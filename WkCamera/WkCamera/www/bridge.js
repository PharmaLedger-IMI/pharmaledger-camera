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
 * @param  {SessionPreset} sessionPreset one of the session presets available in DictSessionPreset
 * @param  {string} flashMode can be `torch`, `flash`, or `off`, all other values will be treated as `auto`
 * @param  {function} onFramePreviewCallback callBack for each preview frame. Data are received as an RGB ArrayBuffer. Can be undefined if you want to call 'getPreviewFrame' yourself
 * @param {number} targetPreviewFps fps for the preview
 * @param {number} previewWidth width for the preview data
 * @param {function} onFrameGrabbedCallBack callBack for each raw frame. Data are received as an RGB ArrayBuffer. Can be undefined if you want to call 'getRawFrame' yourself
 * @param {number} targetGrabFps fps for the full resolution raw frame
 * @param {function} onCameraInitializedCallBack called after camera initilaization is finished
 */
function startNativeCamera(sessionPreset, flashMode, onFramePreviewCallback = undefined, targetPreviewFps = 25, previewWidth = 640, onFrameGrabbedCallBack = undefined, targetGrabFps = 10, onCameraInitializedCallBack = undefined) {
    _targetPreviewFps = targetPreviewFps
    _previewWidth = previewWidth
    _onFramePreviewCallback = onFramePreviewCallback;
    _onFrameGrabbedCallBack = onFrameGrabbedCallBack;
    _onCameraInitializedCallBack = onCameraInitializedCallBack;
    _targetGrabFps = targetGrabFps
    let params = {
        "onInitializedJsCallback": onNativeCameraInitialized.name,
        "sessionPreset": sessionPreset.name,
        "flashMode": flashMode,
        "previewWidth": _previewWidth
    }
    callNative("StartCamera", params);
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
 * Takes a photo
 * @param  {function} onCaptureCallback callback reached when the picture is taken
 */
function takePictureNativeCamera(onCaptureCallback) {
    callNative("TakePicture", {"onCaptureJsCallback": onCaptureCallback.name});
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
            getPreviewFrame().then(a => {
                if (a.byteLength > 1) {
                    _onFramePreviewCallback(a, performance.now() - t0)
                }
            });
        }, 1000/_targetPreviewFps);
    }
    if (_onFrameGrabbedCallBack !== undefined) {
        _grabHandle = setInterval(() => {
            let t0 = performance.now();
            getRawFrame().then(a => {
                if (a.byteLength > 1) {
                    _onFrameGrabbedCallBack(a, performance.now() - t0);
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
 * @returns  {Promise<ArrayBuffer>} gets a downsampled RGB frame for preview
 */
function getPreviewFrame() {
    return fetch(`${_serverUrl}/previewframe`)
    .then(response => {
        return response.blob().then( b => {
            return b.arrayBuffer().then(a => {
                return a;
            })
        })
    })
    .catch( error => {
        console.log(error);
    })
}

/**
 * @returns {Promise<ArrayBuffer>} gets a raw RGB frame
 */
function getRawFrame() {
    return fetch(`${_serverUrl}/rawframe`)
    .then(response => {
        return response.blob().then( b => {
            return b.arrayBuffer().then(a => {
                return a;
            })
        })
    })
    .catch( error => {
        console.log(error);
    })
}