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

class ViewController: UIViewController, CameraEventListener {
    
    //MARK: CameraEventListener
    func onCapture(imageData: Data) {
        print("captureCallback")
        guard let filedir = imageData.savePhotoToFiles(fileName: "test") else {
            //Something went wrong when saving the file
            return
        }
        print("file saved to \(filedir)")
    }
    
    func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        cameraImagePreview?.image = sampleBuffer.bufferToUIImage(ciContext: ciContext)
    }

    func onCameraInitialized() {
        
    }
    
    private let useImage:Bool = false
    private var cameraImagePreview:UIImageView?
    private var cameraSession:CameraSession?
    private let ciContext = CIContext()
    
    private let controlsContainer:UIStackView = UIStackView.init()
    private let captureButton:UIButton = UIButton.init()
    private let cameraToggleButton:UIButton = UIButton.init()
    
    private let cameraAspectRatio:CGFloat = 4.0/3.0
    private var cameraViewHeight:CGFloat?
    private var controlsHeight:CGFloat?
    
    var cameraPreview:CameraPreview?

    override func viewDidLoad() {
        super.viewDidLoad()
        cameraViewHeight = (view.frame.width)*cameraAspectRatio
        controlsHeight = (view.frame.height)-cameraViewHeight!
        // Do any additional setup after loading the view.
        controlsContainer.alignment = .center
        controlsContainer.axis = .horizontal
        controlsContainer.distribution = .fillEqually
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(controlsContainer)
        //startCameraSession()
        openCameraView()
        
        captureButton.setTitle("Take picture", for: .normal)
        captureButton.addTarget(self, action: #selector(captureButtonClick), for: .touchUpInside)
        
        cameraToggleButton.setTitle("Stop camera", for: .normal)
        cameraToggleButton.addTarget(self, action: #selector(toggleCamera), for: .touchUpInside)
        
        cameraToggleButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        
        
        controlsContainer.addArrangedSubview(captureButton)
        controlsContainer.addArrangedSubview(cameraToggleButton)
        
        NSLayoutConstraint.activate([
            controlsContainer.heightAnchor.constraint(equalToConstant: controlsHeight!),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlsContainer.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func openCameraView(){
        cameraPreview = CameraPreview.init(cameraEventListener: self)
        view.addSubview(cameraPreview!)
    }
    
    private func startCameraSession(){
        cameraImagePreview = UIImageView.init()
        cameraImagePreview?.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraImagePreview!)
        
        cameraSession = CameraSession.init(cameraEventListener: self)
        
        NSLayoutConstraint.activate([
            cameraImagePreview!.widthAnchor.constraint(equalTo: view.widthAnchor),
            cameraImagePreview!.topAnchor.constraint(equalTo: view.topAnchor),
            cameraImagePreview!.heightAnchor.constraint(equalToConstant: cameraViewHeight!)
        ])
        
       
    }
    
    @objc func captureButtonClick(){
        print("capture button clicked!")
        cameraPreview?.takePicture()
        cameraSession?.takePicture()
    }
    
    @objc func toggleCamera(){
        
        
        guard let capturesession = cameraSession?.captureSession else {
            return
        }
        if(capturesession.isRunning){
            cameraSession?.stopCamera()
            cameraToggleButton.setTitle("Start camera", for: .normal)
        }else{
            cameraSession?.startCamera()
            cameraToggleButton.setTitle("Stop camera", for: .normal)
        }
        
        
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
