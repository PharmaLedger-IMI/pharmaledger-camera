//
//  CameraEventListener.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 10.6.2021.
//  Copyright © 2021 TrueMed Inc. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

/**
 Public event listener for camera callbacks, such as preview frames, photo capture and initialization
 */
@objc public protocol CameraEventListener{
    /**
     Provides the sample buffer of the camera preview feed
     - Parameter sampleBuffer: CMSampleBuffer that can be buffered into an image or data object
     
     # Code
     ```
     func onPreviewFrame(sampleBuffer: CMSampleBuffer){
        //Convert the sample buffer into an UI image so that it can be displayed in UIImage view
        guard let image:UIImage = sampleBuffer.bufferToUIImage(ciContext: self.ciContext) else {
             return
         }
        mImageView.image = image
     }
     ```
     */
    @objc func onPreviewFrame(sampleBuffer: CMSampleBuffer)
    /**
     Provides the image output of the photo capture.
     - Parameter imageData: Data object of the photo capture image
     
     # Code
     ```
     func onCapture(imageData: Data) {
         guard let filedir = imageData.savePhotoToFiles(fileName: "test") else {
             //Something went wrong when saving the file
             return
         }
         print("file saved to \(filedir)")
     }
     ```
     */
    @objc func onCapture(imageData:Data)
    
    /// Called when the camera initialization has finished
    @objc func onCameraInitialized()
}
