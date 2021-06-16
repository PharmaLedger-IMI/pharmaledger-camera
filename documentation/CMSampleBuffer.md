# Extensions on CMSampleBuffer

## Methods

### `bufferToCGImage(ciContext:)`

Converts the samplebuffer to CGImage

``` swift
public func bufferToCGImage(ciContext:CIContext) ->CGImage?
```

#### Parameters

  - ciContext: CIContext required for creating the CGImage

#### Returns

CGImage

### `bufferToUIImage(ciContext:)`

Converts the samplebuffer to UIImage

``` swift
public func bufferToUIImage(ciContext:CIContext) ->UIImage?
```

#### Parameters

  - ciContext: CIContext required for creating the CGImage

#### Returns

UIImage

### `bufferToData(ciContext:jpegCompression:)`

Converts the samplebuffer to a Data object

``` swift
public func bufferToData(ciContext:CIContext, jpegCompression:CGFloat) -> Data? 
```

#### Parameters

  - ciContext: CIContext required for creating the CGImage
  - jpegCompression: JPEG Compression level for the Data. Maximum is 1.0

#### Returns

Data
