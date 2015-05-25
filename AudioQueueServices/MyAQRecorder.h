//
//  MyAQRecorder.h
//  AudioQueueServices
//
//  Created by wayne on 15/1/21.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>
#import "MyAudioDataQueue.h"


#define FILEON      1


#define kNumberRecordBuffers		(30)		// 缓冲区的个数
#define kBufferDurationSeconds		(0.5)		// 每次的音频输入队列缓存区所保存的是多少秒的数据
#define kSampleRate					(10000)	// 默认的采样率
#define kChannelsPerFrame			1			// 通道数





/**
 *	@struct		录音器状态的结构体.
 *
 *	@field		mQueue
 *					音频队列.
 *	@field		mQueueBuffer
 *					缓冲区指针数组.
 *	@field		mRecordFormat
 *					音频流的基本描述、格式.
 *	@field		mBufferByteSize
 *					每个缓冲区最小字节大小.
 *	@field		mCurrentPacket
 *					从当前音频队列缓冲区写入文件的第一个包（packet）的索引.
 *	@field		mIsRunning
 *					是否正在录音
 */
typedef struct AQRecorderState{
	AudioQueueRef                   mQueue;
	AudioQueueBufferRef             mQueueBuffer[kNumberRecordBuffers];
	AudioStreamBasicDescription     mRecordFormat;
	SInt64                          mCurrentPacket;
	BOOL							mIsRunning;
	AudioFileID						mFileID;
}AQRecorderState;




@interface MyAQRecorder : NSObject

/**
 *	@brief	录音器状态
 */
@property (nonatomic, assign) AQRecorderState recorderState;


@property (nonatomic, strong) dispatch_queue_t writeDataQueue;

+ (instancetype)shareInstance;

/**
 *	@brief  开始录音
 */
- (void)record;

/**
 *	@brief  结束录音
 */
- (void)stop;

@end
