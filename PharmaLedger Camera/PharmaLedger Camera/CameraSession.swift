//
//  CameraSession.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 7.6.2021.
//  Copyright © 2021 TrueMed Inc. All rights reserved.
//

import AVFoundation
import UIKit

protocol CameraSessionDelegate {
    func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer)
    func onCapture(imageData:Data)
    func onCameraInitialized()
}

class CameraSession:NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate{
    
    //MARK: Constants and variables

    private var captureSession:AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "camera_session_queue")
    let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
        [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera],
        mediaType: .video, position: .back)
    private var cameraSessionDelegate:CameraSessionDelegate?
    private var photoOutput: AVCapturePhotoOutput?
    
    private var cameraPermissionGranted = false
    
    private enum ConfigurationResult{
        case permissionsDenied
        case deviceDiscoveryFailure
        case deviceInputFailure
        case deviceOutputFailure
        case deviceOutputConnectionFailure
        case videoOrientationFailure
        case videoMirroringFailure
        case photoOutputFailure
        case success
    }
    
    //MARK: Initialization
    
    init(cameraSessionDelegate:CameraSessionDelegate) {
        super.init()
        print("CameraSession","init with delegate")
        self.cameraSessionDelegate = cameraSessionDelegate
        self.initCamera()
    }
    
    func initCamera(){
        print("CameraSession","initalizing camera...")
        checkPermission()
        sessionQueue.async { [unowned self] in
            let configuration = self.configureSession()
            if(configuration == .success){
                captureSession?.commitConfiguration()
                captureSession?.startRunning()
                cameraSessionDelegate?.onCameraInitialized()
                print("CameraSession","Camera successfully configured")
            }else{
                print("configuration error!","Error: \(configuration)")
            }
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
        
        guard connection.isVideoOrientationSupported else {
            return .videoOrientationFailure
        }
        guard connection.isVideoMirroringSupported else {
            return .videoMirroringFailure
        }
        connection.videoOrientation = .portrait
        
        photoOutput = AVCapturePhotoOutput()
        photoOutput?.isHighResolutionCaptureEnabled = true
        
        guard (captureSession?.canAddOutput(photoOutput!))! else {
            return .photoOutputFailure
        }
        captureSession?.addOutput(photoOutput!)
        
        return .success
    }
    
    private func selectDevice(in position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = self.discoverySession.devices
        guard !devices.isEmpty else { return nil}

        return devices.first(where: { device in device.position == position })!
    }
    
    //MARK: Public functions
    
    func stopCamera(){
        captureSession?.stopRunning()
        sessionQueue.suspend()
    }
    
    func takePicture(){
        
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        
        photoOutput?.capturePhoto(with: photoSettings, delegate: self)
    }
    
    //MARK: Preview and capture callbacks
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        //guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        
        DispatchQueue.main.async { [unowned self] in
            self.cameraSessionDelegate?.onCameraPreviewFrame(sampleBuffer: sampleBuffer)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        cameraSessionDelegate?.onCapture(imageData: imageData)
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
            /*
            if(!self.cameraPermissionGranted){
                self.delegate?.onCameraPermissionDenied()
            }
            */
        }
    }
}
