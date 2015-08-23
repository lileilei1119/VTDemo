//
//  H264Encoder.h
//  VTDemo
//
//  Created by lileilei on 15/7/25.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <VideoToolbox/VideoToolbox.h>

@protocol H264EncoderDelegate <NSObject>

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps;
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame;

@end

@interface H264Encoder : NSObject

- (void) initWithConfiguration;
- (void) start:(int)width  height:(int)height;
- (void) initEncode:(int)width  height:(int)height;
- (void) changeResolution:(int)width  height:(int)height;
- (void) encode:(CVImageBufferRef )imageBuffer;

@property (strong, nonatomic) id<H264EncoderDelegate> delegate;

@end
