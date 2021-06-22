//
//  ViewController.swift
//  Camera Sample
//
//  Created by Ville Raitio on 7.6.2021.
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
        self.showToast(message: "file saved", font: .systemFont(ofSize: 14.0))
    }
    
    func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        cameraImagePreview?.image = sampleBuffer.bufferToUIImage(ciContext: ciContext)
    }

    func onCameraInitialized() {
        print("camConfig","Current colorspace: \(cameraSession?.getCurrentColorSpaceString() ?? "nil")")
    }
    
    func onCameraPermissionDenied() {
        print("camera permission was denied!")
    }
    
    private let useImage:Bool = false
    private var cameraImagePreview:UIImageView?
    private var cameraSession:CameraSession?
    private let cameraConfig:CameraConfiguration = CameraConfiguration.init()
    private let ciContext = CIContext()
    
    private let controlsContainer:UIStackView = UIStackView.init()
    private let captureButton:UIButton = UIButton.init()
    private let flashModeButton:UIButton = UIButton.init()
    private let cameraToggleButton:UIButton = UIButton.init()
    
    private let cameraAspectRatio:CGFloat = 4.0/3.0
    private var cameraViewHeight:CGFloat?
    private var cameraViewWidth:CGFloat?
    private var controlsHeight:CGFloat?
    
    var cameraPreview:CameraPreview?
    
    var camerapreview_widthconstraint:NSLayoutConstraint?
    var camerapreview_heightconstraint:NSLayoutConstraint?
    var camerapreview_topconstraint:NSLayoutConstraint?
    var camerapreview_leftconstraint:NSLayoutConstraint?
    
    var controlscontainer_widthconstraint:NSLayoutConstraint?
    var controlscontainer_heightconstraint:NSLayoutConstraint?
    var controlscontainer_bottomconstraint:NSLayoutConstraint?
    var controlscontainer_leftconstraint:NSLayoutConstraint?
    var controlscontainer_rightconstraint:NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        cameraViewHeight = (view.frame.width)*cameraAspectRatio
        cameraViewWidth = (view.frame.width)
        controlsHeight = (view.frame.height)-cameraViewHeight!
        // Do any additional setup after loading the view.
        controlsContainer.alignment = .center
        controlsContainer.axis = .horizontal
        controlsContainer.distribution = .fillEqually
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(controlsContainer)
        startCameraSession()
        //openCameraView()
        
        //captureButton.setTitle("Take picture", for: .normal)
        captureButton.setImage(UIImage.init(named: "photo_camera"), for: .normal)
        captureButton.addTarget(self, action: #selector(captureButtonClick), for: .touchUpInside)
        
        //cameraToggleButton.setTitle("Stop camera", for: .normal)
        cameraToggleButton.setImage(UIImage.init(named: "pause"), for: .normal)
        cameraToggleButton.addTarget(self, action: #selector(toggleCamera), for: .touchUpInside)
        
        flashModeButton.setImage(UIImage.init(named: "flash_auto"), for: .normal)
        flashModeButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        
        cameraToggleButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        flashModeButton.translatesAutoresizingMaskIntoConstraints = false
        
        controlscontainer_widthconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 0)
        controlscontainer_heightconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: controlsHeight!)
        controlscontainer_bottomconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0)
        controlscontainer_leftconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: 0)
        controlscontainer_rightconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .right, relatedBy: .greaterThanOrEqual, toItem: view, attribute: .right, multiplier: 1, constant: 0)
        
        
        controlsContainer.addArrangedSubview(flashModeButton)
        controlsContainer.addArrangedSubview(captureButton)
        controlsContainer.addArrangedSubview(cameraToggleButton)
        
        setViewConstraints(orientation: UIDevice.current.orientation)
        
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
        cameraConfig.setPreferredColorSpace(color_space: "HLG_BT2020")
        view.addSubview(cameraImagePreview!)
        cameraSession = CameraSession.init(cameraEventListener: self,cameraConfiguration: cameraConfig)
        
        //cameraImagePreview?.setNeedsUpdateConstraints()
        camerapreview_widthconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 0)
        camerapreview_heightconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: cameraViewHeight!)
        camerapreview_topconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0)
        camerapreview_leftconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: 0)
       
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
        }else{
            cameraSession?.startCamera()
        }
        
        
    }
    
    @objc func toggleFlash(){
        switch cameraConfig.getFlashConfiguration() {
        case "off":
            flashModeButton.setImage(UIImage.init(named: "flash_auto"), for: .normal)
            cameraConfig.setFlashConfiguration(flash_mode: "auto")
            break
        case "auto":
            flashModeButton.setImage(UIImage.init(named: "flash_on"), for: .normal)
            cameraConfig.setFlashConfiguration(flash_mode: "flash")
            break
        case "flash":
            flashModeButton.setImage(UIImage.init(named: "flash_torch"), for: .normal)
            cameraConfig.setFlashConfiguration(flash_mode: "torch")
            break
        default://torch
            flashModeButton.setImage(UIImage.init(named: "flash_off"), for: .normal)
            cameraConfig.setFlashConfiguration(flash_mode: "off")
            break
        }
        cameraConfig.applyConfiguration()
    }

    //MARK:Device orientation
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        NSLayoutConstraint.deactivate([
            camerapreview_widthconstraint!,
            camerapreview_heightconstraint!,
            camerapreview_leftconstraint!,
            camerapreview_topconstraint!,
            controlscontainer_widthconstraint!,
            controlscontainer_heightconstraint!,
            controlscontainer_leftconstraint!,
            controlscontainer_rightconstraint!,
            controlscontainer_bottomconstraint!]
        )
        
        setViewConstraints(orientation: UIDevice.current.orientation)
        cameraSession?.updateOrientation()
        
    }
    
    private func setViewConstraints(orientation:UIDeviceOrientation){
        switch UIDevice.current.orientation{
        case .landscapeLeft, .landscapeRight:
            print("landscape")
            camerapreview_widthconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: cameraViewHeight!)
            camerapreview_heightconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 1, constant: 0)
            
            controlscontainer_leftconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: cameraViewHeight!)
            controlscontainer_widthconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: controlsHeight!)
            controlscontainer_heightconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 1, constant: 0)
            controlsContainer.axis = .vertical
        default:
            print("portrait")
            camerapreview_widthconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 0)
            camerapreview_heightconstraint = NSLayoutConstraint(item: cameraImagePreview!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: cameraViewHeight!)
            
            
            controlscontainer_leftconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0)
            controlscontainer_heightconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: controlsHeight!)
            controlscontainer_widthconstraint = NSLayoutConstraint(item: controlsContainer, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 0)
            controlsContainer.axis = .horizontal
        }
        NSLayoutConstraint.activate([
            camerapreview_widthconstraint!,
            camerapreview_heightconstraint!,
            camerapreview_leftconstraint!,
            camerapreview_topconstraint!,
            controlscontainer_widthconstraint!,
            controlscontainer_heightconstraint!,
            controlscontainer_leftconstraint!,
            controlscontainer_rightconstraint!,
            controlscontainer_bottomconstraint!
        ])
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

extension UIViewController {

func showToast(message : String, font: UIFont) {

    let toastLabel = UILabel(frame: self.view.frame)
    toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    toastLabel.textColor = UIColor.white
    toastLabel.font = font
    toastLabel.textAlignment = .center;
    toastLabel.text = message
    toastLabel.alpha = 1.0
    toastLabel.layer.cornerRadius = 10;
    toastLabel.clipsToBounds  =  true
    self.view.addSubview(toastLabel)
    UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
         toastLabel.alpha = 0.0
    }, completion: {(isCompleted) in
        toastLabel.removeFromSuperview()
    })
} }
