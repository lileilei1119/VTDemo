//
//  H264Encoder.m
//  VTDemo
//
//  Created by lileilei on 15/7/25.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import "H264Encoder.h"

@import VideoToolbox;
@import AVFoundation;

@implementation H264Encoder
{
    NSString * yuvFile;
    VTCompressionSessionRef encoderSession;
    dispatch_queue_t encoderQueue;
    CMFormatDescriptionRef  format;
    CMSampleTimingInfo * timingInfo;
    BOOL initialized;
    int  frameCount;
    NSData *sps;
    NSData *pps;
}

- (void) initWithConfiguration
{
    
    encoderSession = nil;
    initialized = true;
    encoderQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    frameCount = 0;
    sps = NULL;
    pps = NULL;
    
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264Encoder* encoder = (__bridge H264Encoder*)outputCallbackRefCon;
    
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder->_delegate)
                {
                    [encoder->_delegate gotSpsPps:encoder->sps pps:encoder->pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder->_delegate gotEncodedData:data isKeyFrame:keyframe];
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
    
}

- (void) start:(int)width  height:(int)height
{
    int frameSize = (width * height * 1.5);
    
    if (!initialized)
    {
        NSLog(@"encoder Not initialized");
        return;
    }
    dispatch_sync(encoderQueue, ^{
        
        // Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &encoderSession);
        NSLog(@"encoder VTCompressionSessionCreate %d", (int)status);
        
        if (status != 0)
        {
            NSLog(@"encoder Unable to create a H264 session");
            return ;
            
        }
        
        // Set the properties
        VTSessionSetProperty(encoderSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(encoderSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        VTSessionSetProperty(encoderSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, 240);
        
        VTSessionSetProperty(encoderSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        
        VTCompressionSessionPrepareToEncodeFrames(encoderSession);
        
        int fd = open([yuvFile UTF8String], O_RDONLY);
        if (fd == -1)
        {
            NSLog(@"encoder Unable to open the file");
            return ;
        }
        
        NSMutableData* theData = [[NSMutableData alloc] initWithLength:frameSize] ;
        NSUInteger actualBytes = frameSize;
        while (actualBytes > 0)
        {
            void* buffer = [theData mutableBytes];
            NSUInteger bufferSize = [theData length];
            
            actualBytes = read(fd, buffer, bufferSize);
            if (actualBytes < frameSize)
                [theData setLength:actualBytes];
            
            frameCount++;

            CMBlockBufferRef BlockBuffer = NULL;
            OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, buffer, actualBytes,kCFAllocatorNull, NULL, 0, actualBytes, kCMBlockBufferAlwaysCopyDataFlag, &BlockBuffer);
            
            if (status != noErr)
            {
                NSLog(@"encoder CMBlockBufferCreateWithMemoryBlock failed %d", (int)status);
                
                return ;
            }
            
            CMSampleBufferRef sampleBuffer = NULL;
            CMFormatDescriptionRef formatDescription;
            CMFormatDescriptionCreate ( kCFAllocatorDefault,
                                       kCMMediaType_Video,
                                       'I420',
                                       NULL,
                                       &formatDescription );
            CMSampleTimingInfo sampleTimingInfo = {CMTimeMake(1, 300)};
            
            OSStatus statusCode = CMSampleBufferCreate(kCFAllocatorDefault, BlockBuffer, YES, NULL, NULL, formatDescription, 1, 1, &sampleTimingInfo, 0, NULL, &sampleBuffer);
            
            if (statusCode != noErr) {
                NSLog(@"encoder CMSampleBufferCreate failed %d", (int)statusCode);
                
                return;
            }
            CFRelease(BlockBuffer);
            BlockBuffer = NULL;
            
            CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
            
            CMTime presentationTimeStamp = CMTimeMake(frameCount, 300);
            VTEncodeInfoFlags flags;
            
            statusCode = VTCompressionSessionEncodeFrame(encoderSession,
                                                         imageBuffer,
                                                         presentationTimeStamp,
                                                         kCMTimeInvalid,
                                                         NULL, NULL, &flags);
            if (statusCode != noErr) {
                NSLog(@"encoder VTCompressionSessionEncodeFrame failed %d", (int)statusCode);
                
                VTCompressionSessionInvalidate(encoderSession);
                CFRelease(encoderSession);
                encoderSession = NULL;
                return;
            }
            NSLog(@"encoder VTCompressionSessionEncodeFrame Success");
            
        }
        
        VTCompressionSessionCompleteFrames(encoderSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(encoderSession);
        CFRelease(encoderSession);
        encoderSession = NULL;
        
        close(fd);
    });
    
    
}
- (void) initEncode:(int)width  height:(int)height
{
    dispatch_sync(encoderQueue, ^{
        
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &encoderSession);
        NSLog(@"encoder VTCompressionSessionCreate %d", (int)status);
        
        if (status != 0)
        {
            NSLog(@"encoder VTCompressionSessionCreate failed");
            return ;
        }
        
        VTSessionSetProperty(encoderSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(encoderSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        
        
        VTCompressionSessionPrepareToEncodeFrames(encoderSession);
    });
}
- (void) encode:(CVImageBufferRef)imageBuffer
{
    dispatch_sync(encoderQueue, ^{
        
        frameCount++;
        
        if (imageBuffer==nil) {
            NSLog(@"imagebuffer is nil");
            return ;
        }
        CMTime presentationTimeStamp = CMTimeMake(frameCount, 1000);
        VTEncodeInfoFlags flags;
        
        OSStatus statusCode = VTCompressionSessionEncodeFrame(encoderSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
        if (statusCode != noErr) {
            NSLog(@"encoder VTCompressionSessionEncodeFrame failed %d", (int)statusCode);
            
            VTCompressionSessionInvalidate(encoderSession);
            CFRelease(encoderSession);
            encoderSession = NULL;
            return;
        }
        NSLog(@"encoder VTCompressionSessionEncodeFrame  Success");
    });
    
    
}
- (void) changeResolution:(int)width  height:(int)height
{
}


- (void) dealloc
{
    VTCompressionSessionCompleteFrames(encoderSession, kCMTimeInvalid);
    
    VTCompressionSessionInvalidate(encoderSession);
    CFRelease(encoderSession);
    encoderSession = NULL;
}
@end
