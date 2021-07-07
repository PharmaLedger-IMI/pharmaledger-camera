document.addEventListener("DOMContentLoaded", () => {
    // document.getElementById('test1button').addEventListener('click', function(event) {
    //     callNative("SayHelloFromSwift", {"p1": "p1_val", "p2": "p2_val"}, helloCallback)
    // });
    document.getElementById('startCameraButton').addEventListener('click', function(e) {
        startNativeCamera(onFrameGrabbed)
    })
    document.getElementById('stopCameraButton').addEventListener('click', function(e) {
        stopNativeCamera();
    })
});

function onFrameGrabbed(aBlob) {
    var frame = new Uint8ClampedArray(aBlob);
    // DEBUG
    let fps = Math.round( 10 * (1000 / ((new Date()) - window.t0)) ) / 10;
    window.t0 = new Date();
    document.getElementById('fakeCameraReturn').innerHTML = `frame[0]=${frame[0]}, frame[1]=${frame[1]}<br/> length=${frame.byteLength}<br>FPS=${fps}`;
    // end DEBUG
}


// Test
function helloCallback(text) {
    document.getElementById('test1').innerHTML = text
}

