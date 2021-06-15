// 
//  CameraPreviewView.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright © 2021 TrueMed Inc. All rights reserved.
//
	
import UIKit
import AVFoundation
import Photos
import Foundation

/**
 UIView CameraPreview that can be added as a sub view to existing view controllers or view containers.
 */
@objc public class CameraPreview:UIView,CameraSessionDelegate{
    
    //MARK: CameraSessionDelegate

    func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            //self.image = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
            self.cameraListener?.previewFrameCallback(byteArray: self.byteArrayFromSampleBuffer(sampleBuffer: sampleBuffer))
        }
    }
    
    func onCapture(imageData: Data) {
        cameraListener?.captureCallback(imageData: imageData)
    }
    
    func onCameraInitialized(captureSession:AVCaptureSession) {
        print("CameraPreview", "Camera initialized!")
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
    
    //MARK: File saving
    
    /**
     Saves the image to photos library. Requires NSPhotoLibraryUsageDescription declaration in Info.plist file.
     - Parameter imageData Data object received from the photo capture callback
     */
    @objc public func savePhotoToLibrary(imageData: Data){
        PHPhotoLibrary.requestAuthorization { (status) in
            if status == .authorized{
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    
                    creationRequest.addResource(with: .photo, data: imageData, options: nil)
                    
                }, completionHandler: { success, error in
                    if !success, let error = error {
                        print("error creating asset: \(error)")
                        
                    }else{
                        print("file saved succesfully!")
                    }
                    
                })
                
            }else{
                
            }
        }
    }
    
    /**
     Saves the image data to the app file directory. Returns the final absolute path to the file as String
     - Parameters:
        - imageData: Data object received from the photo capture callback
        - fileName: Name for the saved image (.jpg will be appended to the end)
     - Returns: Absolute String path of the saved file.
     */
    @objc public func savePhotoToFiles(imageData: Data, fileName:String) -> String{
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            print("Failed to save photo")
            return ""
        }
        let finalPath = "\(directory.absoluteString!)\(fileName).jpg"
        
        do {

            try imageData.write(to: URL.init(string: finalPath)!)
            print("Data written to \(finalPath)")
            return finalPath
        }catch{
            print("Data write failed")
            return ""
        }
        
    }
    
    //MARK: Helpers
    
    /**
     Converts a samplebuffer to UIImage that can be presented in UI views
     */
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage?{
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /**
     Converts samplebuffer to byte array
     */
    private func byteArrayFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> [UInt8]{
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!

        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let byterPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let srcBuff = CVPixelBufferGetBaseAddress(imageBuffer)

        let data = NSData(bytes: srcBuff, length: byterPerRow * height)
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

        return [UInt8].init(repeating: 0, count: data.length / MemoryLayout<UInt8>.size)
    }
    
    /**
     Converts a Data object to UInt8 byte array
     - Parameter imageData: Data object received from the capture callback
     - Returns Byte array in UInt8 form
     */
    @objc public func imageDataToBytes(imageData:Data) -> [UInt8] {
        return [UInt8](imageData)
    }
}
