var renderer, camera, scene, canvasgl;
var material;
var w = 320;
var h = 240;
var sessionPreset;
var stats = new Stats();
stats.showPanel( 0 ); // fps
var controls;
const bytePerChannel = 4;
var formatTexture;

document.addEventListener("DOMContentLoaded", () => {
    // FPS
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

    sessionPreset = DictSessionPreset.hd1280x720;

    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(75, w/h, 0.1, 10000);
    renderer = new THREE.WebGLRenderer({ canvas: canvasgl, antialias: true });

    computeSize();

    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enablePan = false;
    controls.enableZoom = true;
    controls.enableRotate = false;

    const dataTexture = new Uint8Array(sessionPreset.width*sessionPreset.height*bytePerChannel);
    for (var i=0; i<sessionPreset.width*sessionPreset.height*bytePerChannel; i++)
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
        startNativeCamera(onFrameGrabbed)
    })
    document.getElementById('stopCameraButton').addEventListener('click', function(e) {
        stopNativeCamera();
    })

    fpshtml = document.getElementById('fps');
    animate();
});

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

function onFrameGrabbed(aBlob) {
    var frame = new Uint8Array(aBlob);
    material.map = new THREE.DataTexture(frame, sessionPreset.height, sessionPreset.width, formatTexture, THREE.UnsignedByteType);
    material.map.flipY = true;
    material.needsUpdate = true;
    stats.update();
}
