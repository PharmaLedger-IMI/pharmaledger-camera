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
        let filedir = cameraPreview?.savePhotoToFiles(imageData: imageData, fileName: "test")
        print("file saved to \(filedir!)")
    }
    
    func previewFrameCallback(byteArray: [UInt8]) {
        
    }
    
    var cameraPreview:CameraPreview?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        cameraPreview = CameraPreview.init(cameraListener: self)
        cameraPreview?.modalPresentationStyle = .currentContext
        
        addChild(cameraPreview!)
        
        cameraPreview!.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraPreview!.view)
        
        NSLayoutConstraint.activate([
                cameraPreview!.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cameraPreview!.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                cameraPreview!.view.topAnchor.constraint(equalTo: view.topAnchor),
                cameraPreview!.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        
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
        
        cameraPreview!.didMove(toParent: self)
    }
    
    @objc func captureButtonClick(){
        print("capture button clicked!")
        cameraPreview?.takePicture()
    }


}

