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
    
    //MARK: Constants and variables
    
    private var flash_configuration:String = "auto"
    private var torchmode:AVCaptureDevice.TorchMode = .auto
    private var flashmode:AVCaptureDevice.FlashMode = .auto
    private var torchlevel:Float = 1.0
    
    private var colorSpace:AVCaptureColorSpace?
    
    var delegate:CameraConfigurationChangeListener?
    
    /** If true, the CameraSession will monitor device orientation changes and automatically swap the camera preview and photo capture orientation between "portrait", "landscapeLeft" and "landscapeRight"
     
     Default: true
     
     This variable should be defined
     before the camera is initialized.
     */
    public var autoOrientationEnabled:Bool = true
    
    //MARK: Initialization
    
    /// Initializes the camera confifugration with default values. To further customize the configuration, call any
    public init() {
        self.setFlashConfiguration(flash_mode: "auto")
        self.torchlevel = 1.0
        self.autoOrientationEnabled = true
        print("camConfig","initialized")
    }
    
    /// Initialize the camera session with customizable configurations. Parameters that don't need to be configured can be left as nil.
    /// - Parameter flash_mode: Available modes are "torch", "flash", "off" and "auto"
    /// - Parameter color_space: Possible values are "sRGB", "P3_D65" or "HLG_BT2020".
    public init(flash_mode: String?, color_space:String?, auto_orienation_enabled:Bool) {
        self.setFlashConfiguration(flash_mode: flash_mode ?? self.flash_configuration)
        self.setPreferredColorSpace(color_space: color_space ?? "")
        self.autoOrientationEnabled = auto_orienation_enabled
    }
    
    //MARK: Public functions
    
    /// Applies the configurations to the current AVCaptureSession. This should be executed each time the configurations are changed during session runtime.
    public func applyConfiguration(){
        self.delegate?.onConfigurationsChanged()
    }
    
    //MARK: Flash and torch mode
    
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
    }
    
    /// Sets the torch level
    /// - Parameter level: Float in the range of 0 to 1.0
    public func setTorchLevel(level:Float){
        self.torchlevel = level
    }
    
    
    //MARK: Color space
    
    /// Gets the current preference for color space as AVCaptureColorSpace enum value.
    /// - Returns: Returns .sRGB, .P3_D65 or .HLG_BT2020. Returns nil if the color space configuration was undefined
    public func getPreferredColorSpace() -> AVCaptureColorSpace?  {
        return self.colorSpace
    }
    
    /// Gets the current preference for color space as String.
    /// - Returns: Returns "sRGB", "P3_D65" or "HLG_BT2020" or "undefined"
    public func getPreferredColorSpaceString() -> String{
        switch self.colorSpace {
        case .HLG_BT2020: return "HLG_BT2020"
        case .sRGB: return "sRGB"
        case .P3_D65: return "P3_D65"
        default: return "undefined"
        }
    }
    
    /** Sets the preferred color space.
     
     Depending on the device some color spaces might not be supported.
     sRGB is supported on all devices.
     HLG_BT2020 available from iOS v14.1
     
- Parameter color_space: Possible values are "sRGB", "P3_D65" or "HLG_BT2020".
     */
    public func setPreferredColorSpace(color_space:String){
        switch color_space {
        case "sRGB":
            self.colorSpace = .sRGB
            break
        case "HLG_BT2020":
            if #available(iOS 14.1, *) {
                self.colorSpace = .HLG_BT2020
            } else {
                // Fallback on earlier versions
                self.colorSpace = .P3_D65
            }
            break
        case "P3_D65":
            self.colorSpace = .P3_D65
            break
        default:
            self.colorSpace = nil
            break
        }
    }
    
}
