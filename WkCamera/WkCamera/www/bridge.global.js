import { 
    sessionPresetNames,
    getBridgeServerUrl, 
    getCameraConfiguration, 
    startNativeCamera,
    stopNativeCamera,
    setRawCropRoi,
    takePictureBase64NativeCamera,
    getSnapshot,
    setFlashModeNativeCamera,
    setTorchLevelNativeCamera, 
    setPreferredColorSpaceNativeCamera, 
    getPreviewFrame,
    getRawFrame,
    getRawFrameYCbCr } from './bridge.module.js';
import { PLRgbImage, PLYCbCrImage } from './bridge.module.js';

window["nativeCamera"] = { sessionPresetNames, getBridgeServerUrl, getCameraConfiguration, startNativeCamera, stopNativeCamera, setRawCropRoi, takePictureBase64NativeCamera, getSnapshot, setFlashModeNativeCamera, setTorchLevelNativeCamera, setPreferredColorSpaceNativeCamera, getPreviewFrame, getRawFrame, getRawFrameYCbCr, PLRgbImage, PLYCbCrImage };