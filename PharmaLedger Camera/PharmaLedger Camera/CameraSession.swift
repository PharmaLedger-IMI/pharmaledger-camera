//
//  CameraSession.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 7.6.2021.
//

import AVFoundation
import UIKit

/// Camera session handler that provides streamlined access to functionalities such as preview frame callbacks, photo capture and camera configurations
@objc public class CameraSession:NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, CameraConfigurationChangeListener{
    
    //MARK: Constants and variables

    /// The Active AVCaptureSession
    public var captureSession:AVCaptureSession?
    private var captureDevice:AVCaptureDevice?
    private var previewCaptureConnection:AVCaptureConnection?
    private var photoCaptureConnection:AVCaptureConnection?
    
    private let sessionQueue = DispatchQueue(label: "camera_session_queue")
    let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
        [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera],
        mediaType: .video, position: .back)
    private let cameraSessionDelegate:CameraEventListener
    private var photoOutput: AVCapturePhotoOutput?
    
    private let cameraConfiguration:CameraConfiguration
    private let notificationCenter:NotificationCenter = NotificationCenter.default
    
    private var cameraPermissionGranted = false
    
    private enum ConfigurationResult{
        case permissionsDenied
        case deviceDiscoveryFailure
        case deviceConfigurationFailure
        case deviceInputFailure
        case deviceOutputFailure
        case deviceOutputConnectionFailure
        case videoOrientationFailure
        case videoMirroringFailure
        case photoOutputFailure
        case success
    }
    
    //MARK: Initialization
    
    /// Initialisation of the CameraSession. Attempts to configure the session session with default CameraConfiguration and starts it if successfull
    /// - Parameter cameraEventListener: Camera event listener
    public init(cameraEventListener:CameraEventListener) {
        self.cameraConfiguration = CameraConfiguration.init()
        self.cameraSessionDelegate = cameraEventListener
        super.init()
        self.cameraConfiguration.delegate = self
        print("CameraSession","init with delegate")
        self.initCamera()
    }
    
    
    /// Initialisation of the CameraSession using custom launch configurations.
    /// - Parameters:
    ///   - cameraEventListener: Camera event listener
    ///   - cameraConfiguration: Camera configuration
    public init(cameraEventListener:CameraEventListener, cameraConfiguration:CameraConfiguration){
        self.cameraConfiguration = cameraConfiguration
        self.cameraSessionDelegate = cameraEventListener
        super.init()
        self.cameraConfiguration.delegate = self
        print("CameraSession","init with delegate and configuration")
        self.initCamera()
    }
    
    func initCamera(){
        print("CameraSession","initalizing camera...")
        checkPermission()
        sessionQueue.async { [unowned self] in
            let configuration = self.configureSession()
            if(configuration == .success){
                captureSession?.commitConfiguration()
                configureDevice(device: captureDevice!)
                captureSession?.startRunning()
                configureRuntimeSettings(device: captureDevice!)
                cameraSessionDelegate.onCameraInitialized()
                print("CameraSession","Camera successfully configured")
                
            }else if(configuration == .permissionsDenied){
                self.cameraSessionDelegate.onCameraPermissionDenied()
            }
            else{
                print("configuration error!","Error: \(configuration)")
            }
        }
    }
    
    private func configureDevice(device:AVCaptureDevice){
        do{
            try device.lockForConfiguration()
        }catch {
            print(error)
            return
        }
        
        if let preferredColorSpace:AVCaptureColorSpace = cameraConfiguration.getPreferredColorSpace() {
            
            let supportedColorSpaces = device.activeFormat.supportedColorSpaces
            if(supportedColorSpaces.contains(preferredColorSpace)){
                captureSession?.automaticallyConfiguresCaptureDeviceForWideColor = false
                print("camConfig","Trying to set active colorspace to \(cameraConfiguration.getPreferredColorSpaceString())")
                if(preferredColorSpace != device.activeColorSpace){
                    device.activeColorSpace = preferredColorSpace
                }else{
                    print("camConfig","color space already set")
                }
            }else{
                print("preferred color space is not supported!")
                cameraConfiguration.setPreferredColorSpace(color_space: "")
            }
        }else {
            print("camConfig","Preferred color space is not defined")
            captureSession?.automaticallyConfiguresCaptureDeviceForWideColor = true
        }
        
        device.unlockForConfiguration()
    }
    
    /// Call this function after captureSession.startRunning
    private func configureRuntimeSettings(device:AVCaptureDevice){
        if(cameraConfiguration.autoOrientationEnabled){
            addDeviceOrientationObserver()
        }
        do{
            print("camConfig","Try to set torch mode to \(cameraConfiguration.getFlashConfiguration() ?? "undefined") and torch level to \(cameraConfiguration.getTorchLevel())")
            try device.lockForConfiguration()
            device.torchMode = cameraConfiguration.getTorchMode()
            if(device.torchMode == .on){
                do {
                    try device.setTorchModeOn(level: cameraConfiguration.getTorchLevel())
                } catch {
                    print(error)
                }
            }
            device.unlockForConfiguration()
        }catch {
            print(error)
        }
    }
    
    private func configureSession() -> ConfigurationResult {
        captureSession = AVCaptureSession()
        
        guard cameraPermissionGranted else {return .permissionsDenied}
        captureSession?.beginConfiguration()
        captureSession?.sessionPreset = .photo
        
        guard let captureDevice:AVCaptureDevice = selectDevice(in: .back) else {
            return .deviceDiscoveryFailure
        }
        self.captureDevice = captureDevice
        
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            return .deviceInputFailure
        }
        
        guard (captureSession?.canAddInput(captureDeviceInput))! else {
            return .deviceInputFailure
        }
        
        captureSession?.addInput(captureDeviceInput)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBuffer"))
        
        guard (captureSession?.canAddOutput(videoOutput))! else {
            return .deviceOutputFailure
        }
        captureSession?.addOutput(videoOutput)
        
        guard let connection = videoOutput.connection(with: .video) else {
            return .deviceOutputConnectionFailure
        }
        
        self.previewCaptureConnection = connection
        
        guard connection.isVideoOrientationSupported else {
            return .videoOrientationFailure
        }
        
        photoOutput = AVCapturePhotoOutput()
        photoOutput?.isHighResolutionCaptureEnabled = true
        
        guard (captureSession?.canAddOutput(photoOutput!))! else {
            return .photoOutputFailure
        }
        captureSession?.addOutput(photoOutput!)
        
        guard let photo_connection = photoOutput?.connection(with: .video) else {
            print("photo connection not available")
            return .deviceOutputConnectionFailure
        }
        self.photoCaptureConnection = photo_connection
        self.updateOrientation()
        
        return .success
    }
    
    private func selectDevice(in position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = self.discoverySession.devices
        guard !devices.isEmpty else { return nil}

        return devices.first(where: { device in device.position == position })!
    }
    
    //MARK: Public functions
    
    /// Stops the camera session
    @objc public func stopCamera(){
        captureSession?.stopRunning()
        notificationCenter.removeObserver(self)
        sessionQueue.suspend()
    }
    
    /// Starts the camera session.
    @objc public func startCamera(){
        guard let device:AVCaptureDevice = self.captureDevice else {
            return
        }
        self.configureDevice(device: device)
        captureSession?.startRunning()
        self.configureRuntimeSettings(device: device)
        
        sessionQueue.resume()
    }
    
    /// Starts a photo capture
    @objc public func takePicture(){
        
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = cameraConfiguration.getFlashMode()
        
        photoOutput?.capturePhoto(with: photoSettings, delegate: self)
    }
    
    /// Returns the current configuration object of the camera
    /// - Returns: CameraConfiguration (nil if not defined)
    public func getConfig() -> CameraConfiguration?{
        return self.cameraConfiguration
    }
    
    /// Get the current active color space in String format
    /// - Returns: HLG_BT2020, P3_D65, sRGB or unknown. If device was not set returns nil
    public func getCurrentColorSpaceString()->String?{
        guard let device = captureDevice else {
            return nil
        }
        switch device.activeColorSpace {
        case .HLG_BT2020: return "HLG_BT2020"
        case .sRGB: return "sRGB"
        case .P3_D65: return "P3_D65"
        default: return "unknown"
        }
    }
    
    //MARK: Device orientation
    
    /// Requests to update the camera orientation based on the current UIDevice orientation
    @objc public func updateOrientation(){
        guard let connection = self.previewCaptureConnection else {
            return
        }
        guard let capture_connection = self.photoCaptureConnection else {
            return
        }
        
        let deviceOrientation = UIDevice.current.orientation
        
        switch deviceOrientation {
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
            capture_connection.videoOrientation = .landscapeRight
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
            capture_connection.videoOrientation = .landscapeLeft
        default:
            connection.videoOrientation = .portrait
            capture_connection.videoOrientation = .portrait
        }
        
        guard let device = captureDevice else {
            return
        }
        configureRuntimeSettings(device: device)
    }
    
    /// Sets the camera session video orientation to the desired value
    /// - Parameter orientation: Supported values are "landscapeRight", "landscapeLeft" and "portrait". Defaults to portrait for any unsupported values.
    public func setOrientation(orientation:String){
        guard let connection = self.previewCaptureConnection else {
            return
        }
        guard let capture_connection = self.photoCaptureConnection else {
            return
        }
        
        switch orientation {
        case "landscapeLeft":
            connection.videoOrientation = .landscapeRight
            capture_connection.videoOrientation = .landscapeRight
        case "landscapeRight":
            connection.videoOrientation = .landscapeLeft
            capture_connection.videoOrientation = .landscapeLeft
        default:
            connection.videoOrientation = .portrait
            capture_connection.videoOrientation = .portrait
        }
    }
    
    private func addDeviceOrientationObserver(){
        notificationCenter.removeObserver(self)
        notificationCenter.addObserver(self, selector: #selector(updateOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    //MARK: Preview and capture callbacks
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        self.cameraSessionDelegate.onPreviewFrame(sampleBuffer: sampleBuffer)
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        cameraSessionDelegate.onCapture(imageData: imageData)
    }
    
    //MARK: Camera access permission
    
    private func checkPermission(){
        var willRequestPermission:Bool = false
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
            case .authorized:
                print("AVPermission","Authorized!")
                cameraPermissionGranted = true
                break
            case .notDetermined:
                print("AVPermission","Not determined, request permission...")
                willRequestPermission = true
                requestPermission()
                break
            default:
                print("AVPermission","Permission not granted!")
                cameraPermissionGranted = false
                break
        }
        if(!willRequestPermission){
            print("permissions won't be asked")
        }else{
            print("permissions will be asked")
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.cameraPermissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    //MARK: CameraConfigurationChangeListener
    func onConfigurationsChanged() {
        guard let device:AVCaptureDevice = self.captureDevice else {
            return
        }
        self.configureDevice(device: device)
        self.configureRuntimeSettings(device: device)
    }
    
}
