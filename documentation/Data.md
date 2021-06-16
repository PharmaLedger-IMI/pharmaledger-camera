# Extensions on Data

## Methods

### `savePhotoToLibrary()`

Saves the image to photos library. Requires NSPhotoLibraryUsageDescription declaration in Info.plist file.

``` swift
public func savePhotoToLibrary()
```

### `savePhotoToFiles(fileName:)`

Saves the image data to the app file directory. Returns the final absolute path to the file as String

``` swift
public func savePhotoToFiles(fileName:String) -> String?
```

#### Parameters

  - fileName: Name for the saved image (.jpg will be appended to the end)

#### Returns

Absolute String path of the saved file.

### `imageDataToBytes()`

Converts a Data object to UInt8 byte array

``` swift
public func imageDataToBytes() -> [UInt8] 
```

#### Returns

Byte array in UInt8 form
