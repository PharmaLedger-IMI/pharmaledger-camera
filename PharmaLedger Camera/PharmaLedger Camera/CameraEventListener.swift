//
//  CameraEventListener.swift
//  PharmaLedger Camera
//
//  Created by Ville Raitio on 10.6.2021.
//

import Foundation

@objc public protocol CameraEventListener{
    @objc func previewFrameCallback(byteArray:[UInt8])
    @objc func captureCallback(imageData:Data)
}
