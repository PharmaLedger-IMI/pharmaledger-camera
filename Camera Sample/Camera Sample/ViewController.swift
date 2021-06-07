//
//  ViewController.swift
//  Camera Sample
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright TrueMed Inc. 2021
//

import UIKit
import PharmaLedger_Camera

class ViewController: UIViewController {
    
    var cameraPreview:CameraPreview?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        cameraPreview = CameraPreview.init()
        cameraPreview?.modalPresentationStyle = .fullScreen
        
        addChild(cameraPreview!)
        
        cameraPreview!.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraPreview!.view)
        
        NSLayoutConstraint.activate([
                cameraPreview!.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cameraPreview!.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                cameraPreview!.view.topAnchor.constraint(equalTo: view.topAnchor),
                cameraPreview!.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        
        cameraPreview!.didMove(toParent: self)
    }


}

