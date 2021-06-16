# CameraSessionDelegate

``` swift
@objc public protocol CameraSessionDelegate 
```

## Requirements

### onCameraPreviewFrame(sampleBuffer:​)

Provides the sample buffer of the camera preview feed

``` swift
@objc func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer)
```

### Code

``` 
func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer){
   //Convert the sample buffer into an UI image so that it can be displayed in UIImage view
   guard let image:UIImage = sampleBuffer.bufferToUIImage(ciContext: self.ciContext) else {
        return
    }
   mImageView.image = image
}
```

#### Parameters

  - sampleBuffer: CMSampleBuffer that can be buffered into an image or data object

### onCapture(imageData:​)

Provides the image output of the photo capture.

``` swift
@objc func onCapture(imageData:Data)
```

### Code

``` 
func onCapture(imageData: Data) {
    guard let filedir = imageData.savePhotoToFiles(fileName: "test") else {
        //Something went wrong when saving the file
        return
    }
    print("file saved to \(filedir)")
}
```

#### Parameters

  - imageData: Data object of the photo capture image

### onCameraInitialized()

Called when the camera initialization has finished

``` swift
@objc func onCameraInitialized()
```
