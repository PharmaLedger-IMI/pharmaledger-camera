# CameraEventListener

Public event listener for camera preview frames and successfull capture callbacks.

``` swift
@objc public protocol CameraEventListener
```

## Requirements

### previewFrameCallback(cgImage:​)

``` swift
@objc func previewFrameCallback(cgImage:CGImage)
```

  - Parameter cgImage: Preview image output as a CGImage bitmap

### Code

``` 
func previewFrameCallback(cgImage: CGImage) {
  
}
```

### captureCallback(imageData:​)

``` swift
@objc func captureCallback(imageData:Data)
```

  - Parameter imageData: CaptureCallback Data object

### Code

``` 
func captureCallback(imageData: Data) {
   guard let filedir = imageData.savePhotoToFiles(fileName: "test") else {
       //Something went wrong when saving the file
       return
   }
   print("file saved to \(filedir)")
}
```
