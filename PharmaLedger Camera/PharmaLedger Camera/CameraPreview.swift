// 
//  CameraPreviewView.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 7.6.2021.
//
	
import UIKit
import AVFoundation
import Foundation

/**
 UIView CameraPreview that can be added as a sub view to existing view controllers or view containers.
 */
@objc public class CameraPreview:UIView, CameraEventListener{
    
    //MARK: CameraEventListener

    public func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        cameraEventListener?.onPreviewFrame(sampleBuffer: sampleBuffer)
    }
    
    public func onCapture(imageData: Data) {
        cameraEventListener?.onCapture(imageData: imageData)
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
    private var cameraEventListener:CameraEventListener?
    private var cameraPreview:AVCaptureVideoPreviewLayer?
    
    private let ciContext = CIContext()
    
    private var cameraAspectRatio:CGFloat = 4.0/3.0
    
    //MARK: Initialization
    
    /**
     Initializes the preview with camera event callbacks
     - Parameter cameraListener: Protocol to notify preview byte arrays and photo capture callbacks.
     */
    @objc public init(cameraEventListener:CameraEventListener){
        super.init(frame: CGRect())
        self.cameraEventListener = cameraEventListener
        print("CameraPreview","init")
    }
    
    override init(frame: CGRect) {
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
    
    /// Stops the camera session
    @objc public func stopCamera(){
        cameraSession?.stopCamera()
    }
    
    /// Starts the camera session
    @objc public func startCamera(){
        cameraSession?.startCamera()
    }
    
    /// Checks if the camera session is runing or stopped
    /// - Returns: True for running, False for stopped. If capture session couldn't be defined, returns nil
    public func isCameraRunning() -> Bool?{
        guard let captureSession = cameraSession?.captureSession else {
            return nil
        }
        return captureSession.isRunning
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
        
        cameraSession = CameraSession.init(cameraEventListener: self)
    }
}
