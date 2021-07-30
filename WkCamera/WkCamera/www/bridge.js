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
var _x = undefined;
var _y = undefined;
var _w = undefined;
var _h = undefined;

function callNative(api, args, callback) {
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
 * @param  {function} onFramePreviewCallback callBack for each preview frame. Data are received as an RGB ArrayBuffer. Can be undefined if you want to call 'getPreviewFrame' yourself
 * @param {number} targetPreviewFps fps for the preview
 * @param {number} previewWidth width for the preview data
 * @param {function} onFrameGrabbedCallBack callBack for each raw frame. Data are received as an RGB ArrayBuffer. Can be undefined if you want to call 'getRawFrame' yourself
 * @param {number} targetGrabFps fps for the full resolution raw frame
 * @param {function} onCameraInitializedCallBack called after camera initilaization is finished
 * @param  {number} x=undefined RGB raw frame ROI top-left x-coord
 * @param  {number} y=undefined RGB raw frame ROI top-left y-coord
 * @param  {number} w=undefined RGB raw frame ROI width
 * @param  {number} h=undefined RGB raw frame ROI height
 */
function startNativeCamera(sessionPresetName, flashMode, onFramePreviewCallback = undefined, targetPreviewFps = 25, previewWidth = 640, onFrameGrabbedCallBack = undefined, targetGrabFps = 10, auto_orientation_enabled=false, onCameraInitializedCallBack = undefined, x=undefined, y=undefined, w=undefined, h=undefined) {
    _targetPreviewFps = targetPreviewFps
    _previewWidth = previewWidth
    _onFramePreviewCallback = onFramePreviewCallback;
    _onFrameGrabbedCallBack = onFrameGrabbedCallBack;
    _onCameraInitializedCallBack = onCameraInitializedCallBack;
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
 * @param  {function} onCaptureCallback callback reached when the picture is taken
 */
function takePictureBase64NativeCamera(onCaptureCallback) {

    callNative("TakePicture", {"onCaptureJsCallback": onCaptureCallback.name});
}

/**
 * @returns {Promise<Blob>} gets a JPEG snapshot
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
            getRawFrame(_x, _y, _w, _h).then(image => {
                if (image instanceof PLRgbImage) {
                    _onFrameGrabbedCallBack(image, performance.now() - t0);
                }
            })
        }, 1000/_targetGrabFps)
    }
    if (_onCameraInitializedCallBack !== undefined) {
        setTimeout(() => {
            _onCameraInitializedCallBack();
        }, 500);
    }
}

/**
 * @returns  {Promise<PLRgbImage>} gets a downsampled RGB frame for preview
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
 * Gets a raw RGB frame. A ROI can be specified.
 * @param  {number} x=undefined
 * @param  {number} y=undefined
 * @param  {number} w=undefined
 * @param  {number} h=undefined
 * @returns {Promise<PLRgbImage>} a raw RGB frame
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