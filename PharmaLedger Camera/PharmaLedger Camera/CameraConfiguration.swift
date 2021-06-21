// 
//  CameraConfiguration.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 21.6.2021.
//  
//
	

import Foundation
import AVFoundation

protocol CameraConfigurationChangeListener {
    func onConfigurationsChanged()
}

/// CameraConfiguration class that contains all the necessary configurations for the camera
public class CameraConfiguration {
    
    private var flash_configuration:String = "auto"
    private var torchmode:AVCaptureDevice.TorchMode = .auto
    private var flashmode:AVCaptureDevice.FlashMode = .auto
    private var torchlevel:Float = 1.0
    
    var delegate:CameraConfigurationChangeListener?
    
    //MARK: Initialization
    
    /// Initializes the camera confifugration with default values. To further customize the configuration, call any
    public init() {
        self.setFlashConfiguration(flash_mode: "auto")
        self.torchlevel = 1.0
        print("camConfig","initialized")
    }
    
    /// Initialize the camera session with customizable configurations.
    /// - Parameter flash_mode: Available modes are "torch", "flash", "off" and "auto"
    public init(flash_mode: String) {
        self.setFlashConfiguration(flash_mode: flash_mode)
    }
    
    //MARK: Getters
    
    /// Returns the current torch mode in AVCaptureDevice.TorchMode format
    /// - Returns: TorchMode (.on, .auto or .off)
    public func getTorchMode()->AVCaptureDevice.TorchMode {
        return self.torchmode
    }
    
    /// Returns the current flash and torch mode in String format
    /// - Returns: "torch", "flash", "off" or "auto"
    public func getFlashConfiguration()->String?{
        return flash_configuration
    }
    
    /// Returns the current torch mode in AVCaptureDevice.FlashMode format to be used with the photo capture
    /// - Returns: FlashMode (.on, .auto or .off)
    public func getFlashMode()->AVCaptureDevice.FlashMode{
        return flashmode
    }
    
    /// Get the current torch level
    /// - Returns: Torch level from 0-1.0. Default is 1.0
    public func getTorchLevel()->Float {
        return torchlevel
    }
    
    //MARK: Setters
    
    /// Sets the camera torch and flash mode
    /// - Parameter flash_mode: Available modes are "torch", "flash", "off" and "auto"
    public func setFlashConfiguration(flash_mode:String){
        self.flash_configuration = flash_mode
        switch flash_mode {
        case "torch":
            self.torchmode = .on
            self.flashmode = .auto
            break
        case "off":
            self.torchmode = .off
            self.flashmode = .off
            break
        case "flash":
            self.torchmode = .auto
            self.flashmode = .on
            break
        default:
            self.torchmode = .auto
            self.flashmode = .auto
            break
        }
        print("camConfig","torch mode set to \(flash_mode)")
        self.delegate?.onConfigurationsChanged()
    }
    
    
    /// Sets the torch level
    /// - Parameter level: Float in the range of 0 to 1.0
    public func setTorchLevel(level:Float){
        self.torchlevel = level
        self.delegate?.onConfigurationsChanged()
    }
    
}
