//
//  ViewController.h
//  VTDemo
//
//  Created by lileilei on 15/7/25.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "H264Decoder.h"

#include "libavformat/avformat.h"
#include "libswscale/swscale.h"
#include "libavcodec/avcodec.h"
#include "libavformat/avio.h"
#import "AAPLEAGLLayer.h"

@interface ViewController : UIViewController<H264DecoderDelegate>{
    AVFormatContext *pFormatCtx;
    AVPacket packet;
    AVPicture picture;
    int streamNo;
    AAPLEAGLLayer *openGLLayer;
}

@property CADisplayLink *displayLink;
@property NSMutableArray *outputFrames;
@property NSMutableArray *presentationTimes;
@property dispatch_semaphore_t bufferSemaphore;

@property (nonatomic, retain) H264Decoder *h264Decoder;

@end

