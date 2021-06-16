# CameraSession

``` swift
@objc public class CameraSession:NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate
```

## Inheritance

`AVCapturePhotoCaptureDelegate`, `AVCaptureVideoDataOutputSampleBufferDelegate`, `NSObject`

## Initializers

### `init(cameraSessionDelegate:)`

``` swift
public init(cameraSessionDelegate:CameraSessionDelegate) 
```

## Properties

### `captureSession`

``` swift
public var captureSession:AVCaptureSession?
```

## Methods

### `stopCamera()`

Stops the camera session

``` swift
@objc public func stopCamera()
```

### `takePicture()`

Starts a photo capture session

``` swift
@objc public func takePicture()
```

### `captureOutput(_:didOutput:from:)`

``` swift
public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
```

### `photoOutput(_:didFinishProcessingPhoto:error:)`

``` swift
public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) 
```
