//
//  JsMessageHandler.swift
//  jscamera
//
//  Created by Yves Delacrétaz on 29.06.21.
//

import Foundation
import WebKit
import AVFoundation
import PharmaLedger_Camera
import Accelerate

public enum MessageNames: String, CaseIterable {
    case StartCamera = "StartCamera"
    case StopCamera = "StopCamera"
    case TakePicture = "TakePicture"
    case SetFlashMode = "SetFlashMode"
}

public class JsMessageHandler: NSObject, CameraEventListener, WKScriptMessageHandler {
    // MARK: public vars
    public var cameraSession: CameraSession?
    public var cameraConfiguration: CameraConfiguration?
    
    // MARK: WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        var args: [String: AnyObject]? = nil
        var jsCallback: String? = nil
        if let messageName = MessageNames(rawValue: message.name) {
            if let bodyDict = message.body as? [String: AnyObject] {
                args = bodyDict["args"] as? [String: AnyObject]
                jsCallback = bodyDict["callback"] as? String
            }
            self.handleMessage(message: messageName, args: args, jsCallback: jsCallback, completion: {result in
                if let result = result {
                    print("result from js: \(result)")
                }
            })
        } else {
            print("Unrecognized message")
        }
    }
    
    // MARK: CameraEventListener
    public func onCameraPermissionDenied() {
        print("Permission denied")
    }
    
    private var dataBufferRGBA: UnsafeMutableRawPointer? = nil
    private var dataBufferRGB: UnsafeMutableRawPointer? = nil
    private var dataBufferYUV: UnsafeMutableRawPointer? = nil
    public func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Cannot get imageBuffer")
            return
        }
        let data = prepareRGBData(imageBuffer: imageBuffer)
//        let data = prepareYUVData(img: imageBuffer)
        if let data = data {
            WebSocketVideoFrameServer.shared.sendFrame(frame: data)
        }
    }
    
    public func prepareYUVData(img: CVImageBuffer) -> Data? {
        let flag = CVPixelBufferLockFlags.readOnly
        
        CVPixelBufferLockBaseAddress(img, flag)
        
        let  yRow = CVPixelBufferGetBytesPerRowOfPlane(img, 0)
        let uvRow = CVPixelBufferGetBytesPerRowOfPlane(img, 1)
        
        let  yWidth = CVPixelBufferGetWidthOfPlane(img, 0)
        let uvWidth = CVPixelBufferGetWidthOfPlane(img, 1)
        
        let  yHeight = CVPixelBufferGetHeightOfPlane(img, 0)
        let uvHeight = CVPixelBufferGetHeightOfPlane(img, 1)
        
        let  yBuf = CVPixelBufferGetBaseAddressOfPlane(img, 0)!
        let uvBuf = CVPixelBufferGetBaseAddressOfPlane(img, 1)!
        
        if dataBufferYUV == nil {
            dataBufferYUV = malloc(yRow*yHeight+uvRow*uvHeight)
        }
        memcpy(dataBufferYUV!, yBuf, yRow*yHeight)
        let offset = dataBufferYUV!.assumingMemoryBound(to: UInt8.self).advanced(by: yRow*yHeight)
        memcpy(offset, uvBuf, uvRow*uvHeight)
        let data = Data(bytesNoCopy: dataBufferYUV!, count: yRow*yHeight+uvRow*uvHeight, deallocator: .none)
        
        CVPixelBufferUnlockBaseAddress(img, flag)
        
        return data
    }
    
    public func prepareRGBData(imageBuffer: CVImageBuffer) -> Data? {
        let flag = CVPixelBufferLockFlags.readOnly
        CVPixelBufferLockBaseAddress(imageBuffer, flag)
        let  rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer)
        let w = CVPixelBufferGetWidth(imageBuffer)
        let h = CVPixelBufferGetHeight(imageBuffer)
        let buf = CVPixelBufferGetBaseAddress(imageBuffer)!
        
        if dataBufferRGBA == nil {
            dataBufferRGBA = malloc(rowBytes*h)
        }
        if dataBufferRGB == nil {
            dataBufferRGB = malloc(3*w*h)
        }
        memcpy(dataBufferRGBA!, buf, rowBytes*h)
        CVPixelBufferUnlockBaseAddress(imageBuffer, flag)
        
        var inBuffer = vImage_Buffer(
            data: dataBufferRGBA!,
            height: vImagePixelCount(h),
            width: vImagePixelCount(w),
            rowBytes: rowBytes)
        var outBuffer = vImage_Buffer(
            data: dataBufferRGB,
            height: vImagePixelCount(h),
            width: vImagePixelCount(w),
            rowBytes: 3*w)
        vImageConvert_BGRA8888toRGB888(&inBuffer, &outBuffer, UInt32(kvImageNoFlags))
        
        let data = Data(bytesNoCopy: dataBufferRGB!, count: 3*w*h, deallocator: .none)
        return data
    }
    
    public func onCapture(imageData: Data) {
        print("captureCallback")
//        if let image = UIImage.init(data: imageData){
//            print("image acquired \(image.size.width)x\(image.size.height)")
//        }
        if let jsCallback = self.onCaptureJsCallback {
            guard let webview = self.webview else {
                print("WebView was nil")
                return
            }
            let base64 = "data:image/jpeg;base64, " + imageData.base64EncodedString()
            let js = "\(jsCallback)(\"\(base64)\")"
            DispatchQueue.main.async {
                webview.evaluateJavaScript(js, completionHandler: {result, error in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                })
            }
        }
    }
    
    public func onCameraInitialized() {
        print("Camera initialized")
        WebSocketVideoFrameServer.shared.start(completion: { self.callJsAfterCameraStart() })
    }
    
    // MARK: privates vars
    private var webview: WKWebView? = nil
    private var onGrabFrameJsCallBack: String?
    private let ciContext = CIContext()
    private var onCameraInitializedJsCallback: String?
    private var onCaptureJsCallback: String?
    
    // MARK: public methods
    public override init() {
        
    }
    
    deinit {
        if let webview = webview {
            if let cameraSession = self.cameraSession {
                if let captureSession = cameraSession.captureSession {
                    if captureSession.isRunning {
                        cameraSession.stopCamera()
                    }
                }
                self.cameraSession = nil
            }
            for m in MessageNames.allCases {
                webview.configuration.userContentController.removeScriptMessageHandler(forName: m.rawValue)
            }
            self.webview = nil
        }
    }
    
    public func getWebview(frame: CGRect) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        // add all messages defined in MessageNames
        for m in MessageNames.allCases {
            configuration.userContentController.add(self, name: m.rawValue)
        }
        self.webview = WKWebView(frame: frame, configuration: configuration)
        return self.webview!
    }
    
    public func handleMessage(message: MessageNames, args: [String: AnyObject]? = nil, jsCallback: String? = nil, completion: ( (Any?) -> Void )? = nil) {
        guard let webview = self.webview else {
            print("WebView was nil")
            return
        }
        // string used as returned argument that can be passed back to js with the callback
        var jsonString: String = ""
        switch message {
        case .StartCamera:
            handleCameraStart(onCameraInitializedJsCallback: args?["onInitializedJsCallback"] as? String,
                              sessionPreset: args?["sessionPreset"] as! String,
                              flash_mode: args?["flashMode"] as? String)
            jsonString = ""
        case .StopCamera:
            handleCameraStop()
            jsonString = ""
        case .TakePicture:
            handleTakePicture(onCaptureJsCallback: args?["onCaptureJsCallback"] as? String)
        case .SetFlashMode:
            handleSetFlashMode(mode: args?["mode"] as? String)
        }
        if let callback = jsCallback {
            if !callback.isEmpty {
                DispatchQueue.main.async {
                    let js = "\(callback)(\(jsonString))"
                    webview.evaluateJavaScript(js, completionHandler: {result, error in
                        guard error == nil else {
                            print(error!)
                            return
                        }
                        if let completion = completion {
                            completion(result)
                        }
                    })
                }
            }
        }
    }
    
    // MARK: private methods
    private func handleCameraStart(onCameraInitializedJsCallback: String?, sessionPreset: String, flash_mode: String?) {
        self.onCameraInitializedJsCallback = onCameraInitializedJsCallback
        self.cameraConfiguration = .init(flash_mode: flash_mode, color_space: nil, session_preset: sessionPreset, auto_orienation_enabled: false)
        self.cameraSession = .init(cameraEventListener: self, cameraConfiguration: self.cameraConfiguration!)
        return
    }
    
    private func handleCameraStop() {
        if let cameraSession = self.cameraSession {
            if let captureSession = cameraSession.captureSession {
                if captureSession.isRunning {
                    cameraSession.stopCamera()
                    WebSocketVideoFrameServer.shared.stop()
                }
            }
        }
        self.cameraSession = nil
        if dataBufferRGBA != nil {
            free(dataBufferRGBA!)
            dataBufferRGBA = nil
        }
        if dataBufferRGB != nil {
            free(dataBufferRGB)
            dataBufferRGB = nil
        }
        if dataBufferYUV != nil {
            free(dataBufferYUV)
            dataBufferYUV = nil
        }
    }
    
    private func handleTakePicture(onCaptureJsCallback: String?) {
        self.onCaptureJsCallback = onCaptureJsCallback
        self.cameraSession?.takePicture()
    }
    
    private func handleSetFlashMode(mode: String?) {
        guard let mode = mode, let cameraConfiguration = cameraConfiguration else {
            return
        }
        cameraConfiguration.setFlashConfiguration(flash_mode: mode)
    }
    
    private func callJsAfterCameraStart() {
        if let jsCallback = self.onCameraInitializedJsCallback {
            guard let webview = self.webview else {
                print("WebView was nil")
                return
            }
            DispatchQueue.main.async {
                webview.evaluateJavaScript("\(jsCallback)(\(WebSocketVideoFrameServer.shared.serverPort))", completionHandler: {result, error in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                })
            }
        }
    }
}
