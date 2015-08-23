//
//  CommonUitl.m
//  VideoDemo
//
//  Created by lileilei on 15/7/25.
//  Copyright (c) 2015年 lileilei. All rights reserved.
//

#import "CommonUitl.h"

@implementation CommonUitl

+(NSString *)bundlePath:(NSString *)fileName {
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:fileName];
}

+(NSString *)documentsPath:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}

@end
