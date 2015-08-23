//
//  Mp4Handler.h
//  VTDemo
//
//  Created by lileilei on 15/7/26.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "H264Encoder.h"

@interface Mp4Handler : NSObject<H264EncoderDelegate>{
    H264Encoder *h264Encoder;
    NSFileHandle *fileHandle;
    NSString *mp4File;
}

@property BOOL isOpen;

-(void)start:(NSString*)fileName width:(int)width  height:(int)height;
- (void)handle:(CVImageBufferRef)sampleBuffer;

@end
