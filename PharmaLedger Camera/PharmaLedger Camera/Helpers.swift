// 
//  Helpers.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 15.6.2021.
//  Copyright © 2021 TrueMed Inc. All rights reserved.
//
	

import Foundation
import AVFoundation
import UIKit
import Photos


//MARK: File saving

/**
 Saves the image to photos library. Requires NSPhotoLibraryUsageDescription declaration in Info.plist file.
 - Parameter imageData Data object received from the photo capture callback
 */
public func savePhotoToLibrary(imageData: Data){
    PHPhotoLibrary.requestAuthorization { (status) in
        if status == .authorized{
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
                
            }, completionHandler: { success, error in
                if !success, let error = error {
                    print("error creating asset: \(error)")
                    
                }else{
                    print("file saved succesfully!")
                }
                
            })
            
        }else{
            
        }
    }
}

/**
 Saves the image data to the app file directory. Returns the final absolute path to the file as String
 - Parameters:
    - imageData: Data object received from the photo capture callback
    - fileName: Name for the saved image (.jpg will be appended to the end)
 - Returns: Absolute String path of the saved file.
 */
public func savePhotoToFiles(imageData: Data, fileName:String) -> String?{
    guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
        print("Failed to save photo")
        return nil
    }
    let finalPath = "\(directory.absoluteString!)\(fileName).jpg"
    
    do {

        try imageData.write(to: URL.init(string: finalPath)!)
        print("Data written to \(finalPath)")
        return finalPath
    }catch{
        print("Data write failed: \(error.localizedDescription)")
        return nil
    }
    
}

//MARK: Helpers

/**
 Converts a samplebuffer to UIImage that can be presented in UI views
 */
public func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer, ciContext:CIContext) -> UIImage?{
    guard let cgImage = cgImageFromSampleBuffer(sampleBuffer: sampleBuffer, ciContext: ciContext) else { return nil }
    return UIImage(cgImage: cgImage)
}

/// Converts the samplebuffer to CGImage
/// - Parameters:
///   - sampleBuffer: CMSamplebuffer received from the camera preview feed
///   - ciContext: CIContext required for creating the CGImage
/// - Returns: CGImage
public func cgImageFromSampleBuffer(sampleBuffer:CMSampleBuffer, ciContext:CIContext) -> CGImage? {
    
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return cgImage
    
}

/**
 Converts samplebuffer to byte array
 */
public func byteArrayFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> [UInt8]{
    let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
    
    CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let byterPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
    let srcBuff = CVPixelBufferGetBaseAddress(imageBuffer)
    
    let data = NSData(bytes: srcBuff, length: byterPerRow * height)
    CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

    return [UInt8].init(repeating: 0, count: data.length / MemoryLayout<UInt8>.size)
}

/// Get a Data object from CMSampleBuffer
/// - Parameters:
///   - sampleBuffer: CMSamplebuffer received from the camera preview feed
///   - ciContext: CIContext required for creating the CGImage
///   - jpegCompression: Compression level of the bitmap in range (max 1.0)
/// - Returns: Data that can be converted to standard UInt8 byte array for example
public func dataFromSampleBuffer(sampleBuffer: CMSampleBuffer, ciContext:CIContext, jpegCompression:CGFloat) -> Data?{
    let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer, ciContext: ciContext)
    guard let data:Data = image?.jpegData(compressionQuality: jpegCompression) else {
        return nil
    }
    return data
}

/**
 Converts a Data object to UInt8 byte array
 - Parameter imageData: Data object received from the capture callback
 - Returns Byte array in UInt8 form
 */
public func imageDataToBytes(imageData:Data) -> [UInt8] {
    return [UInt8](imageData)
}

