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
    
    [self addChildViewController:myPreview];
    UIView *previewView = [myPreview view];
    previewView.translatesAutoresizingMaskIntoConstraints = false;

    UIView *container = [self view];
    [container addSubview:previewView];
    
    [previewView.leadingAnchor constraintEqualToAnchor: container.leadingAnchor].active = YES;
    [previewView.trailingAnchor constraintEqualToAnchor: container.trailingAnchor].active = YES;
    [previewView.topAnchor constraintEqualToAnchor: container.topAnchor].active = YES;
    [previewView.bottomAnchor constraintEqualToAnchor: container.bottomAnchor].active = YES;
}

-(void)takePicture{
    [myPreview takePicture];
}


- (void)captureCallbackWithImageData:(NSData * _Nonnull)imageData {
    NSString *filedir = [myPreview savePhotoToFilesWithImageData:imageData fileName:@"Test"];
    printf("filedir: %s",[filedir UTF8String]);
}

- (void)previewFrameCallbackWithByteArray:(NSArray<NSNumber *> * _Nonnull)byteArray {
    
}

@end
