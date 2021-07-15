var renderer, camera, scene, canvasgl;
var material;
var w = 320;
var h = 240;
var sessionPreset;
var stats = new Stats();
stats.showPanel( 0 ); // fps
var controls;
const bytePerChannel = 3;
var formatTexture;
var flashMode = 'off'

document.addEventListener("DOMContentLoaded", () => {
    // FPS
    document.getElementById('stopCameraButton').disabled = true
    stats.domElement.style.position = 'absolute';
    stats.domElement.style.right = '0';
    stats.domElement.style.left = 'unset';
    stats.domElement.style.top = '0';
    document.body.appendChild( stats.dom );

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
        if (select_preset.options[i].value === 'vga640x480') {
            select_preset.selectedIndex = i;
            break;
        }
    }
    sessionPreset = getSessionPresetFromName(select_preset.options[select_preset.selectedIndex].value);
    document.getElementById('status_test').innerHTML = sessionPreset.name;

    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, w/h, 0.1, 10000);
    renderer = new THREE.WebGLRenderer({ canvas: canvasgl, antialias: true });

    computeSize();

    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enablePan = false;
    controls.enableZoom = true;
    controls.enableRotate = false;

    const dataTexture = new Uint8Array(sessionPreset.width*sessionPreset.height*bytePerChannel);
    for (let i=0; i<sessionPreset.width*sessionPreset.height*bytePerChannel; i++)
        dataTexture[i] = 128;
    const frameTexture = new THREE.DataTexture(dataTexture, sessionPreset.height, sessionPreset.width, formatTexture, THREE.UnsignedByteType);
    frameTexture.needsUpdate = true;
    const planeGeo = new THREE.PlaneBufferGeometry(sessionPreset.height, sessionPreset.width);
    material = new THREE.MeshBasicMaterial({
        map: frameTexture,
    });
    material.map.flipY = true;
    const plane = new THREE.Mesh(planeGeo, material);
    scene.add(plane);
    
    document.getElementById('startCameraButton').addEventListener('click', function(e) {
        document.getElementById('select_preset').disabled = true;
        document.getElementById('startCameraButton').disabled = true
        document.getElementById('stopCameraButton').disabled = false
        startNativeCamera(onFrameGrabbed, sessionPreset, flashMode)
    })
    document.getElementById('stopCameraButton').addEventListener('click', function(e) {
        stopNativeCamera();
        document.getElementById('select_preset').disabled = false;
        document.getElementById('startCameraButton').disabled = false
        document.getElementById('stopCameraButton').disabled = true
    })

    document.getElementById('takePictureButton').addEventListener('click', function(e) {
        takePictureNativeCamera(onPictureTaken)
    });

    fpshtml = document.getElementById('fps');
    animate();

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

stop

function getSessionPresetFromName(name) {
    for (preset_key of Object.keys(DictSessionPreset)) {
        let preset = DictSessionPreset[preset_key]
        if (preset.name === name) {
            return preset
        }
    }
}

function computeSize() {
    w = canvasgl.clientWidth;
    h = canvasgl.clientHeight;
    cameraHeight = sessionPreset.width/2/Math.tan(camera.fov/2*(Math.PI/180))
    camera.position.set(0,0,cameraHeight);
    renderer.setSize(w,h);
}

function animate() {
    window.requestAnimationFrame(() => animate());
    renderer.render(scene, camera);
}

function ChangePresetList() {
    sessionPreset = getSessionPresetFromName(select_preset.options[select_preset.selectedIndex].value);
    document.getElementById('status_test').innerHTML = sessionPreset.name;
}

/**
 * @param  {Blob} aBlob data coming from native camera. Can be used to create a new Uin8Array
 */
function onFrameGrabbed(aBlob) {
    var frame = new Uint8Array(aBlob);
    material.map = new THREE.DataTexture(frame, sessionPreset.height, sessionPreset.width, formatTexture, THREE.UnsignedByteType);
    material.map.flipY = true;
    material.needsUpdate = true;
    stats.update();
}

function onPictureTaken(base64ImageData) {
    console.log(`Inside onPictureTaken`)
    document.getElementById('snapshotImage').src = base64ImageData
}
