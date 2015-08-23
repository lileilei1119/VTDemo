//
//  H264Decoder.h
//  VTDemo
//
//  Created by lileilei on 15/7/25.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <VideoToolbox/VideoToolbox.h>

@protocol H264DecoderDelegate <NSObject>
@optional

-(void) startDecodeData;
-(void) getDecodeImageData:(CVImageBufferRef) imageBuffer;
@end

@interface H264Decoder : NSObject

@property (nonatomic, strong) id <H264DecoderDelegate> delegate;

@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property (nonatomic, assign) int spsSize;
@property (nonatomic, assign) int ppsSize;

-(void) decodeFrame:(uint8_t *)frame withSize:(uint32_t)frameSize;

@end
