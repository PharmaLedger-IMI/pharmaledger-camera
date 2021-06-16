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
     - Parameter byteArray: Preview image output as an UInt8 byte array
     # Code
      ```
     func previewFrameCallback(byteArray: [UInt8]) {
     
     }
      ```
     */
    @objc func previewFrameCallback(cgImage:CGImage)
    
    /**
     - Parameter imageData: CaptureCallback Data object
     # Code
      ```
     func captureCallback(imageData: Data) {
         let filedir = cameraPreview?.savePhotoToFiles(imageData: imageData, fileName: "test")
         print("file saved to \(filedir!)")
     }
      ```
     */
    @objc func captureCallback(imageData:Data)
}
