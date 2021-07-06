// 
//  SettingsView.swift
//  Camera Sample
//
//  Created by Ville Raitio on 23.6.2021.
//  
//
	

import UIKit

/// Delegate for setting changes
protocol SettingsViewDelegate {
    func onTorchLevelChanged(level:Float)
    func onColorSpaceChanged(color_space:String)
    func onFlashModeChanged(flash_mode:String)
    func onSaveModeChanged(save_mode:String)
    func onSessionPresetChanged(session_preset:String)
}

/// Scrollable view containing camera settings
class SettingsView:UIScrollView, UIPickerViewDelegate, UIPickerViewDataSource{
    
    //MARK: UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if(pickerView == flashmodePicker){
            return flashModeValues.count
        }else if(pickerView == colorSpacePicker){
            return colorSpaceValues.count
        }else if(pickerView == saveModePicker){
            return saveModeValues.count
        }else if(pickerView == sessionPresetPicker){
            return sessionPresetValues.count
        }else{
            return 1
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if(pickerView == flashmodePicker){
            return flashModeValues[row]
        }else if(pickerView == colorSpacePicker){
            return colorSpaceValues[row]
        }else if(pickerView == saveModePicker){
            return saveModeValues[row]
        }else if(pickerView == sessionPresetPicker){
            return sessionPresetValues[row]
        }else{
            return ""
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if(pickerView == flashmodePicker){
            self.currentFlashMode = flashModeValues[row]
            self.settingsViewDelegate?.onFlashModeChanged(flash_mode: self.currentFlashMode)
            print("current flash mode: \(self.currentFlashMode)")
        }else if(pickerView == colorSpacePicker){
            self.currentColorSpace = colorSpaceValues[row]
            self.settingsViewDelegate?.onColorSpaceChanged(color_space: self.currentColorSpace)
            print("current color space: \(self.currentColorSpace)")
        }else if(pickerView == saveModePicker){
            self.currentSaveMode = saveModeValues[row]
            self.settingsViewDelegate?.onSaveModeChanged(save_mode: self.currentSaveMode)
            print("current save mode: \(self.currentSaveMode)")
        }else if(pickerView == sessionPresetPicker){
            self.currentSessionPreset = sessionPresetValues[row]
            self.settingsViewDelegate?.onSessionPresetChanged(session_preset: self.currentSessionPreset)
        }else{
            
        }
    }
    
    private let containerView:UIStackView = UIStackView.init()
    
    private let flashModeLabel:UILabel = UILabel.init()
    private let flashmodePicker:UIPickerView = UIPickerView.init()
    
    private let colorSpaceLabel:UILabel = UILabel.init()
    private let colorSpacePicker:UIPickerView = UIPickerView.init()
    
    private let saveModeLabel:UILabel = UILabel.init()
    private let saveModePicker:UIPickerView = UIPickerView.init()
    
    private let torchLevelLabel:UILabel = UILabel.init()
    private let torchLevelSlider:UISlider = UISlider.init()
    
    private let sessionPresetLabel:UILabel = UILabel.init()
    private let sessionPresetPicker:UIPickerView = UIPickerView.init()
    
    private let colorSpaceValues:[String] = ["default", "sRGB", "P3_D65", "HLG_BT2020"]
    private var currentColorSpace = "default"
    
    private let flashModeValues:[String] = ["auto", "torch", "flash", "off"]
    private var currentFlashMode = "auto"
    
    private let saveModeValues:[String] = ["files", "photos"]
    private var currentSaveMode = "files"
    
    private let sessionPresetValues:[String] = ["photo",
                                                "low",
                                                "medium",
                                                "vga640x480",
                                                "high",
                                                "inputPriority",
                                                "hd1280x720",
                                                "hd1920x1080",
                                                "hd4K3840x2160",
                                                "iFrame960x540",
                                                "iFrame1280x720",
                                                "cif352x288"]
    private var currentSessionPreset = "photo"
    
    private var torchLevel:Float = 1.0
    
    var settingsViewDelegate:SettingsViewDelegate?
    
    func getCurrentColorSpace()->String{
        return currentColorSpace
    }
    func getCurrentFlashMode() -> String {
        return currentFlashMode
    }
    func getCurrentSaveMode() -> String {
        return currentSaveMode
    }
    func getCurrentTorchLevel() -> Float {
        return torchLevel
    }

    func setColorSpace(color_space:String){
        self.currentColorSpace = color_space
        colorSpacePicker.selectRow(colorSpaceValues.firstIndex(of: color_space) ?? 0, inComponent: 0, animated: false)
    }
    
    func setFlashMode(flash_mode:String){
        self.currentFlashMode = flash_mode
        flashmodePicker.selectRow(flashModeValues.firstIndex(of: flash_mode) ?? 0, inComponent: 0, animated: false)
    }
    
    func setTorchLevel(torch_level:Float){
        self.torchLevel = torch_level
        self.torchLevelSlider.value = self.torchLevel
    }
    
    override func didMoveToSuperview() {
        containerView.alignment = .center
        containerView.distribution = .equalSpacing
        containerView.spacing = 10
        containerView.axis = .vertical
        isUserInteractionEnabled = true
        clipsToBounds = true
        
        flashModeLabel.translatesAutoresizingMaskIntoConstraints = false
        flashmodePicker.translatesAutoresizingMaskIntoConstraints = false
        colorSpaceLabel.translatesAutoresizingMaskIntoConstraints = false
        colorSpacePicker.translatesAutoresizingMaskIntoConstraints = false
        torchLevelLabel.translatesAutoresizingMaskIntoConstraints = false
        torchLevelSlider.translatesAutoresizingMaskIntoConstraints = false
        saveModeLabel.translatesAutoresizingMaskIntoConstraints = false
        saveModePicker.translatesAutoresizingMaskIntoConstraints = false
        sessionPresetLabel.translatesAutoresizingMaskIntoConstraints = false
        sessionPresetPicker.translatesAutoresizingMaskIntoConstraints = false
        
        
        //labels
        flashModeLabel.text = "Flash mode:"
        colorSpaceLabel.text = "Color space:"
        saveModeLabel.text = "Save mode:"
        sessionPresetLabel.text = "Session preset:"
        torchLevelLabel.text = "Torch level: \(torchLevel)"
        
        //torch level slider
        torchLevelSlider.minimumValue = 0.1
        torchLevelSlider.maximumValue = 1.0
        torchLevelSlider.value = torchLevel
        torchLevelSlider.isContinuous = false
        torchLevelSlider.addTarget(self, action: #selector(updateTorchLevel), for: .valueChanged)
        
        //pickers
        flashmodePicker.delegate = self
        flashmodePicker.dataSource = self
        colorSpacePicker.delegate = self
        colorSpacePicker.dataSource = self
        saveModePicker.delegate = self
        saveModePicker.dataSource = self
        sessionPresetPicker.dataSource = self
        sessionPresetPicker.delegate = self
        
        //add views to container
        containerView.addArrangedSubview(flashModeLabel)
        containerView.addArrangedSubview(flashmodePicker)
        containerView.addArrangedSubview(torchLevelLabel)
        containerView.addArrangedSubview(torchLevelSlider)
        containerView.addArrangedSubview(colorSpaceLabel)
        containerView.addArrangedSubview(colorSpacePicker)
        containerView.addArrangedSubview(saveModeLabel)
        containerView.addArrangedSubview(saveModePicker)
        containerView.addArrangedSubview(sessionPresetLabel)
        containerView.addArrangedSubview(sessionPresetPicker)
        
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        let widthmodifier:CGFloat = -80
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),// constant: 20),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),// constant: -20),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            containerView.widthAnchor.constraint(equalTo: widthAnchor),// constant: -40),
            containerView.heightAnchor.constraint(greaterThanOrEqualTo: heightAnchor),
            torchLevelSlider.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: widthmodifier),
            flashmodePicker.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: widthmodifier),
            saveModePicker.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: widthmodifier),
            colorSpacePicker.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: widthmodifier),
            sessionPresetPicker.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: widthmodifier),
        ])
    }
    
    @objc func updateTorchLevel(){
        self.torchLevel = torchLevelSlider.value
        self.settingsViewDelegate?.onTorchLevelChanged(level: self.torchLevel)
        self.torchLevelLabel.text = "Torch level: \(self.torchLevel)"
    }
    
}
