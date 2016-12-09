//
//  ViewController.m
//  Pure Cam
//
//  Created by Ben Hambrecht on 24.08.15.
//  Copyright (c) 2015 Ben Hambrecht. All rights reserved.
//

#import "ViewController.h"

@import Photos;
@import AudioToolbox;

@interface ViewController ()

@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic) CGRect lastFrame;
@property (nonatomic) CGPoint transformCenter;
@property (nonatomic) float lastScale;
@property (nonatomic) CGAffineTransform lastTransform;
@property (nonatomic) BOOL snapshotRequested;
@property (nonatomic, strong) UIView *whiteScreen;
@property (nonatomic) CIContext *imageSavingContext;
@property (nonatomic) UIInterfaceOrientation currentOrientation;
@property (nonatomic) IBOutlet UILabel *orientationLabel;
@property (nonatomic) BOOL orientationJustChanged;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) IBOutlet UILongPressGestureRecognizer *longpressGR;


@end

@implementation ViewController


AVCaptureSession *session;
AVCaptureDevice *inputDevice;
AVCaptureStillImageOutput *stillImageOutput;

@synthesize previewLayer;
@synthesize lastFrame;
@synthesize transformCenter;
@synthesize lastScale;
@synthesize lastTransform;
@synthesize snapshotRequested;
@synthesize library;
@synthesize whiteScreen;
@synthesize imageSavingContext;
@synthesize currentOrientation;
@synthesize orientationLabel;
@synthesize orientationJustChanged;
@synthesize timer;
@synthesize longpressGR;




- (void)viewDidLoad {
    [super viewDidLoad];
    self.library = [[ALAssetsLibrary alloc] init];
    self.whiteScreen = [[UIView alloc] initWithFrame:self.view.frame];
    self.whiteScreen.layer.opacity = 0.0f;
    self.whiteScreen.layer.backgroundColor = [[UIColor whiteColor] CGColor];
    [self.view addSubview:self.whiteScreen];
    self.orientationLabel.hidden = YES;
    self.orientationJustChanged = NO;

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(turnExternalDisplay) name:UIDeviceOrientationDidChangeNotification object:nil];

}


- (void)viewDidUnload
{
    self.library = nil;
    [super viewDidUnload];
}

//- (void)requestLaunchOrientation {
//    
//    self.launchOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
//    
//    switch (self.launchOrientation) {
//        case UIInterfaceOrientationLandscapeRight:
//            NSLog(@"landscape right");
//            return;
//        case UIInterfaceOrientationLandscapeLeft:
//            NSLog(@"landscape left");
//            return;
//        case UIInterfaceOrientationPortrait:
//            NSLog(@"portrait");
//            return;
//        case UIInterfaceOrientationPortraitUpsideDown:
//            NSLog(@"portrait upside down");
//            return;
//        case UIInterfaceOrientationUnknown:
//            NSLog(@"unknown");
//            return;
//    }
//    
//}

- (void)viewWillAppear:(BOOL)animated {
    
    //[self performSelector:@selector(requestLaunchOrientation) withObject:nil afterDelay:1];

    
    self.imageSavingContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @(YES)}];
    
    self.snapshotRequested = NO;
    
    session = [[AVCaptureSession alloc] init];
    [session setSessionPreset:AVCaptureSessionPresetPhoto];
    
    inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error;
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:&error];
    
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    }
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
//    [self.previewLayer.connection setVideoOrientation:[]];

    

    
    
    
//    [self.previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    CALayer *rootLayer = [[self view] layer];
    [rootLayer setMasksToBounds:YES];
    
    [rootLayer insertSublayer:self.previewLayer atIndex:0];
    
    
    stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [stillImageOutput setOutputSettings:outputSettings];
    
    [self resetFrame];
    
    [session addOutput:stillImageOutput];
    
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];

    
    // Specify the pixel format
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    

    [session startRunning];
    
    UITapGestureRecognizer *tripleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(takeSnapshot)];
    tripleTapGR.numberOfTapsRequired = 3;
    [self.view addGestureRecognizer:tripleTapGR];
    
    UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
    doubleTapGR.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTapGR];
    
    UITapGestureRecognizer *singleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
    singleTapGR.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:singleTapGR];
    
    [singleTapGR requireGestureRecognizerToFail:doubleTapGR];
    [singleTapGR requireGestureRecognizerToFail:tripleTapGR];
    [doubleTapGR requireGestureRecognizerToFail:tripleTapGR];
    
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [self.view addGestureRecognizer:panGR];

    UIPinchGestureRecognizer *pinchGR = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];
    [self.view addGestureRecognizer:pinchGR];
    
    UIRotationGestureRecognizer *rotationGR = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotate:)];
    [self.view addGestureRecognizer:rotationGR];
    
    UILongPressGestureRecognizer *orientationChangeGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(changeOrientation:)];
    //orientationChangeGR.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:orientationChangeGR];
    
}

-(void)createAndPlaySoundID: (NSString*)name
{
    NSString *path = [NSString stringWithFormat: @"%@/%@", [[NSBundle mainBundle] resourcePath], name];
    
    NSURL* filePath = [NSURL fileURLWithPath: path isDirectory: NO];
    SystemSoundID soundID;
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &soundID);
    
    AudioServicesPlaySystemSound(soundID);
}



//- (CGAffineTransform)screenRotation {
//    
//    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
//    
//    float angle = 0;
//    BOOL landscape = NO;
//    
//    switch (orientation) {
//        case UIInterfaceOrientationPortrait :
//            angle = 0;
//            break;
//        case UIInterfaceOrientationLandscapeLeft :
//            angle = .5*M_PI;
//            landscape = YES;
//            break;
//        case UIInterfaceOrientationPortraitUpsideDown :
//            angle = M_PI;
//            break;
//        case UIInterfaceOrientationLandscapeRight :
//            angle = 1.5*M_PI;
//            landscape = YES;
//            break;
//        default:
//            break;
//    }
//    
//    return CGAffineTransformMakeRotation(angle);
//}


- (void)resetFrame {

//    CGAffineTransform transform = [self screenRotation];
//    self.previewLayer.affineTransform = transform;
    
    self.previewLayer.frame = self.view.bounds;

}

- (void)viewDidAppear:(BOOL)animated {
    self.currentOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
    
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (deviceOrientation == UIInterfaceOrientationPortraitUpsideDown)
        [self.previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
    
    else if (deviceOrientation == UIInterfaceOrientationPortrait)
        [self.previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    else if (deviceOrientation == UIInterfaceOrientationLandscapeLeft)
        [self.previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
    
    else
        [self.previewLayer.connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];

}

- (BOOL)shouldAutorotate {
    return NO;
}




- (void)takeSnapshot {
    self.snapshotRequested = YES;
    [self flashScreen];
    AudioServicesPlaySystemSound(1108); // shutter sound
    //[self createAndPlaySoundID:<#(NSString *)#>];
}



-(void)flashScreen {
    CAKeyframeAnimation *opacityAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    NSArray *animationValues = @[ @0.8f, @0.0f ];
    NSArray *animationTimes = @[ @0.3f, @1.0f ];
    id timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    NSArray *animationTimingFunctions = @[ timingFunction, timingFunction ];
    [opacityAnimation setValues:animationValues];
    [opacityAnimation setKeyTimes:animationTimes];
    [opacityAnimation setTimingFunctions:animationTimingFunctions];
    opacityAnimation.fillMode = kCAFillModeForwards;
    opacityAnimation.removedOnCompletion = YES;
    opacityAnimation.duration = 0.4;
    
    [self.whiteScreen.layer addAnimation:opacityAnimation forKey:@"animation"];
}



- (void)doubleTap:(UITapGestureRecognizer *)sender {
    
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    
    self.previewLayer.affineTransform = CGAffineTransformIdentity; //CGAffineTransformMakeRotation(.5*M_PI);
    [self resetFrame];

}

- (void)singleTap:(UITapGestureRecognizer *)sender {
    
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    
    CGPoint focusPoint = [sender locationInView:self.view]; // screen reference frame
    focusPoint = CGPointApplyAffineTransform(focusPoint, CGAffineTransformInvert(self.previewLayer.affineTransform));
//    focusPoint = CGPointApplyAffineTransform(focusPoint, [self screenRotation]);
    // now converted to video feed reference frame
    double focusX = focusPoint.x/self.previewLayer.frame.size.width;
    double focusY = focusPoint.y/self.previewLayer.frame.size.height;
    
    NSError *error;
    [inputDevice lockForConfiguration:&error];
    [inputDevice setFocusPointOfInterest:CGPointMake(focusX,focusY)];
    [inputDevice setFocusMode:AVCaptureFocusModeAutoFocus];
    [inputDevice unlockForConfiguration];
}



- (void)drag:(UIPanGestureRecognizer *)sender {
    
    if (sender.state == UIGestureRecognizerStateBegan ) {
        
        self.lastTransform = self.previewLayer.affineTransform;
        
    } else if (sender.state == UIGestureRecognizerStateChanged) {
    
        CGPoint vector = [sender translationInView:self.view];
        
        CGAffineTransform translation = CGAffineTransformMakeTranslation(vector.x, vector.y);
        
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        self.previewLayer.affineTransform = CGAffineTransformConcat(self.lastTransform,translation);
        [CATransaction commit];
    }
    
}


- (void)pinch:(UIPinchGestureRecognizer *)sender {
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        self.lastTransform = self.previewLayer.affineTransform;
        
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        
        float scale = sender.scale;
        
        CGPoint scalingCenter = [sender locationInView:self.view];
        CGPoint centerPoint = CGPointMake(self.view.frame.size.width*.5,
                                          self.view.frame.size.height*.5);
        CGAffineTransform translation = CGAffineTransformMakeTranslation(scalingCenter.x - centerPoint.x, scalingCenter.y - centerPoint.y);
        
        CGAffineTransform scaling = CGAffineTransformIdentity;
        scaling = CGAffineTransformConcat(scaling, CGAffineTransformInvert(translation));
        scaling = CGAffineTransformConcat(scaling, CGAffineTransformMakeScale(scale,scale));
        scaling = CGAffineTransformConcat(scaling, translation);

        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        self.previewLayer.affineTransform = CGAffineTransformConcat(self.lastTransform,scaling);
        [CATransaction commit];
        
    }
}


- (void)rotate:(UIRotationGestureRecognizer *)sender {
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        self.lastTransform = self.previewLayer.affineTransform;
        
    } else if (sender.state == UIGestureRecognizerStateChanged) {
        
        float angle = sender.rotation;
        
        CGPoint rotationCenter = [sender locationInView:self.view];
        CGPoint centerPoint = CGPointMake(self.view.frame.size.width*.5,
                                          self.view.frame.size.height*.5);
        CGAffineTransform translation = CGAffineTransformMakeTranslation(rotationCenter.x - centerPoint.x, rotationCenter.y - centerPoint.y);

        CGAffineTransform rotation = CGAffineTransformIdentity;
        rotation = CGAffineTransformConcat(rotation, CGAffineTransformInvert(translation));
        rotation = CGAffineTransformConcat(rotation, CGAffineTransformMakeRotation(angle));
        rotation = CGAffineTransformConcat(rotation, translation);
        
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        self.previewLayer.affineTransform = CGAffineTransformConcat(self.lastTransform,rotation);
        [CATransaction commit];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}



// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    
    if (self.snapshotRequested) {
        
        // Create a UIImage from the sample buffer data
        CGImageRef CGImage = [self CGImageFromSampleBuffer:sampleBuffer];

        // apply the current transform to image
        CIImage *image2 = [CIImage imageWithCGImage:CGImage];
        
        image2 = [image2 imageByApplyingTransform:self.previewLayer.affineTransform];
        
        float angle = [self imageRotationAngle];
        
        image2 = [image2 imageByApplyingTransform:CGAffineTransformMakeRotation(angle)];

        
        
        CGImageRef img = [self.imageSavingContext createCGImage:image2 fromRect:[image2 extent]];
        
        UIImage *image = [UIImage imageWithCGImage:img];
        
        [self.library addAssetsGroupAlbumWithName:@"OH Writer Snapshots" resultBlock:^(ALAssetsGroup *group)
        {
            ////NSLog(@"Adding Folder:'Overhead Snapshots', success: %s", group.editable ? "Success" : "Already created: Not Success");
        } failureBlock:^(NSError *error)
        {
            //NSLog(@"Error creating album");
        }];
        
        
        [self.library saveImage:image toAlbum:@"OH Writer Snapshots" completion:^(NSURL *assetURL, NSError *error) {
            if (error) {
                //NSLog(@"ERROR SAVING TO ALBUM");
            }
        } failure:^(NSError *error) {
            if (error!=nil) {
                //NSLog(@"Big error: %@", [error description]);
            }
        }];
        
        CGImageRelease(img);
        CGImageRelease(CGImage);
        
        self.snapshotRequested = NO;
    }
    
}

- (float)imageRotationAngle {
    
    //UIInterfaceOrientation currentOrientation = (UIInterfaceOrientation)[[UIDevice currentDevice] orientation];
    UIUserInterfaceIdiom idiom = [[UIDevice currentDevice] userInterfaceIdiom];
    
    switch (self.currentOrientation) {
            
        case UIInterfaceOrientationPortrait:
            
            //NSLog(@"launched in PORTRAIT");
            
            switch (idiom) {
                
                case UIUserInterfaceIdiomPad:
                    return 1.5*M_PI;
                case UIUserInterfaceIdiomPhone:
                    return 1.5*M_PI;
                case UIUserInterfaceIdiomUnspecified:
                    return 0;
                case UIUserInterfaceIdiomTV:
                    return 0;
                    
            }
            
        case UIInterfaceOrientationLandscapeLeft:
            
            //NSLog(@"launched in LANDSCAPE LEFT");
            switch (idiom) {
                    
                case UIUserInterfaceIdiomPad:
                    return 1.*M_PI;
                case UIUserInterfaceIdiomPhone:
                    return 1*M_PI;
                case UIUserInterfaceIdiomUnspecified:
                    return 0;
                case UIUserInterfaceIdiomTV:
                    return 0;
                    
            }    return 0;
            
        case UIInterfaceOrientationPortraitUpsideDown:
            
            //NSLog(@"launched in PORTRAIT UPSIDE DOWN");
            switch (idiom) {
                    
                case UIUserInterfaceIdiomPad:
                    return .5*M_PI;
                case UIUserInterfaceIdiomPhone:
                    return .5*M_PI;
                case UIUserInterfaceIdiomUnspecified:
                    return 0;
                case UIUserInterfaceIdiomTV:
                    return 0;
                    
            }
            
        case UIInterfaceOrientationLandscapeRight:
            
            //NSLog(@"launched in LANDSCAPE RIGHT");
            switch (idiom) {
                    
                case UIUserInterfaceIdiomPad:
                    return 0*M_PI;
                case UIUserInterfaceIdiomPhone:
                    return 0*M_PI;
                case UIUserInterfaceIdiomUnspecified:
                    return 0;
                case UIUserInterfaceIdiomTV:
                    return 0;
            }
            
        case UIInterfaceOrientationUnknown:
            
            //NSLog(@"interface orientation UNKNOWN");
            return 0;
            
    }
    
}



// Create a CGImage from sample buffer data
- (CGImageRef) CGImageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return (quartzImage);
}


// Create a CGImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    
    CGImageRef quartzImage = [self CGImageFromSampleBuffer:sampleBuffer];
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    return image;
}



- (void)showOrientationLabel {
    
//    float angle = [self imageRotationAngle];

    self.orientationLabel.hidden = NO;
//    [self performSelector:@selector(hideOrientationLabel) withObject:nil afterDelay:1];
}

- (void)hideOrientationLabel {
    self.orientationLabel.hidden = YES;
//    self.orientationLabel.transform = CGAffineTransformIdentity;
}


- (void)changeOrientation:(UIGestureRecognizer *)sender {
    // turns the orientation:
    //    - up direction on the screen turns clockwise
    //    - picture on projector turns counterclockwise
    
//    if (self.orientationJustChanged) {
//        NSLog(@"can't change orientation right now");
//        return;
//    }
//    NSLog(@"canChangeOrientation");
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        //NSLog(@"long press began, setting timer");
        [self showOrientationLabel];
        //self.timer = [NSTimer timerWithTimeInterval:.75 target:self selector:@selector(turnInterface) userInfo:nil repeats:YES];
        //[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        [self performSelector:@selector(turnInterface) withObject:nil afterDelay:.3];
        [self performSelector:@selector(hideOrientationLabel) withObject:nil afterDelay:.8];
    }
//    } else if (sender.state == UIGestureRecognizerStateEnded) {
//        
//        NSLog(@"long press ended, ending timer");
//        [self.timer invalidate];
//        [self hideOrientationLabel];
//        return;
//    }
    
}

- (void)canChangeOrientationAgain {
    self.orientationJustChanged = NO;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)turnInterface {
    
    switch (self.currentOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            self.currentOrientation = UIInterfaceOrientationPortrait;
            //NSLog(@"orientation changed from LL to P");
            break;
        case UIInterfaceOrientationPortrait:
            self.currentOrientation = UIInterfaceOrientationLandscapeRight;
            //NSLog(@"orientation changed from P to LR");
            break;
        case UIInterfaceOrientationLandscapeRight:
            self.currentOrientation = UIInterfaceOrientationPortraitUpsideDown;
            //NSLog(@"orientation changed from LR to PUD");
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            self.currentOrientation = UIInterfaceOrientationLandscapeLeft;
            //NSLog(@"orientation changed from PUD to LL");
            break;
        case UIInterfaceOrientationUnknown:
            //NSLog(@"orientation unknown, unchanged");
            break;
    }
    
//    [[UIDevice currentDevice] setValue:
//     [NSNumber numberWithInteger:self.currentOrientation]
//                                forKey:@"orientation"];

    [self turnExternalDisplay];

    
    
//    self.orientationJustChanged = YES;
//    [self performSelector:@selector(canChangeOrientationAgain) withObject:nil afterDelay:.5];
    
    //[CATransaction begin];
    //[CATransaction setValue:(id)kCFBooleanFalse forKey:kCATransactionDisableActions];
    //[CATransaction setDisableActions:NO];
    //self.orientationLabel.transform = CGAffineTransformConcat(self.orientationLabel.transform, CGAffineTransformMakeRotation(.5*M_PI));
    //[CATransaction commit];
    
    [UIView beginAnimations:@"rotate" context:nil];
    [UIView setAnimationDuration:0.3];
    self.orientationLabel.transform = CGAffineTransformConcat(self.orientationLabel.transform, CGAffineTransformMakeRotation(.5*M_PI));
    [UIView commitAnimations];
    
}

- (void)turnExternalDisplay {
    //NSLog(@"device rotated");
        
    dispatch_async(dispatch_get_main_queue(),^{[[NSNotificationCenter defaultCenter] postNotificationName:UIScreenModeDidChangeNotification object:self];});
  //  [[NSNotificationCenter defaultCenter] postNotificationName:UIScreenDidConnectNotification object:self];
    [[UIApplication sharedApplication] setStatusBarOrientation:self.currentOrientation];
}


@end
