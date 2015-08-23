//
//  Mp4Handler.m
//  VTDemo
//
//  Created by lileilei on 15/7/26.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import "Mp4Handler.h"
#import "CommonUitl.h"

@implementation Mp4Handler

-(id)init{
    self = [super init];
    if (self) {
        h264Encoder = [[H264Encoder alloc] init];
        self.isOpen = YES;
    }
    return self;
}

-(void)start:(NSString*)fileName width:(int)width  height:(int)height{
    
    [h264Encoder initWithConfiguration];
    mp4File = [CommonUitl documentsPath:fileName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:mp4File error:nil];
    [fileManager createFileAtPath:mp4File contents:nil attributes:nil];
    
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:mp4File];
    
    [h264Encoder initEncode:width height:height];
    h264Encoder.delegate = self;
}

-(void)handle:(CVImageBufferRef)sampleBuffer{
    [h264Encoder encode:sampleBuffer];
}

- (void) dealloc
{
    [fileHandle closeFile];
    fileHandle = NULL;
}

#pragma mark -  H264EncoderDelegate delegare
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:pps];
    
}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        
        [fileHandle writeData:ByteHeader];
        [fileHandle writeData:data];
    }
}

@end
