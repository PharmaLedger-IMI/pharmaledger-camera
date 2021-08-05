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
    
    /// The Active [AVCaptureSession](https://developer.apple.com/documentation/avfoundation/avcapturesession)
    public var captureSession:AVCaptureSession?
    private var captureDevice:AVCaptureDevice?
    private var previewCaptureConnection:AVCaptureConnection?
    private var photoCaptureConnection:AVCaptureConnection?
    
    private let sessionQueue = DispatchQueue(label: "camera_session_queue")
    private var sessionPreset:AVCaptureSession.Preset = .photo
    private var currentDeviceTypes:[AVCaptureDevice.DeviceType]?
    private var currentCameraPosition:AVCaptureDevice.Position?
    
    private let cameraSessionDelegate:CameraEventListener
    private var photoOutput: AVCapturePhotoOutput?
    
    private let cameraConfiguration:CameraConfiguration
    private let notificationCenter:NotificationCenter = NotificationCenter.default
    
    private var lastOrientation:UIDeviceOrientation?
    
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
    
    //focus variables
    private var currentFocuscallbackTime = 0.0
    private var focusCallbackTimeout:Double = 2.0
    private let focusCallbackMinimumTime = 0.4
    private let focusCallbackInterval = 0.1
    
    private var focusTimeoutHandler:Timer?
    
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
        currentDeviceTypes = cameraConfiguration.getDeviceTypes()
        currentCameraPosition = cameraConfiguration.getCameraPosition()
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
                captureSession?.commitConfiguration()
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
        
        let preferredSessionPreset:AVCaptureSession.Preset = cameraConfiguration.getSessionPreset()
        if(sessionPreset != preferredSessionPreset){
            print("setting the preset to \(cameraConfiguration.getSessionPresetString())")
            sessionPreset = preferredSessionPreset
            captureSession?.sessionPreset = sessionPreset
        }else{
            print("session preset is already set to \(cameraConfiguration.getSessionPresetString())")
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
            if(device.isTorchModeSupported(cameraConfiguration.getTorchMode()) && device.isTorchAvailable){
                device.torchMode = cameraConfiguration.getTorchMode()
                if(device.torchMode == .on){
                    do {
                        try device.setTorchModeOn(level: cameraConfiguration.getTorchLevel())
                    } catch {
                        print(error)
                    }
                }
            }
            device.unlockForConfiguration()
            
            requestFocus(pointOfInterest: nil)
        }catch {
            print(error)
        }
    }
    
    private func configureSession() -> ConfigurationResult {
        captureSession = AVCaptureSession()
        
        guard cameraPermissionGranted else {return .permissionsDenied}
        captureSession?.beginConfiguration()
        captureSession?.sessionPreset = self.sessionPreset
        
        guard let captureDevice:AVCaptureDevice = selectDevice(in: cameraConfiguration.getCameraPosition()) else {
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
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
//        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)]
        
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
        var discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: cameraConfiguration.getDeviceTypes(), mediaType: .video, position: position)
        var devices = discoverySession.devices
        if(devices.isEmpty){
            //try to get fallback devices
            cameraConfiguration.setDeviceTypes(deviceTypes: [])
            print("selectDevice","didn't find devices with initial query, searching with fallback \(cameraConfiguration.getDeviceTypeStrings())")
            discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: cameraConfiguration.getDeviceTypes(), mediaType: .video, position: position)
            devices = discoverySession.devices
        }
        
        guard !devices.isEmpty else { return nil}
        print("selectDevice","number of available devices for criteria: \(devices.count)")
        return devices.first(where: { device in device.position == position })!
    }
    
    //MARK: Public functions
    
    /// returns the photoOutput for custom takePicture implementation
    @objc public func getPhotoOutput() -> AVCapturePhotoOutput? {
        return photoOutput
    }
    
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
        print("start camera...")
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
    
    //MARK: Focus request handling
    
    /** Focus request with a callback
    - Parameters:
      - pointOfInterest: Point of interest ranging from {0,0} to {1,1}. This coordinate system is always relative to a landscape device orientation with the home button on the right, regardless of the actual device orientation.
      - requestTimeout: Focus request will time out after the defined duration (in seconds). Default is 2.0.
      - completion: Closure for focus request.
      - locked: Callback completion result. **True** if the device successfully found focus and **false** if focus has not been locked before timing out. Note that some device types might return false even when focus is found.
     
 # Code
 ```
 cameraSession?.requestFocusWithCallback(
     pointOfInterest: pointOfInterest,
     requestTimeout: 2.0,
     completion: {locked in
        print("locked",locked)
 })
 ```
     
 */
    public func requestFocusWithCallback(pointOfInterest:CGPoint?, requestTimeout:Double?, completion: @escaping (_ locked:Bool) -> Void){
        
        if(requestTimeout != nil){
            self.focusCallbackTimeout = requestTimeout!
        }
        
        requestFocus(pointOfInterest: pointOfInterest)
        
        if(focusTimeoutHandler != nil){
            if(focusTimeoutHandler!.isValid){
                print("focusCallback", "invalidate current request")
                focusTimeoutHandler?.invalidate()
            }
        }
        
        currentFocuscallbackTime = 0.0
        
        focusTimeoutHandler = Timer.scheduledTimer(withTimeInterval: self.focusCallbackInterval, repeats: true) {timer in
            
            self.currentFocuscallbackTime += self.focusCallbackInterval
            
            if(self.currentFocuscallbackTime >= self.focusCallbackMinimumTime){
            
                if let focusMode:AVCaptureDevice.FocusMode = self.captureDevice?.focusMode {
                    if(focusMode == .locked){
                        print("focusCallback", "auto focus is now locked!")
                        timer.invalidate()
                        self.currentFocuscallbackTime = 0.0
                        completion(true)
                        return
                    }else if(focusMode == .continuousAutoFocus){
                        if(self.captureDevice!.isAdjustingFocus){
                            print("focusCallback", "no longer adjusting focus")
                            timer.invalidate()
                            self.currentFocuscallbackTime = 0.0
                            completion(true)
                            return
                        }
                    }
                }
            }
            
            print("focusCallback","timer is now at \(self.currentFocuscallbackTime)")
            if(self.currentFocuscallbackTime>=self.focusCallbackTimeout){
                timer.invalidate()
                self.currentFocuscallbackTime = 0.0
                completion(false)
            }
        }
    }
    
    /// Lens focus request.
    /// - Parameter pointOfInterest: Point of interest ranging from {0,0} to {1,1}. This coordinate system is always relative to a landscape device orientation with the home button on the right, regardless of the actual device orientation.
    public func requestFocus(pointOfInterest:CGPoint?){
        guard let device = captureDevice else {
            print("requestFocus","couldn't define capture device")
            return
        }
        
        if(!device.isFocusModeSupported(.continuousAutoFocus) && !device.isFocusModeSupported(.autoFocus)){
            print("requestFocus","device doesn't support focus requests")
            return
        }
        
        do{
            try device.lockForConfiguration()
        }catch {
            print(error)
            return
        }
        
        device.isSmoothAutoFocusEnabled = device.isSmoothAutoFocusSupported
        if(device.isAutoFocusRangeRestrictionSupported){
            device.autoFocusRangeRestriction = .none
        }
        
        if(device.isFocusPointOfInterestSupported && pointOfInterest != nil){
            device.focusPointOfInterest = pointOfInterest!
        }else{
            print("requestFocus","POI not supported")
        }
        if(cameraConfiguration.continuousFocus){
            print("requestFocus","request continuousAuto")
            if(device.isFocusModeSupported(.continuousAutoFocus)){
                device.focusMode = .continuousAutoFocus
            }else{
                print("requestFocus","mode continuousAuto not supported")
                device.focusMode = .autoFocus
                cameraConfiguration.continuousFocus = false
            }
        }else{
            print("requestFocus","request auto")
            if(device.isFocusModeSupported(.autoFocus)){
                device.focusMode = .autoFocus
            }else{
                print("requestFocus","mode auto not supported")
                device.focusMode = .continuousAutoFocus
                
                cameraConfiguration.continuousFocus = true
            }
        }
        
        
        device.unlockForConfiguration()
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
        print("update orientation...")
        switch deviceOrientation {
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
            capture_connection.videoOrientation = .landscapeRight
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
            capture_connection.videoOrientation = .landscapeLeft
        case .portrait, .portraitUpsideDown, .unknown:
            connection.videoOrientation = .portrait
            capture_connection.videoOrientation = .portrait
        default: // .faceUp, .faceDown
            break
        }
        
        guard let device = captureDevice else {
            return
        }
        
        
        if(lastOrientation != deviceOrientation){
            if(deviceOrientation == .faceUp || deviceOrientation == .faceDown){
                print("faceUp or faceDown, return!")
                return
            }
            lastOrientation = deviceOrientation
        }else{
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
        print("setOrientation",orientation)
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
        print("onConfigurationsChanged", "configurations were changed and applied")
        //if there are any critical changes that require session reconfiguration, run initCamera instead
        if(currentCameraPosition != cameraConfiguration.getCameraPosition() || deviceArrayHasChanged()){
            print("onConfigurationsChanged", "reinitialize the camera")
            stopCamera()
            sessionQueue.resume()
            initCamera()
            var orientationString:String = "portrait"
            if(lastOrientation == .landscapeLeft){
                orientationString = "landscapeLeft"
            }else if(lastOrientation == .landscapeRight){
                orientationString = "landscapeRight"
            }
            setOrientation(orientation: orientationString)
            return
        }
        
        print("onConfigurationsChanged", "apply device and runtime configurations")
        guard let device:AVCaptureDevice = self.captureDevice else {
            return
        }
        self.configureDevice(device: device)
        self.configureRuntimeSettings(device: device)
    }
    
    
    private func deviceArrayHasChanged()->Bool{
        guard let device_types:[AVCaptureDevice.DeviceType] = currentDeviceTypes else {
            print("deviceArrayHasChanged","device_types not defined")
            return false
        }
        
        let configTypes = cameraConfiguration.getDeviceTypes()
        
        if(device_types.count != configTypes.count){
            print("deviceArrayHasChanged","different array sizes!")
            return true
        }
        
        for i in 0 ... device_types.count-1 {
            if(device_types[i] != configTypes[i]){
                print("deviceArrayHasChanged","index \(i) is different in arrays!")
                return true
            }
        }
        
        print("deviceArrayHasChanged","no changes detected")
        return false
    }
    
}
