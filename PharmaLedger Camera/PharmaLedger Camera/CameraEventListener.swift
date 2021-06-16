//
//  CameraEventListener.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 10.6.2021.
//  Copyright © 2021 TrueMed Inc. All rights reserved.
//

import Foundation
import UIKit

/**
 Public event listener for camera preview frames and successfull capture callbacks.
 */
@objc public protocol CameraEventListener{
    /**
     - Parameter cgImage: Preview image output as a CGImage bitmap
     
     # Code
      ```
     func previewFrameCallback(cgImage: CGImage) {
        
     }
      ```
     */
    @objc func previewFrameCallback(cgImage:CGImage)
    
    /**
     - Parameter imageData: CaptureCallback Data object
     
     # Code
      ```
     func captureCallback(imageData: Data) {
         guard let filedir = imageData.savePhotoToFiles(fileName: "test") else {
             //Something went wrong when saving the file
             return
         }
         print("file saved to \(filedir)")
     }
      ```
     */
    @objc func captureCallback(imageData:Data)
}
