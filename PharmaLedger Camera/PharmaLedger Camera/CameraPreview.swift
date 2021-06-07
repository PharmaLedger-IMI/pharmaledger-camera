//
//  CameraPreview.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright TrueMed Inc. 2021
//

import UIKit
import AVFoundation

public class CameraPreview:UIViewController,CameraSessionDelegate{
    
    //MARK: CameraSessionDelegate
    
    func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer) {
        
        DispatchQueue.main.async {
            //Convert the sample buffer to UIImage and update the preview image
            self.preview?.image = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
        }
    }
    
    func onCameraInitialized() {
        print("CameraPreview", "Camera initialized!")
    }
    
    //MARK: Constants and variables
    
    var preview:UIImageView?
    var cameraSession:CameraSession?
    
    private let ciContext = CIContext()
    
    //MARK: Initialization
    
    //MARK: Public functions
    
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
    
    
}
