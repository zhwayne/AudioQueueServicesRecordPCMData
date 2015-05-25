//
//  AudioDataBuffer.m
//  AudioQueueServices
//
//  Created by wayne on 15/1/22.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//

#import "MyAudioDataQueue.h"

@implementation MyAudioDataQueue

+ (instancetype)shareInstance{
	static MyAudioDataQueue *audioBuffer = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		audioBuffer = [[self alloc] init];
	});
	
	return audioBuffer;
}

- (id)init{
	if(self = [super init]){
		dataQueue = [[NSMutableData alloc] init];
	}
	
	return self;
}


- (void)enqueueWithData:(NSData *)data{
	[dataQueue appendData:data];
}

- (void)dequeueBytesWithLength:(NSUInteger)length{
	NSRange range = NSMakeRange(0, length);
	[dataQueue replaceBytesInRange:range withBytes:NULL length:0];
}

- (void)getBytes:(void *)buffer range:(NSRange)range{
    [dataQueue getBytes:buffer range:range];
}

- (void)resetQueue{
	[dataQueue setLength:0];
}

- (NSUInteger)length{
	return [dataQueue length];
}

@end
