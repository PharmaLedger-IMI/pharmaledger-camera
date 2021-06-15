//
//  ViewController.swift
//  Camera Sample
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright TrueMed Inc. 2021
//

import UIKit
import PharmaLedger_Camera

class ViewController: UIViewController, CameraEventListener {
    
    func captureCallback(imageData: Data) {
        print("captureCallback")
        let filedir = cameraPreview?.savePhotoToFiles(imageData: imageData, fileName: "test")
        print("file saved to \(filedir!)")
        
        //cameraPreview?.removeFromSuperview()
    }
    
    func previewFrameCallback(byteArray: [UInt8]) {
        
    }
    
    var cameraPreview:CameraPreview?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        openCameraView()
        
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

