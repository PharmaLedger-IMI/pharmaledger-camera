var renderer, camera, scene, canvasgl;
var material;
var w = 320;
var h = 240;
var sessionPreset;
var previewWidth = 360;
var previewHeight = undefined;
var targetPreviewFPS = 25;
var fpsMeasurementInterval = 5;
var previewFramesCounter = 0;
var previewFramesElapsedSum = 0;
var previewFramesMeasuredFPS = 0;
var targetRawFPS = 10;
var rawFramesCounter = 0;
var rawFramesElapsedSum = 0;
var rawFramesMeasuredFPS = 0;
var elapsed = 0
var controls;
const bytePerChannel = 3;
var formatTexture;
var flashMode = 'off'
var time0 = undefined
var globalCounter = 0


document.addEventListener("DOMContentLoaded", () => {
    document.getElementById('stopCameraButton').disabled = true
    status_test = document.getElementById('status_test');
    // FPS
    status_fps_preview = document.getElementById('status_fps_preview');
    status_fps_raw = document.getElementById('status_fps_raw');

    if (bytePerChannel === 4) {
        formatTexture = THREE.RGBAFormat;
    } else if (bytePerChannel === 3) {
        formatTexture = THREE.RGBFormat;
    }

    canvasgl = document.getElementById('cameraCanvas');
    w = canvasgl.clientWidth;
    h = canvasgl.clientHeight;

    select_preset = document.getElementById('select_preset')
    let i = 0
    for (preset_key of Object.keys(DictSessionPreset)) {
        let preset = DictSessionPreset[preset_key]
        var p_i = new Option(preset.name, preset.name)
        select_preset.options.add(p_i);
        i++;
    }
    for (let i = 0; i < select_preset.options.length; i++) {
        if (select_preset.options[i].value === 'hd1920x1080') {
            select_preset.selectedIndex = i;
            break;
        }
    }
    sessionPreset = getSessionPresetFromName(select_preset.options[select_preset.selectedIndex].value);
    status_test.innerHTML = sessionPreset.name;

    document.getElementById('startCameraButton').addEventListener('click', function(e) {
        document.getElementById('select_preset').disabled = true;
        document.getElementById('startCameraButton').disabled = true
        document.getElementById('stopCameraButton').disabled = false
        previewHeight = Math.round(previewWidth / sessionPreset.height * sessionPreset.width) // w<-> because landscape
        setupGLView();
        startNativeCamera(sessionPreset, flashMode, onFramePreview, targetPreviewFPS, previewWidth, onFrameGrabbed, targetRawFPS)
        // startNativeCamera(sessionPreset, flashMode, undefined, targetPreviewFPS, previewWidth, undefined, targetRawFPS)
    })
    document.getElementById('stopCameraButton').addEventListener('click', function(e) {
        stopNativeCamera();
        document.getElementById('select_preset').disabled = false;
        document.getElementById('startCameraButton').disabled = false
        document.getElementById('stopCameraButton').disabled = true
        time0 = undefined
        globalCounter = 0
        document.getElementById('title_id').innerHTML = "Camera Test"
    })

    document.getElementById('takePictureButton').addEventListener('click', function(e) {
        takePictureNativeCamera(onPictureTaken)
    });

    document.getElementById('flashButton').addEventListener('click', function(e) {
        switch (flashMode) {
            case 'off':
                flashMode = 'flash';
                break;
            case 'flash':
                flashMode = 'torch';
                break;
            case 'torch':
                flashMode = 'off';
                break;
            default:
                break;
        }
        document.getElementById('flashButton').innerHTML = `T ${flashMode}`;
        setFlashModeNativeCamera(flashMode);
    });
});

function getSessionPresetFromName(name) {
    for (preset_key of Object.keys(DictSessionPreset)) {
        let preset = DictSessionPreset[preset_key]
        if (preset.name === name) {
            return preset
        }
    }
}

function setupGLView() {
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, w/h, 0.1, 10000);
    renderer = new THREE.WebGLRenderer({ canvas: canvasgl, antialias: true });

    computeSize();

    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enablePan = false;
    controls.enableZoom = true;
    controls.enableRotate = false;

    const dataTexture = new Uint8Array(previewWidth*previewHeight*bytePerChannel);
    for (let i=0; i<previewWidth*previewHeight*bytePerChannel; i++)
        dataTexture[i] = 128;
    const frameTexture = new THREE.DataTexture(dataTexture, previewHeight, previewWidth, formatTexture, THREE.UnsignedByteType);
    frameTexture.needsUpdate = true;
    const planeGeo = new THREE.PlaneBufferGeometry(previewWidth, previewHeight);
    material = new THREE.MeshBasicMaterial({
        map: frameTexture,
    });
    material.map.flipY = true;
    const plane = new THREE.Mesh(planeGeo, material);
    scene.add(plane);

    animate();
}

function computeSize() {
    w = canvasgl.clientWidth;
    h = canvasgl.clientHeight;
    cameraHeight = previewHeight/2/Math.tan(camera.fov/2*(Math.PI/180))
    camera.position.set(0,0,cameraHeight);
    renderer.setSize(w,h);
}

function animate() {
    window.requestAnimationFrame(() => animate());
    renderer.render(scene, camera);
}

function ChangePresetList() {
    sessionPreset = getSessionPresetFromName(select_preset.options[select_preset.selectedIndex].value);
    status_test.innerHTML = sessionPreset.name;
}




/**
 * @param {ArrayBuffer} buffer preview data coming from native camera. Can be used to create a new Uint8Array
 * @param {number} elapsedTime time in ms elapsed to get the preview frame
 */
function onFramePreview(buffer, elapsedTime) {
    if (time0 === undefined) {
        document.getElementById('title_id').innerHTML = _serverUrl;
        time0 = performance.now();
    }
    var frame = new Uint8Array(buffer);
    material.map = new THREE.DataTexture(frame, previewWidth, previewHeight, formatTexture, THREE.UnsignedByteType);
    material.map.flipY = true;
    material.needsUpdate = true;

    if (previewFramesCounter !== 0 && previewFramesCounter%(fpsMeasurementInterval-1) === 0) {
        previewFramesMeasuredFPS = 1000/previewFramesElapsedSum * fpsMeasurementInterval;
        previewFramesCounter = 0;
        previewFramesElapsedSum = 0;
    } else {
        previewFramesCounter += 1;
        previewFramesElapsedSum += elapsedTime;
    }
    globalCounter += 1
    status_fps_preview.innerHTML = `preview ${Math.round(elapsedTime)} ms (max FPS=${Math.round(previewFramesMeasuredFPS)}) | gFPS:${Math.round(10 * 1000 * globalCounter / (performance.now() - time0)) / 10}`
}

/**
 * @param {ArrayBuffer} buffer raw data coming from native camera. Can be used to create a new Uint8Array
 * @param {number} elapsedTime time in ms elapsed to get the raw frame
 */
function onFrameGrabbed(buffer, elapsedTime) {
    var rawframe = new Uint8Array(buffer);
    status_test.innerHTML = `${sessionPreset.name}, p(${previewWidth}x${previewHeight}), p FPS:${targetPreviewFPS}, raw FPS:${targetRawFPS}<br/> raw frame length: ${Math.round(10*rawframe.byteLength/1024/1024)/10}MB, [0]=${rawframe[0]}, [1]=${rawframe[1]}`

    if (rawFramesCounter !== 0 && rawFramesCounter%(fpsMeasurementInterval-1) === 0) {
        rawFramesMeasuredFPS = 1000/rawFramesElapsedSum * fpsMeasurementInterval;
        rawFramesCounter = 0;
        rawFramesElapsedSum = 0;
    } else {
        rawFramesCounter += 1;
        rawFramesElapsedSum += elapsedTime;
    }
    status_fps_raw.innerHTML = `raw ${Math.round(elapsedTime)} ms (max FPS=${Math.round(rawFramesMeasuredFPS)})`
}

function onPictureTaken(base64ImageData) {
    console.log(`Inside onPictureTaken`)
    document.getElementById('snapshotImage').src = base64ImageData
}
