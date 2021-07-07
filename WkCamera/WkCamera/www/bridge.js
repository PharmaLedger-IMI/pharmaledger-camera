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

function startNativeCamera(onFrameGrabbedCallback) {
    window.onFrameGrabbedCallback = onFrameGrabbedCallback;
    callNative("StartCamera", {"onInitializedJsCallback": onNativeCameraInitialized.name});
}

function stopNativeCamera() {
    clearInterval(window.onGetFrameH)
    callNative("StopCamera")
}

function onNativeCameraInitialized() {
    // window.onGetFrameH = setInterval(() => {
    //     callNative("GrabFrame", {}, onFrameGrabbed)
    // }, 1000/25);
    //
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