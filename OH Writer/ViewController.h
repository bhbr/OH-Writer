//
//  ViewController.h
//  Pure Cam
//
//  Created by Ben Hambrecht on 24.08.15.
//  Copyright (c) 2015 Ben Hambrecht. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ALAssetsLibrary+CustomPhotoAlbum.h"


@interface ViewController : UIViewController <UIGestureRecognizerDelegate,
                                              AVCaptureVideoDataOutputSampleBufferDelegate>

@property (strong, atomic) ALAssetsLibrary* library;

@end

