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

public class CameraWebViewController: UIViewController /*, WKScriptMessageHandler*/ {
    // MARK: Privates
    private var webview: WKWebView?
    private let htmlBootstrap = "www/bootstrap.html"
//    private let htmlBootstrap = "www/socket_test2.html"
    private var messageHandler: JsMessageHandler?
    
    func load() {
        self.messageHandler = JsMessageHandler()
        self.webview = messageHandler?.getWebview(frame: self.view.frame)
        if let webview = webview {
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
            webview.removeFromSuperview()
        }
        messageHandler = nil
    }
}
