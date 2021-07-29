var renderer, camera, scene, canvasgl;
var material;
var sessionPreset;
var previewWidth = 360;
var previewHeight = undefined;
var targetPreviewFPS = 25;
var fpsMeasurementInterval = 5;
var previewFramesCounter = 0;
var previewFramesElapsedSum = 0;
var previewFramesMeasuredFPS = 0;
var targetRawFPS = 10;
var rawCrop_x = undefined;
var rawCrop_y = undefined;
var rawCrop_w = undefined;
var rawCrop_h = undefined;
var rawFramesCounter = 0;
var rawFramesElapsedSum = 0;
var rawFramesMeasuredFPS = 0;
var elapsed = 0
var controls;
const bytePerChannel = 3;
if (bytePerChannel === 4) {
    formatTexture = THREE.RGBAFormat;
} else if (bytePerChannel === 3) {
    formatTexture = THREE.RGBFormat;
}
var formatTexture;
var flashMode = 'off'
var usingMJPEG = false


document.addEventListener("DOMContentLoaded", () => {
    status_test = document.getElementById('status_test');
    status_fps_preview = document.getElementById('status_fps_preview');
    status_fps_raw = document.getElementById('status_fps_raw');

    startCameraButtonGL = document.getElementById('startCameraButtonGL');
    startCameraButtonMJPEG = document.getElementById('startCameraButtonMJPEG');
    stopCameraButton = document.getElementById('stopCameraButton');
    stopCameraButton.disabled = true

    title_h2 = document.getElementById('title_id');
    takePictureButton1 = document.getElementById('takePictureButton1');
    takePictureButton2 = document.getElementById('takePictureButton2');
    flashButton = document.getElementById('flashButton');
    snapshotImage = document.getElementById('snapshotImage');

    
    canvasgl = document.getElementById('cameraCanvas');
    streamPreview = document.getElementById('streamPreview');
    rawCropCanvas = document.getElementById('rawCropCanvas');
    invertRawFrameCheck = document.getElementById('invertRawFrameCheck');
    cropRawFrameCheck = document.getElementById('cropRawFrameCheck');
    rawCropRoiInput = document.getElementById('rawCropRoiInput');
    rawCropRoiInput.addEventListener('change', function() {
        setCropCoords();
    })
    cropRawFrameCheck.addEventListener('change', function() {
        if (this.checked) {
            show(rawCropRoiInput);        
        } else {
            hide(rawCropRoiInput);
        }
    });
    hide(rawCropRoiInput);
    hide(rawCropCanvas);


    select_preset = document.getElementById('select_preset');
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

    startCameraButtonGL.addEventListener('click', function(e) {
        usingMJPEG = false
        select_preset.disabled = true;
        startCameraButtonGL.disabled = true
        startCameraButtonMJPEG.disabled = true
        stopCameraButton.disabled = false
        setCropCoords();
        show(canvasgl);
        canvasgl.parentElement.style.display = "block";
        hide(streamPreview);
        streamPreview.parentElement.style.display = "none";
        show(status_fps_preview);
        show(status_fps_raw);
        previewWidth = canvasgl.clientWidth;
        previewHeight = Math.round(previewWidth / sessionPreset.height * sessionPreset.width) // w<->h because landscape in sessionPreset
        canvasgl.clientHeight = previewHeight;
        setupGLView(previewWidth, previewHeight);
        startNativeCamera(
            sessionPreset, 
            flashMode, 
            onFramePreview, 
            targetPreviewFPS, 
            previewWidth, 
            onFrameGrabbed, 
            targetRawFPS, 
            () => {
                title_h2.innerHTML = _serverUrl;
            },
            rawCrop_x,
            rawCrop_y,
            rawCrop_w,
            rawCrop_h);
    })
    startCameraButtonMJPEG.addEventListener('click', function(e) {
        usingMJPEG = true
        select_preset.disabled = true;
        startCameraButtonGL.disabled = true
        startCameraButtonMJPEG.disabled = true
        stopCameraButton.disabled = false
        setCropCoords();
        hide(canvasgl);
        canvasgl.parentElement.style.display = "none";
        show(streamPreview);
        streamPreview.parentElement.style.display = "block";
        hide(status_fps_preview);
        show(status_fps_raw);
        previewHeight = Math.round(previewWidth / sessionPreset.height * sessionPreset.width) // w<->h because landscape in sessionPreset
        startNativeCamera(
            sessionPreset, 
            flashMode, 
            undefined, 
            targetPreviewFPS, 
            previewWidth, 
            onFrameGrabbed, 
            targetRawFPS, 
            () => {
                streamPreview.src = `${_serverUrl}/mjpeg`;
                title_h2.innerHTML = _serverUrl;
            },
            rawCrop_x,
            rawCrop_y,
            rawCrop_w,
            rawCrop_h);
    });
    stopCameraButton.addEventListener('click', function(e) {
        window.close(); 
        stopNativeCamera();
        select_preset.disabled = false;
        startCameraButtonGL.disabled = false
        startCameraButtonMJPEG.disabled = false
        stopCameraButton.disabled = true
        time0 = undefined
        globalCounter = 0
        title_h2.innerHTML = "Camera Test"
    });

    takePictureButton1.addEventListener('click', function(e) {
        takePictureBase64NativeCamera(onPictureTaken)
    });
    takePictureButton2.addEventListener('click', function(e) {
        getSnapshot().then( b => {
            snapshotImage.src = URL.createObjectURL(b);
        });
    });

    flashButton.addEventListener('click', function(e) {
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
        flashButton.innerHTML = `T ${flashMode}`;
        setFlashModeNativeCamera(flashMode);
    });

    hide(canvasgl);
    hide(streamPreview);
    hide(status_fps_preview)
    hide(status_fps_raw)
});

function getSessionPresetFromName(name) {
    for (preset_key of Object.keys(DictSessionPreset)) {
        let preset = DictSessionPreset[preset_key]
        if (preset.name === name) {
            return preset
        }
    }
}

function setupGLView(w, h) {
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, w/h, 0.1, 10000);
    renderer = new THREE.WebGLRenderer({ canvas: canvasgl, antialias: true });

    cameraHeight = h/2/Math.tan(camera.fov/2*(Math.PI/180))
    camera.position.set(0,0,cameraHeight);
    renderer.setSize(w,h);

    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enablePan = false;
    controls.enableZoom = false;
    controls.enableRotate = false;

    const dataTexture = new Uint8Array(w*h*bytePerChannel);
    for (let i=0; i<w*h*bytePerChannel; i++)
        dataTexture[i] = 255;
    const frameTexture = new THREE.DataTexture(dataTexture, w, h, formatTexture, THREE.UnsignedByteType);
    frameTexture.needsUpdate = true;
    const planeGeo = new THREE.PlaneBufferGeometry(w, h);
    material = new THREE.MeshBasicMaterial({
        map: frameTexture,
    });
    material.map.flipY = true;
    const plane = new THREE.Mesh(planeGeo, material);
    scene.add(plane);

    animate();
}

function animate() {
    window.requestAnimationFrame(() => animate());
    renderer.render(scene, camera);
}

function ChangePresetList() {
    sessionPreset = getSessionPresetFromName(select_preset.options[select_preset.selectedIndex].value);
    status_test.innerHTML = sessionPreset.name;
}

function setCropCoords() {
    if (cropRawFrameCheck.checked) {
        const coords = rawCropRoiInput.value.split(",");
        rawCrop_x = parseInt(coords[0]);
        rawCrop_y = parseInt(coords[1]);
        rawCrop_w = parseInt(coords[2]);
        rawCrop_h = parseInt(coords[3]);
        if (rawCrop_x != rawCrop_x || rawCrop_y != rawCrop_y || rawCrop_w != rawCrop_w || rawCrop_h != rawCrop_h) {
            alert("failed to parse coords");
            cropRawFrameCheck.checked = false;
            hide(rawCropRoiInput);
            rawCrop_x = undefined;
            rawCrop_y = undefined;
            rawCrop_w = undefined;
            rawCrop_h = undefined;
        }
    } else {
        rawCrop_x = undefined;
        rawCrop_y = undefined;
        rawCrop_w = undefined;
        rawCrop_h = undefined;
    }
}


/**
 * @param {ArrayBuffer} buffer preview data coming from native camera. Can be used to create a new Uint8Array
 * @param {number} elapsedTime time in ms elapsed to get the preview frame
 */
function onFramePreview(buffer, elapsedTime) {
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
    status_fps_preview.innerHTML = `preview ${Math.round(elapsedTime)} ms (max FPS=${Math.round(previewFramesMeasuredFPS)})`;
}

/**
 * @param {ArrayBuffer} buffer raw data coming from native camera. Can be used to create a new Uint8Array
 * @param {number} elapsedTime time in ms elapsed to get the raw frame
 */
function onFrameGrabbed(buffer, elapsedTime) {
    var rawframe = new Uint8Array(buffer);
    if (usingMJPEG === false) {
        pSizeText = `, p(${previewWidth}x${previewHeight}), p FPS:${targetPreviewFPS}`
    } else {
        pSizeText = ""
    }
    status_test.innerHTML = `${sessionPreset.name}${pSizeText}, raw FPS:${targetRawFPS}<br/> raw frame length: ${Math.round(10*rawframe.byteLength/1024/1024)/10}MB, [0]=${rawframe[0]}, [1]=${rawframe[1]}`

    if (rawFramesCounter !== 0 && rawFramesCounter%(fpsMeasurementInterval-1) === 0) {
        rawFramesMeasuredFPS = 1000/rawFramesElapsedSum * fpsMeasurementInterval;
        rawFramesCounter = 0;
        rawFramesElapsedSum = 0;
    } else {
        rawFramesCounter += 1;
        rawFramesElapsedSum += elapsedTime;
    }
    status_fps_raw.innerHTML = `raw ${Math.round(elapsedTime)} ms (max FPS=${Math.round(rawFramesMeasuredFPS)})`
    if (rawCrop_w !== undefined && rawCrop_h !== undefined) {
        placeUint8RGBArrayInCanvas(rawCropCanvas, rawframe, rawCrop_w, rawCrop_h);
    } else {
        placeUint8RGBArrayInCanvas(rawCropCanvas, rawframe, sessionPreset.height, sessionPreset.width);
    }
    show(rawCropCanvas);
}

function onPictureTaken(base64ImageData) {
    console.log(`Inside onPictureTaken`)
    snapshotImage.src = base64ImageData
}

function hide(element) {
    element.style.display = "none";
}

function show(element) {
    element.style.display = "block";
}

function placeUint8RGBArrayInCanvas(canvasElem, array, w, h) {
    let a = 1;
    let b = 0;
    if (invertRawFrameCheck.checked === true){
        a = -1;
        b = 255;
    }
    canvasElem.width = w;
    canvasElem.height = h;
    var ctx = canvasElem.getContext('2d');
    var clampedArray = new Uint8ClampedArray(w*h*4);
    let j = 0
    for (let i = 0; i < 3*w*h; i+=3) {
        clampedArray[j] = b+a*array[i];
        clampedArray[j+1] = b+a*array[i+1];
        clampedArray[j+2] = b+a*array[i+2];
        clampedArray[j+3] = 255;
        j += 4;
    }
    var imageData = new ImageData(clampedArray, w, h);
    ctx.putImageData(imageData, 0, 0);
}
