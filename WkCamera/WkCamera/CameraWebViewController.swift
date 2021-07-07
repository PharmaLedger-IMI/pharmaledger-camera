//
//  CameraWebViewController.swift
//  jscamera
//
//  Created by Yves Delacrétaz on 23.06.21.
//

import Foundation
import AVFoundation
import UIKit
import WebKit

public class CameraWebViewController: UIViewController, WKScriptMessageHandler {
    // MARK: WKScriptMessageHandler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        var args: [String: AnyObject]? = nil
        var jsCallback: String? = nil
        if let messageName = MessageNames(rawValue: message.name) {
            if let bodyDict = message.body as? [String: AnyObject] {
                args = bodyDict["args"] as? [String: AnyObject]
                jsCallback = bodyDict["callback"] as? String
            }
            messageHandler?.handleMessage(message: messageName, args: args, jsCallback: jsCallback, completion: {result in
                if let result = result {
                    print("result from js: \(result)")
                }
            })
        } else {
            print("Unrecognized message")
        }
    }
    
    // MARK: Privates
    private var webview: WKWebView?
    private let htmlBootstrap = "www/bootstrap.html"
//    private let htmlBootstrap = "www/socket_test2.html"
    private var messageHandler: JsMessageHandler?
    
    func load() {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()
        // add all messages defined in MessageNames
        for m in MessageNames.allCases {
            configuration.userContentController.add(self, name: m.rawValue)
        }
        self.webview = WKWebView(frame: self.view.frame, configuration: configuration)
        if let webview = webview {
            self.messageHandler = JsMessageHandler(webview: webview)
            let fileUrl = URL(fileURLWithPath: Bundle.main.path(forResource: self.htmlBootstrap, ofType: nil)!)
            webview.loadFileURL(fileUrl, allowingReadAccessTo: fileUrl.deletingLastPathComponent())
            self.view.addSubview(webview)
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        load()
        super.viewWillAppear(animated)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        removeWebview()
        super.viewWillDisappear(animated)
    }
    
    
    public func removeWebview() {
        if let webview = webview {
            if let messageHandler = self.messageHandler {
                if let cameraSession = messageHandler.cameraSession {
                    if let captureSession = cameraSession.captureSession {
                        if captureSession.isRunning {
                            cameraSession.stopCamera()
                        }
                    }
                    messageHandler.cameraSession = nil
                }
            }
            webview.configuration.userContentController.removeAllScriptMessageHandlers()
            self.messageHandler = nil
            webview.removeFromSuperview()
            self.webview = nil
        }
    }
}
