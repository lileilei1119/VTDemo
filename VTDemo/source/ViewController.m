//
//  ViewController.m
//  VTDemo
// 联系email lileilei1119@foxmail.com
//  Created by lileilei on 15/7/25.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import "ViewController.h"

#include "libavutil/intreadwrite.h"
#include "avcodec.h"
#include "CommonUitl.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initWithVideo:[CommonUitl bundlePath:@"test.264"]];// test.264  mytest.mp4(Mp4Hander 生成的文件h264格式)
    
    self.outputFrames = [NSMutableArray new];
    self.presentationTimes = [NSMutableArray new];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.displayLink setPaused:YES];
    self.bufferSemaphore = dispatch_semaphore_create(0);
    
    _h264Decoder = [[H264Decoder alloc]init];
    _h264Decoder.delegate = self;
    
    //开始播放
    dispatch_async(dispatch_queue_create("com.wikijoin.video", NULL), ^{
        [self loadFrame];
    });
    
}

-(void)initWithVideo:(NSString *)moviePath
{
    
    AVCodec *pCodec;
    avcodec_register_all();
    av_register_all();
    
    if (avformat_open_input(&pFormatCtx,[moviePath cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL) != 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        return;
    }
    
    if ((streamNo = av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find a video stream in the input file\n");
        return;
    }
    
    AVCodecContext* pCodecCtx = pFormatCtx->streams[streamNo]->codec;
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if(avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
        return;
    }
    
    
}

-(void)loadFrame
{
    while (av_read_frame(pFormatCtx, &packet)>= 0) {
        if (packet.stream_index == streamNo) {
            NSLog(@"=========dddd=========");
            [_h264Decoder decodeFrame:packet.data withSize:packet.size];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)displayPixelBuffer:(CVImageBufferRef)imageBuffer
{
    int width = (int)CVPixelBufferGetWidth(imageBuffer);
    int height = (int)CVPixelBufferGetHeight(imageBuffer);
    CGFloat halfWidth = self.view.frame.size.width;
    CGFloat halfheight = self.view.frame.size.height;
    if (width > halfWidth || height > halfheight) {
        width /= 2;
        height /= 2;
    }
    if (!openGLLayer) {
        openGLLayer = [[AAPLEAGLLayer alloc] init];
        [openGLLayer setFrame:CGRectMake((self.view.frame.size.width-width)/2, (self.view.frame.size.height-height)/2, width, height)];
        openGLLayer.presentationRect = CGSizeMake(width, height);
        
        [openGLLayer setupGL];
        [self.view.layer addSublayer:openGLLayer];
        
        [openGLLayer start:@"mytest.mp4" width:width height:height];
    }
    
    [openGLLayer displayPixelBuffer:imageBuffer];
    
}

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    if ([self.outputFrames count] && [self.presentationTimes count]) {
        CVImageBufferRef imageBuffer = NULL;
        NSNumber *insertionIndex = nil;
        id imageBufferObject = nil;
        @synchronized(self){
            insertionIndex = [self.presentationTimes firstObject];
            imageBufferObject = [self.outputFrames firstObject];
            imageBuffer = (__bridge CVImageBufferRef)imageBufferObject;
            
            if (imageBufferObject) {
                [self.outputFrames removeObjectAtIndex:0];
            }
            if (insertionIndex) {
                [self.presentationTimes removeObjectAtIndex:0];
                if ([self.presentationTimes count] == 3) {
                    dispatch_semaphore_signal(self.bufferSemaphore);
                }
            }
            
            if (imageBuffer) {
                [self displayPixelBuffer:imageBuffer];
            }
        }
        
    }
}

#pragma --mark H264DecoderDelegate
-(void) startDecodeData
{
    if ([self.presentationTimes count] >= 5) {
        [self.displayLink setPaused:NO];
        dispatch_semaphore_wait(self.bufferSemaphore, DISPATCH_TIME_FOREVER);
    }
}

-(void) getDecodeImageData:(CVImageBufferRef) imageBuffer
{
    id imageBufferObject = (__bridge id)imageBuffer;
    @synchronized(self){
        NSUInteger insertionIndex = self.presentationTimes.count + 1;
        
        [self.outputFrames addObject:imageBufferObject];
        [self.presentationTimes addObject:[NSNumber numberWithInteger:insertionIndex]];
        
    }
}

@end

