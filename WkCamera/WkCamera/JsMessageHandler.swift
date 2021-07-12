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
    case StartCamera = "StartCamera"
    case StopCamera = "StopCamera"
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
    
    public func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Cannot get imageBuffer")
            return
        }
        let ciImage: CIImage = .init(cvImageBuffer: imageBuffer)
        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let bpc = cgImage!.bitsPerComponent
        let Bpr = cgImage!.bytesPerRow
        let cgContext = CGContext(data: nil, width: cgImage!.width, height: cgImage!.height, bitsPerComponent: bpc, bytesPerRow: Bpr, space: colorspace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        cgContext?.draw(cgImage!, in: CGRect(x: 0, y: 0, width: cgImage!.width, height: cgImage!.height))
        let byteData = cgContext!.data?.assumingMemoryBound(to: UInt8.self)
        let array = Array(UnsafeMutableBufferPointer(start: byteData, count: Bpr * cgImage!.height))
        WebSocketVideoFrameServer.shared.sendFrame(frame: array)
    }
    
    public func onCapture(imageData: Data) {
        /// TODO
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

    // MARK: public methods
    public override init() {
        
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
            handleCameraStart(onCameraInitializedJsCallback: args?["onInitializedJsCallback"] as? String, sessionPreset: args?["sessionPreset"] as! String)
            jsonString = ""
        case .StopCamera:
            handleCameraStop()
            jsonString = ""
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
    private func handleCameraStart(onCameraInitializedJsCallback: String?, sessionPreset: String) {
        self.onCameraInitializedJsCallback = onCameraInitializedJsCallback
        self.cameraConfiguration = .init(flash_mode: nil, color_space: nil, session_preset: sessionPreset, auto_orienation_enabled: false)
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
