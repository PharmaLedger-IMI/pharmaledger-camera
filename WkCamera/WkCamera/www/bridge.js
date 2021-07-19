var grabHandle = 0;
var onFrameGrabbedCallbackRef = undefined;

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
 * @param  {function} onFrameGrabbedCallback callBack for each native frame. Data are received as a blob.
 * @param  {SessionPreset} sessionPreset one of the session presets available in DictSessionPreset
 * @param  {string} flashMode can be `torch`, `flash`, or `off`, all other values will be treated as `auto`
 */
function startNativeCamera(onFrameGrabbedCallback, sessionPreset, flashMode) {
    onFrameGrabbedCallbackRef = onFrameGrabbedCallback;
    let params = {
        "onInitializedJsCallback": onNativeCameraInitialized.name,
        "sessionPreset": sessionPreset.name,
        "flashMode": flashMode
    }
    callNative("StartCamera", params);
}

/**
 * Stops the native camera
 */
function stopNativeCamera() {
    clearInterval(grabHandle)
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
    grabHandle = setInterval(() => {
        let target = `http://localhost:${wsPort}`
        fetch(`${target}/rawframe`)
        .then(response => {
            response.blob().then( b => {
                b.arrayBuffer().then(a => {
                    if (a.byteLength > 1) {
                        onFrameGrabbedCallbackRef(a);
                    }
                })
            })
        })
    }, 1000/25);


    // var ws = new WebSocket(`ws://localhost:${wsPort}`);
    // ws.onopen = function() {
    //     console.log('ws opened');
    // }
    // ws.onmessage = function(evt) {
    //     evt.data.arrayBuffer().then(b => {
    //         if (b.byteLength > 1) {
    //             window.onFrameGrabbedCallback(b);
    //         }
    //     });
    // }
    // ws.onclose = function() {
    //     console.log('ws closed');
    // }
}