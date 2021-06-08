//
//  CameraPreview.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright TrueMed Inc. 2021
//

import UIKit
import AVFoundation
import Photos

public protocol CameraEventListener{
    func previewFrameCallback(byteArray:[UInt8])
    func captureCallback(imageData:Data)
}

public class CameraPreview:UIViewController,CameraSessionDelegate{
    
    //MARK: CameraSessionDelegate
    
    func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            //Convert the sample buffer to UIImage and update the preview image
            self.preview?.image = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
            self.cameraListener?.previewFrameCallback(byteArray: self.byteArrayFromSampleBuffer(sampleBuffer: sampleBuffer))
        }
    }
    
    func onCapture(imageData: Data) {
        cameraListener?.captureCallback(imageData: imageData)
    }
    
    func onCameraInitialized() {
        print("CameraPreview", "Camera initialized!")
    }
    
    //MARK: Constants and variables
    
    private var preview:UIImageView?
    private var cameraSession:CameraSession?
    
    private var cameraListener:CameraEventListener?
    private let ciContext = CIContext()
    
    //MARK: Initialization
    
    /**
     Initializes the preview with camera event callbacks
     */
    public init(cameraListener:CameraEventListener){
        super.init(nibName: nil, bundle: nil)
        self.cameraListener = cameraListener
    }
    
    /**
     Initializes the preview with no callbacks
     */
    public init(){
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: Public functions
    
    public func takePicture(){
        cameraSession?.takePicture()
    }
    
    //MARK: View lifecycle
    
    override public func viewDidLoad() {
        print("CameraPreview", "viewDidLoad")
        preview = UIImageView.init()
        preview?.translatesAutoresizingMaskIntoConstraints = false
        preview?.contentMode = .scaleAspectFit
        view.addSubview(preview!)
        
        NSLayoutConstraint.activate([
            preview!.widthAnchor.constraint(equalTo: view.widthAnchor),
            preview!.heightAnchor.constraint(equalTo: view.heightAnchor),
            preview!.topAnchor.constraint(equalTo: view.topAnchor),
            preview!.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        cameraSession = CameraSession.init(cameraSessionDelegate: self)
        
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        print("CameraPreview", "viewWillDisappear")
        cameraSession?.stopCamera()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        print("CameraPreview", "viewDidDisappear")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        print("CameraPreview", "viewWillAppear")
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        print("CameraPreview", "viewDidAppear")
    }
    
    //MARK: File saving
    
    /**
     Saves the image to photos library
     */
    public func savePhotoToLibrary(imageData: Data){
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
     */
    public func savePhotoToFiles(imageData: Data, fileName:String) -> String{
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
    
    public func imageDataToBytes(imageData:Data) -> [UInt8] {
        return [UInt8](imageData)
    }
    
}
