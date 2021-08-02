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
    private var sessionPreset:AVCaptureSession.Preset = .photo
    private var aspectRatio:CGFloat = 4.0/3.0
    
    private var colorSpace:AVCaptureColorSpace?
    
    /// List of supported aspect ratios. 16/9 || 4/3 || 11/9
    public let supportedAspectRatios:[CGFloat] = [16.0/9.0, 4.0/3.0, 11.0/9.0]
    
    var delegate:CameraConfigurationChangeListener?
    
    /** If true, the CameraSession will monitor device orientation changes and automatically swap the camera preview and photo capture orientation between "portrait", "landscapeLeft" and "landscapeRight"
     
     Default: true
     
     This variable should be defined
     before the camera is initialized.
     */
    public var autoOrientationEnabled:Bool = true
    
    /** Defines the preferred [AVCaptureDevice.FocusMode](https://developer.apple.com/documentation/avfoundation/avcapturedevice/focusmode).
     If true, preferred focusmode will be set to **continuousAutoFocus**, otherwise the mode will switch between **autoFocus** and **locked**.
     
     Default: true
     
     */
    public var continuousFocus:Bool = true
    
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
    /// - Parameter session_preset: Session preset in String format. See **setSessionPreset** for more information.
    /// - Parameter auto_orienation_enabled: If set to true, camera session will attempt to automatically adjust the preview and capture orientation based on the device orientation
    public init(flash_mode: String?, color_space:String?, session_preset:String?, auto_orienation_enabled:Bool) {
        self.setFlashConfiguration(flash_mode: flash_mode ?? self.flash_configuration)
        self.setPreferredColorSpace(color_space: color_space ?? "")
        self.autoOrientationEnabled = auto_orienation_enabled
        self.setSessionPreset(preset: session_preset)
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
            self.torchmode = .off
            self.flashmode = .on
            break
        default:
            self.torchmode = .off
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
    
    //MARK: Session presets and aspect ratio
    
    /**
     Sets the desired aspect ratio. If an unsupported aspect ratio is given, the closest possible aspect ratio will be selected
     
     Session preset will be assigned as follows:
     - 4/3: .photo
     - 16/9: .high
     - 11/9: .cif352x288
     
     - Parameter aspectRatio: Supported values are 4/3, 16/9 and 11/9
     
     */
    public func setAspectRatio(aspectRatio:CGFloat){
        var closestAspectRatio:CGFloat = 4.0/3.0
        if(!supportedAspectRatios.contains(aspectRatio)){
            //get the closest desired aspect ratio
            var distanceToClosestAspectRatio:CGFloat = abs(aspectRatio - closestAspectRatio)
            for ratio in supportedAspectRatios {
                let distanceToAspectRatio = abs(aspectRatio - ratio)
                if(distanceToAspectRatio < distanceToClosestAspectRatio){
                    distanceToClosestAspectRatio = distanceToAspectRatio
                    closestAspectRatio = ratio
                }
            }
        }else{
            closestAspectRatio = aspectRatio
        }
        self.aspectRatio = closestAspectRatio
        if(self.aspectRatio == 4.0/3.0){
            sessionPreset = .photo
        }else if(self.aspectRatio == 16.0/9.0){
            sessionPreset = .high
        }else{
            sessionPreset = .cif352x288
        }
    }
    
    /// Sets the session preset
    /// - Parameter preset: Session preset in String format.
    ///
    /// 4:3 parameters:
    /// - "photo"
    /// - "low"
    /// - "medium"
    /// - "vga640x480"
    ///
    /// 16:9 parameters:
    /// - "high"
    /// - "inputPriority"
    /// - "hd1280x720"
    /// - "hd1920x1080"
    /// - "hd4K3840x2160"
    /// - "iFrame960x540"
    /// - "iFrame1280x720"
    ///
    ///  11:9 parameters:
    /// - "cif352x288"
    ///
    /// See [AVCaptureSession.Preset documentation by Apple](https://developer.apple.com/documentation/avfoundation/avcapturesession/preset) for more information
    public func setSessionPreset(preset:String?){
        switch preset {
        case "low":
            sessionPreset = .low
            aspectRatio = 4.0/3.0
        case "medium":
            sessionPreset = .medium
            aspectRatio = 4.0/3.0
        case "high":
            sessionPreset = .high
            aspectRatio = 16.0/9.0
        case "inputPriority":
            sessionPreset = .inputPriority
            aspectRatio = 16.0/9.0
        case "hd1280x720":
            sessionPreset = .hd1280x720
            aspectRatio = 16.0/9.0
        case "hd1920x1080":
            sessionPreset = .hd1920x1080
            aspectRatio = 16.0/9.0
        case "hd4K3840x2160":
            sessionPreset = .hd4K3840x2160
            aspectRatio = 16.0/9.0
        case "iFrame960x540":
            sessionPreset = .iFrame960x540
            aspectRatio = 16.0/9.0
        case "iFrame1280x720":
            sessionPreset = .iFrame1280x720
            aspectRatio = 16.0/9.0
        case "vga640x480":
            sessionPreset = .vga640x480
            aspectRatio = 4.0/3.0
        case "cif352x288":
            sessionPreset = .cif352x288
            aspectRatio = 11.0/9.0
        default://photo
            sessionPreset = .photo
            aspectRatio = 4.0/3.0
        }
    }
    
    /// Returns the current session preset
    /// - Returns: Session preset as String
    public func getSessionPresetString() -> String {
        switch sessionPreset {
        case .low: return "low"
        case .high: return "high"
        case .medium: return "medium"
        case .inputPriority: return "inputPriority"
        case .hd1280x720: return "hd1280x720"
        case .hd1920x1080: return "hd1920x1080"
        case .hd4K3840x2160: return "hd4K3840x2160"
        case .iFrame960x540: return "iFrame960x540"
        case .iFrame1280x720: return "iFrame1280x720"
        case .vga640x480: return "vga640x480"
        case .cif352x288: return "cif352x288"
        case .photo: return "photo"
        default: return ""
        }
    }
    
    /// Returns the current session preset
    /// - Returns: Session preset as [AVCaptureSession.Preset](https://developer.apple.com/documentation/avfoundation/avcapturesession/preset) enum
    public func getSessionPreset() -> AVCaptureSession.Preset {
        return sessionPreset
    }
    
    /// Get the current configuration aspect ratio
    /// - Returns: Camera aspect ratio, eg. 4.0/3.0 (longer side divided by shorter side)
    public func getAspectRatio() -> CGFloat{
        return aspectRatio
    }
}
