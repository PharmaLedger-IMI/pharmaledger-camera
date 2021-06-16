// 
//  CameraPreviewView.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright © 2021 TrueMed Inc. All rights reserved.
//
	
import UIKit
import AVFoundation
import Foundation

/**
 UIView CameraPreview that can be added as a sub view to existing view controllers or view containers.
 */
@objc public class CameraPreview:UIView,CameraSessionDelegate{
    
    //MARK: CameraSessionDelegate

    public func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            //self.image = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
            guard let cgImage:CGImage = sampleBuffer.bufferToCGImage(ciContext: self.ciContext) else {
                return
            }
            
            self.cameraListener?.previewFrameCallback(cgImage: cgImage)
        }
    }
    
    public func onCapture(imageData: Data) {
        cameraListener?.captureCallback(imageData: imageData)
    }
    
    public func onCameraInitialized() {
        print("CameraPreview", "Camera initialized!")
        guard let captureSession:AVCaptureSession = cameraSession?.captureSession else {
            return
        }
        DispatchQueue.main.async {
            self.cameraPreview = AVCaptureVideoPreviewLayer.init(session: captureSession)
            self.cameraPreview!.frame = self.bounds
            self.cameraPreview!.backgroundColor = UIColor.black.cgColor
            self.cameraPreview!.videoGravity = .resizeAspect
            self.layer.addSublayer(self.cameraPreview!)
        }
    }
    
    //MARK: Constants and variables
    
    private var cameraSession:CameraSession?
    private var cameraListener:CameraEventListener?
    private var cameraPreview:AVCaptureVideoPreviewLayer?
    
    private let ciContext = CIContext()
    
    private var cameraAspectRatio:CGFloat = 4.0/3.0
    
    //MARK: Initialization
    
    /**
     Initializes the preview with camera event callbacks
     - Parameter cameraListener: Protocol to notify preview byte arrays and photo capture callbacks.
     */
    @objc public init(cameraListener:CameraEventListener){
        super.init(frame: CGRect())
        self.cameraListener = cameraListener
        print("CameraPreview","init")
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    /**
     Initializes the preview with no callbacks
     */
    @objc public init(){
        super.init(frame: CGRect())
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //MARK: Public functions
    
    /**
     Requests the camera session for a photo capture.
     */
    @objc public func takePicture(){
        cameraSession?.takePicture()
    }
    
    //MARK: View lifecycle
    
    public override func willMove(toSuperview newSuperview: UIView?) {
        print("CameraPreview","willMove to superview")
    }
    
    public override func didMoveToSuperview() {
        if(superview == nil){
            print("CameraPreview","Superview is nil! Stopping camera...")
            cameraSession?.stopCamera()
            return
        }
        self.contentMode = .scaleAspectFit
        self.translatesAutoresizingMaskIntoConstraints = false
        print("CameraPreview","didMove to superview")
        let heightAnchorConstant = (superview?.frame.width)!*cameraAspectRatio
        print("CameraPreview","View size: \((superview?.frame.width)!)x\(heightAnchorConstant)")
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalTo: superview!.widthAnchor),
            self.topAnchor.constraint(equalTo: superview!.topAnchor),
            self.heightAnchor.constraint(equalToConstant: heightAnchorConstant)
        ])
        
        cameraSession = CameraSession.init(cameraSessionDelegate: self)
    }
}
