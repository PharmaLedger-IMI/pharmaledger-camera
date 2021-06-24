# PharmaLedger Camera

This readme is mainly meant as internal TrueMed documentation for managing the PharmaLedger iOS camera framework.

## Repository contents

- Camera Sample (Swift project that implements the Camera Framework)
- pharmaledger_flutterdemo (Flutter application that uses the Camera Framework to access the native camera)
- PharmaLedger Camera (native iOS camera Framework)

## Documentation

- The html Swift documentation is hosted live at [truemedinc.com](https://truemedinc.com/pharmaledger-sdk/documentation/)
- Please see our [Setup guide](https://truemedinc.com/pharmaledger-sdk/documentation/guides/Setup.pdf) on how to add the Framework to your project

## Sample code

This example shows how the **CameraSession** preview feed would be displayed in a iOS native **UIImageView**. For a more complete example, see the [Camera Sample](Camera%20Sample/) project.

First implement the **CameraEventListener** to receive events from the CameraSession, like preview frames and photo capture callbacks.

    import PharmaLedger_Camera
    import AVFoundation
    import UIKit
    
    class ViewController: UIViewController, CameraEventListener {
        func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        
        }
        
        func onCapture(imageData: Data) {
        
        }
        
        func onCameraInitialized() {
        
        }

When the delegate has been defined, the CameraSession instance can be created.

    private var cameraSession:CameraSession?
    private var cameraPreview:UIImageView?

    /// Use this function for example in your viewDidLoad script
    private func startCameraSession(){
        // 1. Init the CameraSession

        cameraSession = CameraSession.init(cameraEventListener: self)

        // 2a. Create a preview view and add it to the ViewController

        cameraPreview = UIImageView.init()
        view.addSubview(cameraPreview!)

        // 2b. in this example the preview is scaled using constraints.
        // The Height constraint is based on the camera aspect ratio, in this example 4:3.

        cameraPreview?.translatesAutoresizingMaskIntoConstraints = false
        let cameraAspectRatio:CGFloat = 4.0/3.0      
        let heightAnchorConstant = (view.frame.width)*cameraAspectRatio

        NSLayoutConstraint.activate([
            cameraPreview!.widthAnchor.constraint(equalTo: view.widthAnchor),
            cameraPreview!.topAnchor.constraint(equalTo: view.topAnchor),
            cameraPreview!.heightAnchor.constraint(equalToConstant: heightAnchorConstant)
        ])
    }

To display the camera preview frames in the cameraPreview view, edit the onPreviewFrame(sampleBuffer: CMSampleBuffer) method from CameraEventListener

    //define the CIContext as a constant
    let ciContext:CIContext = CIContext()

    func onPreviewFrame(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            //1. Get UIImage from the sampleBuffer.
            guard let image:UIImage = sampleBuffer.bufferToUIImage(ciContext: ciContext) else {
                return
            }
            //2. update the preview image
            self.cameraPreview?.image = image
        }
    }

### Capturing and saving a photo

To capture a photo, simply call cameraSession?.takePicture(). When the capture is finished, the Data object is returned in the onCapture(imageData: Data) method. Below example shows how to save the file:

    func onCapture(imageData: Data) {
        //below snippet saves a file "test.jpg" into the app files directory
        guard let filedir = imageData.savePhotoToFiles(fileName: "test") else {
            //Something went wrong when saving the file 
            return
        }
    }

## Development

### Building Documentation

Currently documentation is generated using [Jazzy](https://github.com/realm/jazzy). To generate the documentation, run this command in the PharmaLedger Camera framework root folder (remember to replace VERSION_NUMBER with the version number of the build, eg. 0.1.0):

`jazzy --output docs --copyright "" --author "TrueMed Inc." --author_url https://truemedinc.com --module PharmaLedger_Camera --title "PharmaLedger iOS Camera SDK" --module-version VERSION_NUMBER --skip-undocumented --hide-documentation-coverage`

Before releasing, you can make sure documentation is up to date by not skipping undocumented code.

### Testing

Quickest way to test the Framework is to boot the sample project **Camera Sample**. Make sure that the Swift framework project is included in the project. This way you can quickly make changes to the source files while testing them in an application project. Make sure you don't have the Framework project open in another window.

### Releasing

To build a release framework, open the **PharmaLedger Camera** project and select the release build scheme (create a new release scheme if there is none available). After this, build the project and find the release build in the project Output.
