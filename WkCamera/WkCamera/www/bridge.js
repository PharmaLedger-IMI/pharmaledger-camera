const sessionPresetNames = [
    "low",
    "medium",
    "high",
    "inputPriority",
    "hd1280x720",
    "hd1920x1080",
    "hd4K3840x2160",
    "iFrame960x540",
    "iFrame1280x720",
    "vga640x480",
    "cif352x288",
    "photo"
];

const deviceTypeNames = [
    "wideAngleCamera",
    "tripleCamera",
    "dualCamera",
    "dualWideCamera",
    "ultraWideAngleCamera",
    "telephotoCamera",
    "trueDepthCamera"
]

/** Class representing a raw interleaved RGB image */
class PLRgbImage {
    /**
     * create a PLRgbImage
     * @param  {ArrayBuffer} arrayBuffer contains interleaved RGB raw data
     * @param  {Number} width image width 
     * @param  {Number} height image height
     */
    constructor(arrayBuffer, width, height) {
        this.arrayBuffer = arrayBuffer;
        this.width = width;
        this.height = height;
    }
};

/**Class representing a raw YCbCr 420 image. First chunck of size wxh is the Y plane. 2nd chunk of size wxh/2 is the interleaved CbCr plane */
class PLYCbCrImage {
    /** creates a PLYCbCrImage. The Y-plane and CbCr interpleaved plane are copied seperately.
     * @param  {ArrayBuffer} arrayBuffer raw data
     * @param  {Number} width image width, must be even
     * @param  {Number} height image height, must be even
     */
    constructor(arrayBuffer, width, height) {
        this.width = width;
        this.height = height;
        if (!Number.isInteger(this.width/2) || !Number.isInteger(this.height/2)) {
            throw `Only even width and height is supported, got w=${this.width}, h=${this.height} `
        }
        this.yArrayBuffer = arrayBuffer.slice(0, this.width*this.height);
        this.cbCrArrayBuffer = arrayBuffer.slice(this.width*this.height)
    }
}

/** Class wrapping a camera configuration */
class PLCameraConfig {
    
    /** creates a camera configuration for use with function `startNativeCameraWithConfig`
     * @param  {string} sessionPreset one of the session presets available in sessionPresetNames
     * @param  {string} flashConfiguration="auto" can be `torch`, `flash`, or `off`, all other values will be treated as `auto`
     * @param  {boolean} continuousFocus=true Defines the preferred [AVCaptureDevice.FocusMode](https://developer.apple.com/documentation/avfoundation/avcapturedevice/focusmode). If true, preferred focusmode will be set to **continuousAutoFocus**, otherwise the mode will switch between **autoFocus** and **locked**.
     * @param  {boolean} autoOrientationEnabled=true If set to true, camera session will attempt to automatically adjust the preview and capture orientation based on the device orientation
     * @param  {[String]} deviceTypes=["wideAngleCamera"] Additional criteria for selecting the camera. Supported values are **tripleCamera**, **dualCamera**, **dualWideCamera**, **wideAngleCamera**, **ultraWideAngleCamera**, **telephotoCamera** and **trueDepthCamera**. Device discovery session will prioritize device types in the array based on their array index.
     * @param  {String} cameraPosition="back" "back" or "front". If not defined, this setting will default to "back"
     * @param  {boolean} highResolutionCaptureEnabled=true If high resolution is enabled, the photo capture will be taken with the highest possible resolution available.
     * @param  {string | undefined} preferredColorSpace=undefined Possible values are "sRGB", "P3_D65" or "HLG_BT2020".
     * @param  {number} torchLevel=1.0 Float in the range of 0 to 1.0
     * @param  {number} aspectRatio=4.0/3.0 This value will not be used
     * @param  {string} initOrientation="portrait" Predefines the orientation when initializing the camera (available values are "landscapeRight", "landscapeLeft" and "portrait").
     */
    constructor(sessionPreset, flashConfiguration = "auto", continuousFocus = true, autoOrientationEnabled = true, deviceTypes = ["wideAngleCamera"], cameraPosition = "back", highResolutionCaptureEnabled = true, preferredColorSpace = undefined, torchLevel = 1.0, aspectRatio = 4.0/3.0, initOrientation = "portrait") {
        this.sessionPreset = sessionPreset;
        this.flashConfiguration = flashConfiguration;
        this.torchLevel = torchLevel;
        this.continuousFocus = continuousFocus;
        this.autoOrientationEnabled = autoOrientationEnabled;
        this.deviceTypes = deviceTypes;
        this.cameraPosition = cameraPosition;
        this.highResolutionCaptureEnabled = highResolutionCaptureEnabled;
        this.preferredColorSpace = preferredColorSpace;
        this.aspectRatio = aspectRatio;
        this.initOrientation = initOrientation;
    }
}
  
var _previewHandle = undefined;
var _grabHandle = undefined;
var _onFramePreviewCallback = undefined;
var _targetPreviewFps = 20;
var _previewWidth = 0;
var _serverUrl = undefined;
var _cameraRunning = false;
var _onFrameGrabbedCallBack = undefined;
var _onCameraInitializedCallBack = undefined;
var _targetGrabFps = 10;
var _ycbcr = false;
var _x = undefined;
var _y = undefined;
var _w = undefined;
var _h = undefined;

function callNative(api, args, callback) {
    // @ts-ignore
    let handle = window.webkit.messageHandlers[api]
    let payload = {}
    if (args !== undefined) {
        payload["args"] = args
    }
    if (callback !== undefined) {
        payload["callback"] = callback.name
    }
    handle.postMessage(payload)
}




/**
 * Starts the native camera frame grabber
 * @param  {string} sessionPresetName one of the session presets available in sessionPresetNames
 * @param  {string} flashMode can be `torch`, `flash`, or `off`, all other values will be treated as `auto`
 * @param  {function} onFramePreviewCallback callBack for each preview frame. Data are received as PLRgbImage. Can be undefined if you want to call 'getPreviewFrame' yourself
 * @param {number} targetPreviewFps fps for the preview
 * @param {number} previewWidth width for the preview data
 * @param {function} onFrameGrabbedCallBack callBack for each raw frame. Data are received as PLRgbImage or PLYCbCrImage. Can be undefined if you want to call 'getRawFrame' or 'getRawFrameYCbCr' yourself
 * @param {number} targetGrabFps fps for the full resolution raw frame
 * @param {boolean} [auto_orientation_enabled=false] set to true to rotate image feed with respect to device orientation
 * @param {function} onCameraInitializedCallBack called after camera initilaization is finished
 * @param  {number} [x=undefined] RGB/YCbCr raw frame ROI top-left x-coord
 * @param  {number} [y=undefined] RGB/YCbCr raw frame ROI top-left y-coord
 * @param  {number} [w=undefined] RGB/YCbCr raw frame ROI width
 * @param  {number} [h=undefined] RGB/YCbCr raw frame ROI height
 * @param  {boolean} [ycbcr=false] set to true to receive data as YCbCr 420 in 'onFrameGrabbedCallBack'
 */
function startNativeCamera(sessionPresetName, flashMode, onFramePreviewCallback = undefined, targetPreviewFps = 25, previewWidth = 640, onFrameGrabbedCallBack = undefined, targetGrabFps = 10, auto_orientation_enabled=false, onCameraInitializedCallBack = undefined, x=undefined, y=undefined, w=undefined, h=undefined, ycbcr=false) {
    _targetPreviewFps = targetPreviewFps
    _previewWidth = previewWidth
    _onFramePreviewCallback = onFramePreviewCallback;
    _onFrameGrabbedCallBack = onFrameGrabbedCallBack;
    _onCameraInitializedCallBack = onCameraInitializedCallBack;
    _ycbcr = ycbcr;
    _targetGrabFps = targetGrabFps
    setRawCropRoi(x, y, w, h);
    let params = {
        "onInitializedJsCallback": onNativeCameraInitialized.name,
        "sessionPreset": sessionPresetName,
        "flashMode": flashMode,
        "previewWidth": _previewWidth,
        "auto_orientation_enabled": auto_orientation_enabled
    }
    callNative("StartCamera", params);
}

/**
 * @param  {PLCameraConfig} config
 * @param  {function} onFramePreviewCallback callBack for each preview frame. Data are received as PLRgbImage. Can be undefined if you want to call 'getPreviewFrame' yourself
 * @param  {number} targetPreviewFps=25 fps for the preview
 * @param  {number} previewWidth=640 width for the preview data
 * @param  {function} onFrameGrabbedCallBack=undefined callBack for each raw frame. Data are received as PLRgbImage or PLYCbCrImage. Can be undefined if you want to call 'getRawFrame' or 'getRawFrameYCbCr' yourself
 * @param  {number} targetGrabFps=10 fps for the full resolution raw frame
 * @param  {function} onCameraInitializedCallBack=undefined called after camera initilaization is finished
 * @param  {number} x=undefined RGB/YCbCr raw frame ROI top-left x-coord
 * @param  {number} y=undefined RGB/YCbCr raw frame ROI top-left y-coord
 * @param  {number} w=undefined RGB/YCbCr raw frame ROI width
 * @param  {number} h=undefined RGB/YCbCr raw frame ROI height
 * @param  {boolean} ycbcr=false set to true to receive data as YCbCr 420 in 'onFrameGrabbedCallBack'
 */
function startNativeCameraWithConfig(config, onFramePreviewCallback = undefined, targetPreviewFps = 25, previewWidth = 640, onFrameGrabbedCallBack = undefined, targetGrabFps = 10, onCameraInitializedCallBack = undefined, x=undefined, y=undefined, w=undefined, h=undefined, ycbcr=false) {
    _targetPreviewFps = targetPreviewFps
    _previewWidth = previewWidth
    _onFramePreviewCallback = onFramePreviewCallback;
    _onFrameGrabbedCallBack = onFrameGrabbedCallBack;
    _onCameraInitializedCallBack = onCameraInitializedCallBack;
    _ycbcr = ycbcr;
    _targetGrabFps = targetGrabFps
    setRawCropRoi(x, y, w, h);
    let params = {
        "onInitializedJsCallback": onNativeCameraInitialized.name,
        "previewWidth": _previewWidth,
        "config": config
    }
    callNative("StartCameraWithConfig", params);
}

/**
 * Sets the raw crop to a new position
 * @param  {number} x
 * @param  {number} y
 * @param  {number} w
 * @param  {number} h
 */
function setRawCropRoi(x, y, w, h) {
    _x = x;
    _y = y;
    _w = w;
    _h = h;
}

/**
 * Stops the native camera
 */
function stopNativeCamera() {
    clearInterval(_previewHandle)
    _previewHandle = undefined
    clearInterval(_grabHandle)
    _grabHandle = undefined
    callNative("StopCamera")
}

/**
 * Takes a photo and return it as base64 string ImageData in callback function
 * @param  {function} onCaptureCallback callback reached when the picture is taken. The callback receives the picture as base64 string
 */
function takePictureBase64NativeCamera(onCaptureCallback) {

    callNative("TakePicture", {"onCaptureJsCallback": onCaptureCallback.name});
}

/**
 * Gets a JPEG snapshot, corresponds to endpoint /snapshot
 * @returns {Promise<void | Blob>} JPEG snapshot
 */
 function getSnapshot() {
    return fetch(`${_serverUrl}/snapshot`)
    .then(response => {
        return response.blob();
    })
    .catch( error => {
        console.log(error);
    })
}

/**
 * Control camera flash mode
 * @param  {string} mode can be `torch`, `flash`, or `off`, all other values will be treated as `auto`
 */
function setFlashModeNativeCamera(mode) {
    callNative("SetFlashMode", { "mode": mode })
}

/**
 * Control camera torch level
 * @param  {number} level torch level between (0.0, 1.0]
 */
function setTorchLevelNativeCamera(level) {
    callNative("SetTorchLevel", { "level": level})
}

/**
 * Control preferred colorspace. The call may not succeed if the colorspace is not available. 
 * In this case the colorspace is reverted to undefined. 
 * @param  {string} colorspace 'sRGB', 'HLG_BT2020', 'P3_D65'
 */
function setPreferredColorSpaceNativeCamera(colorspace) {
    callNative("SetPreferredColorSpace", { "colorspace": colorspace })
}

function onNativeCameraInitialized(wsPort) {
    _serverUrl = `http://localhost:${wsPort}`
    if (_onFramePreviewCallback !== undefined) {
        _previewHandle = setInterval(() => {
            let t0 = performance.now();
            getPreviewFrame().then(image => {
                if (image instanceof PLRgbImage) {
                    _onFramePreviewCallback(image, performance.now() - t0)
                }
            });
        }, 1000/_targetPreviewFps);
    }
    if (_onFrameGrabbedCallBack !== undefined) {
        _grabHandle = setInterval(() => {
            let t0 = performance.now();
            if (_ycbcr) {
                getRawFrameYCbCr(_x, _y, _w, _h).then(image => {
                    if (image instanceof PLYCbCrImage) {
                        _onFrameGrabbedCallBack(image, performance.now() - t0);
                    }
                })
            } else {
                getRawFrame(_x, _y, _w, _h).then(image => {
                    if (image instanceof PLRgbImage) {
                        _onFrameGrabbedCallBack(image, performance.now() - t0);
                    }
                })
            }
        }, 1000/_targetGrabFps)
    }
    if (_onCameraInitializedCallBack !== undefined) {
        setTimeout(() => {
            _onCameraInitializedCallBack();
        }, 500);
    }
}

/**
 * Gets a downsampled RGB frame for preview, corresponds to endpoint /previewframe
 * @returns  {Promise<void | PLRgbImage>} Downsampled RGB frame for preview
 */
function getPreviewFrame() {
    return fetch(`${_serverUrl}/previewframe`)
    .then(response => {
        let image = getPLRgbImageFromResponse(response);
        return image;
    })
    .catch( error => {
        console.log(error);
    })
}

/**
 * Gets a raw RGB frame. A ROI can be specified, corresponds to endpoint /rawframe
 * @param  {number} [x=undefined]
 * @param  {number} [y=undefined]
 * @param  {number} [w=undefined]
 * @param  {number} [h=undefined]
 * @returns {Promise<void | PLRgbImage>} a raw RGB frame
 */
function getRawFrame(x = undefined, y = undefined, w = undefined, h = undefined) {
    let fetchString = `${_serverUrl}/rawframe`;
    let params = {};
    if (x !== undefined) {
        params.x = x;
    }
    if (y !== undefined) {
        params.y = y;
    }
    if (w !== undefined) {
        params.w = w;
    }
    if (h !== undefined) {
        params.h = h;
    }
    if (Object.keys(params).length > 0) {
        // @ts-ignore
        const urlParams = new URLSearchParams(params);
        fetchString = `${fetchString}?${urlParams.toString()}`;
    }
    return fetch(fetchString)
    .then(response => {
        let image = getPLRgbImageFromResponse(response);
        return image;
    })
    .catch( error => {
        console.log(error);
    })
}

/** Get a raw YCbCr 420 frame A ROI can be specified, corresponds to endpoint /rawframe_ycbcr
 * @param  {number} [x=undefined]
 * @param  {number} [y=undefined]
 * @param  {number} [w=undefined]
 * @param  {number} [h=undefined]
 * @returns {Promise<Void | PLYCbCrImage>} a raw YCbCr frame
 */
function getRawFrameYCbCr(x = undefined, y = undefined, w = undefined, h = undefined) {
    let fetchString = `${_serverUrl}/rawframe_ycbcr`;
    let params = {};
    if (x !== undefined) {
        params.x = x;
    }
    if (y !== undefined) {
        params.y = y;
    }
    if (w !== undefined) {
        params.w = w;
    }
    if (h !== undefined) {
        params.h = h;
    }
    if (Object.keys(params).length > 0) {
        // @ts-ignore
        const urlParams = new URLSearchParams(params);
        fetchString = `${fetchString}?${urlParams.toString()}`;
    }
    return fetch(fetchString)
    .then(response => {
        let image = getPLYCbCrImageFromResponse(response);
        return image;
    })
    .catch( error => {
        console.log(error);
    })
}
/**
 * Get the current camera configuration, corresponds to endpoint /cameraconfig
 * @returns {Promise<any>} the current camera configuration
 */
function getCameraConfiguration() {
    let fetchString = `${_serverUrl}/cameraconfig`;
    return fetch(fetchString)
    .then(response => {
        return response.json()
    })
}

/**
 * Get device information, corresponds to endpoint /deviceinfo
 * @returns {Promise<any>} the device information {"modelName": string, "systemVersion": string}
 */
function getDeviceInfo() {
    let fetchString = `${_serverUrl}/deviceinfo`;
    return fetch(fetchString)
    .then(response => {
        return response.json()
    })
}

/**
 * Packs a response from endpoints providing raw rgb buffer as octet-stream and image size in headers
 * 
 * @param  {Response} response
 * @returns {Promise<PLRgbImage>} the image in a promise
 */
function getPLRgbImageFromResponse(response) {
    let frame_w = 0
    let frame_h = 0
    if (response.headers.has("image-width")) {
        frame_w = parseInt(response.headers.get("image-width"));
    }
    if (response.headers.has("image-height")) {
        frame_h = parseInt(response.headers.get("image-height"));
    }
    return response.blob().then( b => {
        return b.arrayBuffer().then(a => {
            let image = new PLRgbImage(a, frame_w, frame_h);
            return image;
        })
    })
}

/**
 * Packs a response from endpoints providing raw YCbCr 420 buffer as octet-stream and image size in headers
 * 
 * @param  {Response} response
 * @returns {Promise<PLYCbCrImage>} the image in a promise
 */
function getPLYCbCrImageFromResponse(response) {
    let frame_w = 0
    let frame_h = 0
    if (response.headers.has("image-width")) {
        frame_w = parseInt(response.headers.get("image-width"));
    }
    if (response.headers.has("image-height")) {
        frame_h = parseInt(response.headers.get("image-height"));
    }
    return response.blob().then( b => {
        return b.arrayBuffer().then(a => {
            let image = new PLYCbCrImage(a, frame_w, frame_h);
            return image;
        })
    })
}