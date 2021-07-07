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

public enum MessageNames: String, CaseIterable {
    case SayHello = "SayHelloFromSwift"
    case StartCamera = "StartCamera"
    case StopCamera = "StopCamera"
    case GrabFrame = "GrabFrame"
}

public class JsMessageHandler: CameraEventListener {
    public func onCameraPermissionDenied() {
        print("Permission denied")
    }
    
    // MARK: public vars
    public var cameraSession: CameraSession?
    public var cameraConfiguration: CameraConfiguration?
    
    
    func createJsonForJavaScript(for data: [String : Any]) -> String {
        var jsonString : String?
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data,       options: .prettyPrinted)
            // here "jsonData" is the dictionary encoded in JSON data .
            jsonString = String(data: jsonData, encoding: .utf8)!
            
            jsonString = jsonString?.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\\", with: "")
        }  catch {
            print(error.localizedDescription)
        }
        return jsonString!
    }
    
    // MARK: CameraEventListener
    public func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Cannot get imageBuffer")
            return
        }
        var ciImage: CIImage = .init(cvImageBuffer: imageBuffer)
//        let resizeFilter = CIFilter(name: "CILanczosScaleTransform")!
//        resizeFilter.setValue(ciImage, forKey: kCIInputImageKey)
//        resizeFilter.setValue(0.2, forKey: kCIInputScaleKey)
//        ciImage = resizeFilter.outputImage!
        // swap R and G (because image is BGRA but js wants RGBA in imageData)
        swapFilter.inputImage = ciImage
        ciImage = swapFilter.outputImage()!
        //
        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let bpc = cgImage!.bitsPerComponent
        let Bpr = cgImage!.bytesPerRow
        let cgContext = CGContext(data: nil, width: cgImage!.width, height: cgImage!.height, bitsPerComponent: bpc, bytesPerRow: Bpr, space: colorspace, bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)

        cgContext?.draw(cgImage!, in: CGRect(x: 0, y: 0, width: cgImage!.width, height: cgImage!.height))
        let byteData = cgContext!.data?.assumingMemoryBound(to: UInt8.self)
        let array = Array(UnsafeMutableBufferPointer(start: byteData, count: Bpr * cgImage!.height))
        WebSocketVideoFrameServer.shared.storeFrame(frame: array)
        WebSocketVideoFrameServer.shared.send();
    }
    
    public func onCapture(imageData: Data) {
        /// TODO
    }
    
    public func onCameraInitialized() {
        print("Camera initialized")
        WebSocketVideoFrameServer.shared.start(completion: { self.callJsAfterCameraStart() })
    }
    
    // MARK: privates vars
    private var webview: WKWebView
    private var onGrabFrameJsCallBack: String?
    private let ciContext = CIContext()
    private let swapFilter: MetalFilterSwapBandR
    private var frameJsonString: String?
    private var onCameraInitializedJsCallback: String?

    // MARK: public methods
    public init(webview: WKWebView) {
        self.webview = webview
        self.swapFilter = MetalFilterSwapBandR()
    }
    
    public func handleMessage(message: MessageNames, args: [String: AnyObject]? = nil, jsCallback: String? = nil, completion: ( (Any?) -> Void )? = nil) {
        var jsonString: String = ""
        switch message {
        case .SayHello:
            jsonString = self.handleSayHello(args: args)
        case .StartCamera:
            handleCameraStart(onCameraInitializedJsCallback: args?["onInitializedJsCallback"] as? String)
        case .StopCamera:
            handleCameraStop()
        case .GrabFrame:
            if self.frameJsonString != nil {
                jsonString = self.frameJsonString!
            } else {
                print("jsonString was nil")
            }
        }
        if let callback = jsCallback {
            if !callback.isEmpty {
                DispatchQueue.main.async {
                    let js = "\(callback)(\(jsonString))"
                    self.webview.evaluateJavaScript(js, completionHandler: {result, error in
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
    private func handleSayHello(args: [String: AnyObject]?) -> String {
        var mess = "Hello. Args were: <br/>"
        guard args != nil else {
            return mess
        }
        for (k, v) in args! {
            mess = mess + "\(k): \(v) <br/>"
        }
        return mess
    }
    
    private func handleCameraStart(onCameraInitializedJsCallback: String?) {
        self.onCameraInitializedJsCallback = onCameraInitializedJsCallback
        if self.cameraSession == nil {
//            self.cameraSession = .init(cameraEventListener: self)
            self.cameraConfiguration = .init(flash_mode: nil, color_space: nil, session_preset: "hd1280x720", auto_orienation_enabled: false)
            self.cameraSession = .init(cameraEventListener: self, cameraConfiguration: self.cameraConfiguration!)
            return
        }
        if let cameraSession = cameraSession {
            if let captureSession = cameraSession.captureSession {
                if captureSession.isRunning == false {
                    cameraSession.startCamera()
                    WebSocketVideoFrameServer.shared.start(completion: { self.callJsAfterCameraStart() })
                }
            }
        }
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
    }
    
    private func callJsAfterCameraStart() {
        if let jsCallback = self.onCameraInitializedJsCallback {
            DispatchQueue.main.async {
                self.webview.evaluateJavaScript("\(jsCallback)()", completionHandler: {result, error in
                    guard error == nil else {
                        print(error!)
                        return
                    }
                })
            }
        }
    }
}
