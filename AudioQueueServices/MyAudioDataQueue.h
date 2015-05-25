//
//  AudioDataBuffer.h
//  AudioQueueServices
//
//  Created by wayne on 15/1/22.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//


/**
 *
 */

#import <Foundation/Foundation.h>

@interface MyAudioDataQueue : NSObject
{
	@private
	NSMutableData *dataQueue;
}

+ (instancetype)shareInstance;

/**
 *	@brief  字节入队
 *
 *	@param bytes  待入队的字节
 *	@param length 字节长度
 */
- (void)enqueueWithData:(NSData *)data;


/**
 *	@brief  出队length长度的字节
 *
 *	@param length 长度
 */
- (void)dequeueBytesWithLength:(NSUInteger)length;


/**
 *	@brief  从队列中取出（复制出）length字节的数据
 *
 *	@param buffer   缓冲区，取出的数据放入到这里
 *	@param range    数据区间
 */
- (void)getBytes:(void *)buffer range:(NSRange)range;

/**
 *	@brief  重置队列
 */
- (void)resetQueue;

/**
 *	@brief  返回队列长度
 */
- (NSUInteger)length;

@end
