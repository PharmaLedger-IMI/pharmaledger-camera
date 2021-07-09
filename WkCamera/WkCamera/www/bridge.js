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
 * @param  {function} onFrameGrabbedCallback callBack for each native frame. Data are received as a blob.
 * @param  {SessionPreset} sessionPreset one of the session presets available in DictSessionPreset
 */
function startNativeCamera(onFrameGrabbedCallback, sessionPreset) {
    window.onFrameGrabbedCallback = onFrameGrabbedCallback;
    let params = {
        "onInitializedJsCallback": onNativeCameraInitialized.name,
        "sessionPreset": sessionPreset.name
    }
    callNative("StartCamera", params);
}

function stopNativeCamera() {
    callNative("StopCamera")
}

function onNativeCameraInitialized() {
    var ws = new WebSocket("ws://localhost:8888");
    ws.onopen = function() {
        console.log('ws opened');
    }
    ws.onmessage = function(evt) {
        evt.data.arrayBuffer().then(b => {
            window.onFrameGrabbedCallback(b);
        });
    }
    ws.onclose = function() {
        console.log('ws closed');
    }
}