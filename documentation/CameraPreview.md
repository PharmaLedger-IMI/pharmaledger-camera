# CameraPreview

UIView CameraPreview that can be added as a sub view to existing view controllers or view containers.

``` swift
@objc public class CameraPreview:UIView,CameraSessionDelegate
```

## Inheritance

[`CameraSessionDelegate`](/CameraSessionDelegate), `UIView`

## Initializers

### `init(cameraListener:)`

Initializes the preview with camera event callbacks

``` swift
@objc public init(cameraListener:CameraEventListener)
```

#### Parameters

  - cameraListener: Protocol to notify preview byte arrays and photo capture callbacks.

### `init(frame:)`

``` swift
public override init(frame: CGRect) 
```

### `init()`

Initializes the preview with no callbacks

``` swift
@objc public init()
```

## Methods

### `onCameraPreviewFrame(sampleBuffer:)`

``` swift
public func onCameraPreviewFrame(sampleBuffer: CMSampleBuffer) 
```

### `onCapture(imageData:)`

``` swift
public func onCapture(imageData: Data) 
```

### `onCameraInitialized()`

``` swift
public func onCameraInitialized() 
```

### `takePicture()`

Requests the camera session for a photo capture.

``` swift
@objc public func takePicture()
```

### `willMove(toSuperview:)`

``` swift
public override func willMove(toSuperview newSuperview: UIView?) 
```

### `didMoveToSuperview()`

``` swift
public override func didMoveToSuperview() 
```
