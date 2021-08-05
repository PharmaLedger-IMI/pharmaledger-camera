var renderer, camera, scene, canvasgl;
var material;
var previewWidth = 360;
var previewHeight = Math.round(previewWidth * 16 / 9); // assume 16:9 portrait at start
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
const bytePerChannel = 3;
if (bytePerChannel === 4) {
    formatTexture = THREE.RGBAFormat;
} else if (bytePerChannel === 3) {
    formatTexture = THREE.RGBFormat;
}
var formatTexture;
var flashMode = 'off'
var usingMJPEG = false

var status_test
var status_fps_preview
var status_fps_raw
var startCameraButtonGL
var startCameraButtonMJPEG
var stopCameraButton
var title_h2
var takePictureButton1
var takePictureButton2
var flashButton
var torchRange
var snapshotImage
var getConfigButton
var configInfo
var colorspaceButton
var streamPreview
var rawCropCanvas
var rawCropCbCanvas 
var rawCropCrCanvas 
var invertRawFrameCheck 
var cropRawFrameCheck 
var ycbcrCheck 
var rawCropRoiInput 
var select_preset
var selectedPresetName


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
    torchRange = document.getElementById('torchLevelRange');
    torchRange.addEventListener('change', function() {
        let level = parseFloat(torchRange.value);
        if (level != level) {
            alert('failed to parse torch level value');
        } else {
            window.nativeCamera.setTorchLevelNativeCamera(level);
            document.getElementById("torchLevelRangeLabel").innerHTML = `Torch Level: ${torchRange.value}`;
        }
    })
    torchRange.value = "1.0";
    document.getElementById("torchLevelRangeLabel").innerHTML = `Torch Level: ${torchRange.value}`;
    torchRange.disabled = true;
    snapshotImage = document.getElementById('snapshotImage');
    getConfigButton = document.getElementById("getConfigButton");
    getConfigButton.addEventListener("click", (e) => {
        window.nativeCamera.getCameraConfiguration()
        .then(data => {
            configInfo.innerHTML = JSON.stringify(data);
        })
    });
    configInfo = document.getElementById("configInfo");
    colorspaceButton = document.getElementById("colorspaceButton");
    colorspaceButton.addEventListener('click', function(e) {
        let nextColorspace = '';
        switch (colorspaceButton.innerHTML) {
            case 'sRGB':
                nextColorspace = 'HLG_BT2020';
                break;
            case 'HLG_BT2020':
                nextColorspace = 'P3_D65';
                break;
            default:
                nextColorspace = 'sRGB';
                break;
        }
        colorspaceButton.innerHTML = nextColorspace;
        window.nativeCamera.setPreferredColorSpaceNativeCamera(nextColorspace);
    });


    canvasgl = document.getElementById('cameraCanvas');
    streamPreview = document.getElementById('streamPreview');
    rawCropCanvas = document.getElementById('rawCropCanvas');
    rawCropCbCanvas = document.getElementById('rawCropCbCanvas');
    rawCropCrCanvas = document.getElementById('rawCropCrCanvas');
    invertRawFrameCheck = document.getElementById('invertRawFrameCheck');
    cropRawFrameCheck = document.getElementById('cropRawFrameCheck');
    ycbcrCheck = document.getElementById('ycbcrCheck');
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
    hide(rawCropCbCanvas);
    hide(rawCropCrCanvas);


    select_preset = document.getElementById('select_preset');
    let i = 0
    for (let presetName of window.nativeCamera.sessionPresetNames) {
        var p_i = new Option(presetName, presetName)
        select_preset.options.add(p_i);
        i++;
    }
    for (let i = 0; i < select_preset.options.length; i++) {
        if (select_preset.options[i].value === 'hd1920x1080') {
            select_preset.selectedIndex = i;
            break;
        }
    }
    selectedPresetName = select_preset.options[select_preset.selectedIndex].value;
    status_test.innerHTML = selectedPresetName;

    startCameraButtonGL.addEventListener('click', function(e) {
        usingMJPEG = false
        select_preset.disabled = true;
        startCameraButtonGL.disabled = true
        startCameraButtonMJPEG.disabled = true
        stopCameraButton.disabled = false
        torchRange.disabled = false
        ycbcrCheck.disabled = true
        setCropCoords();
        show(canvasgl);
        canvasgl.parentElement.style.display = "block";
        hide(streamPreview);
        streamPreview.parentElement.style.display = "none";
        show(status_fps_preview);
        show(status_fps_raw);
        setupGLView(previewWidth, previewHeight);
        window.nativeCamera.startNativeCamera(
            selectedPresetName, 
            flashMode, 
            onFramePreview, 
            targetPreviewFPS, 
            previewWidth, 
            onFrameGrabbed, 
            targetRawFPS, 
            true,
            () => {
                title_h2.innerHTML = window.nativeCamera.getBridgeServerUrl();
            },
            rawCrop_x,
            rawCrop_y,
            rawCrop_w,
            rawCrop_h,
            ycbcrCheck.checked);
    })
    startCameraButtonMJPEG.addEventListener('click', function(e) {
        usingMJPEG = true
        select_preset.disabled = true;
        startCameraButtonGL.disabled = true
        startCameraButtonMJPEG.disabled = true
        stopCameraButton.disabled = false
        torchRange.disabled = false
        ycbcrCheck.disabled = true
        setCropCoords();
        hide(canvasgl);
        canvasgl.parentElement.style.display = "none";
        show(streamPreview);
        streamPreview.parentElement.style.display = "block";
        hide(status_fps_preview);
        show(status_fps_raw);
        window.nativeCamera.startNativeCamera(
            selectedPresetName, 
            flashMode, 
            undefined, 
            targetPreviewFPS, 
            previewWidth, 
            onFrameGrabbed, 
            targetRawFPS,
            true, 
            () => {
                streamPreview.src = `${window.nativeCamera.getBridgeServerUrl()}/mjpeg`;
                title_h2.innerHTML = window.nativeCamera.getBridgeServerUrl();
            },
            rawCrop_x,
            rawCrop_y,
            rawCrop_w,
            rawCrop_h,
            ycbcrCheck.checked);
    });
    stopCameraButton.addEventListener('click', function(e) {
        window.close(); 
        window.nativeCamera.stopNativeCamera();
        select_preset.disabled = false;
        startCameraButtonGL.disabled = false
        startCameraButtonMJPEG.disabled = false
        stopCameraButton.disabled = true
        torchRange.disabled = true
        ycbcrCheck.disabled = false
        title_h2.innerHTML = "Camera Test"
    });

    takePictureButton1.addEventListener('click', function(e) {
        window.nativeCamera.takePictureBase64NativeCamera(onPictureTaken)
    });
    takePictureButton2.addEventListener('click', function(e) {
        window.nativeCamera.getSnapshot().then( b => {
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
        window.nativeCamera.setFlashModeNativeCamera(flashMode);
    });

    hide(canvasgl);
    hide(streamPreview);
    hide(status_fps_preview)
    hide(status_fps_raw)
});

function setupGLView(w, h) {
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, w/h, 0.1, 10000);
    renderer = new THREE.WebGLRenderer({ canvas: canvasgl, antialias: true });

    let cameraHeight = h/2/Math.tan(camera.fov/2*(Math.PI/180))
    camera.position.set(0,0,cameraHeight);
    let clientHeight = Math.round(h/w * canvasgl.clientWidth);    
    renderer.setSize(canvasgl.clientWidth, clientHeight);

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
    selectedPresetName = select_preset.options[select_preset.selectedIndex].value;
    status_test.innerHTML = selectedPresetName;
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
    window.nativeCamera.setRawCropRoi(rawCrop_x, rawCrop_y, rawCrop_w, rawCrop_h);
}


/**
 * @param {PLRgbImage} rgbImage preview data coming from native camera
 * @param {number} elapsedTime time in ms elapsed to get the preview frame
 */
function onFramePreview(rgbImage, elapsedTime) {
    var frame = new Uint8Array(rgbImage.arrayBuffer);
    if (rgbImage.width !== previewWidth || rgbImage.height !== previewHeight) {
        previewWidth = rgbImage.width;
        previewHeight = rgbImage.height;
        setupGLView(previewWidth, previewHeight);
    }
    material.map = new THREE.DataTexture(frame, rgbImage.width, rgbImage.height, formatTexture, THREE.UnsignedByteType);
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
 * @param {PLRgbImage | PLYCbCrImage} plImage raw data coming from native camera
 * @param {number} elapsedTime time in ms elapsed to get the raw frame
 */
function onFrameGrabbed(plImage, elapsedTime) {
    let pSizeText;
    if (usingMJPEG === false) {
        pSizeText = `, p(${previewWidth}x${previewHeight}), p FPS:${targetPreviewFPS}`
    } else {
        pSizeText = ""
    }
    
    let rawframeLengthMB = undefined
    if (plImage instanceof window.nativeCamera.PLRgbImage) {
        rawframeLengthMB = Math.round(10*plImage.arrayBuffer.byteLength/1024/1024)/10;
        placeUint8RGBArrayInCanvas(rawCropCanvas, new Uint8Array(plImage.arrayBuffer), plImage.width, plImage.height);
        show(rawCropCanvas);
        hide(rawCropCbCanvas);
        hide(rawCropCrCanvas);
    } else if (plImage instanceof window.nativeCamera.PLYCbCrImage) {
        rawframeLengthMB = Math.round(10*(plImage.yArrayBuffer.byteLength + plImage.cbCrArrayBuffer.byteLength)/1024/1024)/10;
        placeUint8GrayScaleArrayInCanvas(rawCropCanvas, new Uint8Array(plImage.yArrayBuffer), plImage.width, plImage.height);
        show(rawCropCanvas);
        placeUint8CbCrArrayInCanvas(rawCropCbCanvas, rawCropCrCanvas, new Uint8Array(plImage.cbCrArrayBuffer), plImage.width/2, plImage.height/2);
        show(rawCropCbCanvas);
        show(rawCropCrCanvas);
    } else {
        rawframeLengthMB = -1
    }
    
    status_test.innerHTML = `${selectedPresetName}${pSizeText}, raw FPS:${targetRawFPS}<br/> raw frame length: ${rawframeLengthMB}MB, ${plImage.width}x${plImage.height}`

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

function placeUint8GrayScaleArrayInCanvas(canvasElem, array, w, h) {
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
    for (let i = 0; i < w*h; i++) {
        clampedArray[j] = b+a*array[i];
        clampedArray[j+1] = b+a*array[i];
        clampedArray[j+2] = b+a*array[i];
        clampedArray[j+3] = 255;
        j += 4;
    }
    var imageData = new ImageData(clampedArray, w, h);
    ctx.putImageData(imageData, 0, 0);
}

function placeUint8CbCrArrayInCanvas(canvasElemCb, canvasElemCr, array, w, h) {
    canvasElemCb.width = w;
    canvasElemCb.height = h;
    canvasElemCr.width = w;
    canvasElemCr.height = h;
    var ctxCb = canvasElemCb.getContext('2d');
    var ctxCr = canvasElemCr.getContext('2d');
    var clampedArrayCb = new Uint8ClampedArray(w*h*4);
    var clampedArrayCr = new Uint8ClampedArray(w*h*4);
    let j = 0
    for (let i = 0; i < 2*w*h; i+=2) {
        clampedArrayCb[j] = array[i];
        clampedArrayCb[j+1] = array[i];
        clampedArrayCb[j+2] = array[i];
        clampedArrayCb[j+3] = 255;
        clampedArrayCr[j] = array[i+1];
        clampedArrayCr[j+1] = array[i+1];
        clampedArrayCr[j+2] = array[i+1];
        clampedArrayCr[j+3] = 255;
        j += 4;
    }
    var imageDataCb = new ImageData(clampedArrayCb, w, h);
    ctxCb.putImageData(imageDataCb, 0, 0);
    var imageDataCr = new ImageData(clampedArrayCr, w, h);
    ctxCr.putImageData(imageDataCr, 0, 0);
}
