//
//  ViewController.swift
//  Camera Sample
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright TrueMed Inc. 2021
//

import UIKit
import PharmaLedger_Camera
import AVFoundation
import ImageIO

class ViewController: UIViewController, CameraEventListener, CameraSessionDelegate {
    
    //MARK: CameraSessionDelegate
    func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            guard let data:Data = dataFromSampleBuffer(sampleBuffer: sampleBuffer, ciContext: self.ciContext, jpegCompression: 1.0) else {
                print("received nil data")
                return
            }
            let img:UIImage = UIImage.init(data: data)!
            self.cameraImagePreview?.image = img
        }
    }
    
    func onCapture(imageData: Data) {
        
    }
    
    func onCameraInitialized(captureSession: AVCaptureSession) {
        
    }
    
    //MARK: CameraEventListener
    func captureCallback(imageData: Data) {
        print("captureCallback")
        let filedir = savePhotoToFiles(imageData: imageData, fileName: "test")
        print("file saved to \(filedir)")
    }
    
    func previewFrameCallback(cgImage: CGImage) {
        
    }
    
    private var cameraImagePreview:UIImageView?
    private var cameraSession:CameraSession?
    private let ciContext = CIContext()
    
    var cameraPreview:CameraPreview?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        //openCameraView()
        startCameraSession()
        
        let captureButton:UIButton = UIButton.init()
        captureButton.setTitle("Take picture", for: .normal)
        captureButton.addTarget(self, action: #selector(captureButtonClick), for: .touchUpInside)
        //captureButton.target(forAction: #selector(captureButtonClick), withSender: self)
        
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(captureButton)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: -50)
        ])
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func openCameraView(){
        cameraPreview = CameraPreview.init(cameraListener: self)
        view.addSubview(cameraPreview!)
    }
    
    private func startCameraSession(){
        cameraImagePreview = UIImageView.init()
        cameraImagePreview?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraImagePreview!)
        
        cameraSession = CameraSession.init(cameraSessionDelegate: self)
        
        let cameraAspectRatio:CGFloat = 4.0/3.0
        
        let heightAnchorConstant = (view.frame.width)*cameraAspectRatio
        
        NSLayoutConstraint.activate([
            cameraImagePreview!.widthAnchor.constraint(equalTo: view.widthAnchor),
            cameraImagePreview!.topAnchor.constraint(equalTo: view.topAnchor),
            cameraImagePreview!.heightAnchor.constraint(equalToConstant: heightAnchorConstant)
        ])
    }
    
    @objc func captureButtonClick(){
        print("capture button clicked!")
        cameraPreview?.takePicture()
    }

    //MARK: Device orientation
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        var orientationText=""
        switch UIDevice.current.orientation{
        case .portrait:
            orientationText="Portrait"
        case .portraitUpsideDown:
            orientationText="PortraitUpsideDown"
        case .landscapeLeft:
            orientationText="LandscapeLeft"
        case .landscapeRight:
            orientationText="LandscapeRight"
        default:
            orientationText="Another"
        }
        
        print("rotationParent","viewWillTransition \(orientationText)")
        
    }
 
    private func orientationString(orientation:UIInterfaceOrientationMask) -> String {
        var orientationText=""
        switch orientation{
        case .portrait:
            orientationText="Portrait"
        case .portraitUpsideDown:
            orientationText="PortraitUpsideDown"
        case .landscapeLeft:
            orientationText="LandscapeLeft"
        case .landscapeRight:
            orientationText="LandscapeRight"
        default:
            orientationText="Another"
        }
        return orientationText
    }
    
}
