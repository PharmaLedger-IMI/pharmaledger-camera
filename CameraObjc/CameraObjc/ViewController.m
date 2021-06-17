//
//  ViewController.m
//  CameraObjc
//
//  Created by Ville Raitio on 10.6.2021.
//

#import "ViewController.h"
#import "PharmaLedger_Camera/PharmaLedger_Camera.h"
#import "PharmaLedger_Camera/PharmaLedger_Camera-Swift.h"

@interface ViewController () <CameraEventListener>

@end

@implementation ViewController

CameraPreview *myPreview;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self openCameraView];
}

- (void)openCameraView {
    myPreview = [[CameraPreview alloc] initWithCameraListener:self];
    
    UIView *container = [self view];
    [container addSubview:myPreview];
}

-(void)takePicture{
    [myPreview takePicture];
}


- (void)captureCallbackWithImageData:(NSData * _Nonnull)imageData {
    
}

- (void)previewFrameCallbackWithByteArray:(NSArray<NSNumber *> * _Nonnull)byteArray {
    
}

@end
