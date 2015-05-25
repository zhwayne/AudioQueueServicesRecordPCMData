//
//  MyAQRecorder.m
//  AudioQueueServices
//
//  Created by wayne on 15/1/21.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//

#import "MyAQRecorder.h"




#define ThrowError(error, operation)	\
do {						\
if (error) {									\
NSString *reason = [NSString stringWithUTF8String:operation];\
NSString *name = [NSString stringWithUTF8String:__PRETTY_FUNCTION__];	\
NSException *e = [NSException exceptionWithName:name reason:reason userInfo:nil];\
@throw e;							\
}												\
} while (0)



@implementation MyAQRecorder


static void InputBufferCallBack(void *inUserData,
								AudioQueueRef inAQ,
								AudioQueueBufferRef inBuffer,
								const AudioTimeStamp *inTimeStamp,
								UInt32 inNumPackets,
								const AudioStreamPacketDescription *inPacketDesc)
{
	MyAQRecorder *aqr = (__bridge MyAQRecorder *)inUserData;
	
	@try{
		if(inNumPackets > 0){
            // 后台保存数据到自己的数据队列中
            NSData *bufferData = [NSData dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
            dispatch_async(aqr.writeDataQueue, ^{
                [[MyAudioDataQueue shareInstance] enqueueWithData:bufferData];
            });

#if FILEON
			AudioFileWritePackets(aqr->_recorderState.mFileID, FALSE, inBuffer->mAudioDataByteSize,
								  inPacketDesc, aqr->_recorderState.mCurrentPacket, &inNumPackets, inBuffer->mAudioData);
			aqr->_recorderState.mCurrentPacket += inNumPackets;
#endif
		}
	}
	@catch(NSException *exception){
		NSLog(@"捕获到异常: %@", [exception reason]);
		return;
	}
	
	@try{
		if(aqr.recorderState.mIsRunning){
			ThrowError(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL), "音频数据入队操作异常");
		}
		else{
		}
	}
	@catch(NSException *exception){
		NSLog(@"捕获到异常: %@", [exception reason]);
		return;
	}
}


#pragma mark - 单例
+ (instancetype)shareInstance{
	static id share = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		share = [[self alloc] init];
	});
	
	return share;
}


#pragma mark - 销毁
- (void)dealloc{
	[self stop];
}

#pragma mark - 初始化
- (id)init{
	if(self = [super init]){
		_writeDataQueue = dispatch_queue_create("writeDataQueue", NULL);
	}
	
	return self;
}


#pragma mark -
- (void)setRecordFormat{
	// 设置录音格式
	memset(&_recorderState, 0, sizeof(AQRecorderState));
	_recorderState.mRecordFormat.mSampleRate = kSampleRate;					// 采样率
	_recorderState.mRecordFormat.mChannelsPerFrame = kChannelsPerFrame;		// 声道数（单声道）
	_recorderState.mRecordFormat.mFramesPerPacket = 1;						// 一个数据包放一帧数据
	_recorderState.mRecordFormat.mBitsPerChannel = 8;						// 每个声道中的每个采样点用8bit数据量化
    _recorderState.mRecordFormat.mBytesPerFrame = (_recorderState.mRecordFormat.mBitsPerChannel / 8) * _recorderState.mRecordFormat.mChannelsPerFrame;	// 每帧的字节数(2个字节)
    _recorderState.mRecordFormat.mBytesPerPacket = _recorderState.mRecordFormat.mBytesPerFrame * _recorderState.mRecordFormat.mFramesPerPacket;
	_recorderState.mRecordFormat.mFormatID = kAudioFormatLinearPCM;
	_recorderState.mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
}

- (void)copyEncoderCookieToFile
{
    UInt32 propertySize;
    // get the magic cookie, if any, from the converter
    OSStatus err = AudioQueueGetPropertySize(_recorderState.mQueue, kAudioQueueProperty_MagicCookie, &propertySize);
    
    // we can get a noErr result and also a propertySize == 0
    // -- if the file format does support magic cookies, but this file doesn't have one.
    if (err == noErr && propertySize > 0) {
        Byte *magicCookie = (Byte *)malloc(sizeof(Byte) * propertySize);
        UInt32 magicCookieSize;
        ThrowError(AudioQueueGetProperty(_recorderState.mQueue, kAudioQueueProperty_MagicCookie, magicCookie, &propertySize), "get audio converter's magic cookie");
        magicCookieSize = propertySize;	// the converter lies and tell us the wrong size
        
        // now set the magic cookie on the output file
        UInt32 willEatTheCookie = false;
        // the converter wants to give us one; will the file take it?
        err = AudioFileGetPropertyInfo(_recorderState.mFileID, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
        if (err == noErr && willEatTheCookie) {
            err = AudioFileSetProperty(_recorderState.mFileID, kAudioFilePropertyMagicCookieData, magicCookieSize, magicCookie);
            ThrowError(err, "set audio file's magic cookie");
        }
        
        free(magicCookie);
    }
}

- (UInt32)computeBufferSize{
//	UInt32 size;
//	UInt32 frames = (UInt32)ceil(kBufferDurationSeconds * _recorderState.mRecordFormat.mSampleRate);
//	size = frames * _recorderState.mRecordFormat.mBytesPerPacket;
//	return size;
    
    int packets, frames, bytes = 0;
    @try {
        frames = (int)ceil(kBufferDurationSeconds * _recorderState.mRecordFormat.mSampleRate);
        
        if (_recorderState.mRecordFormat.mBytesPerFrame > 0)
            bytes = frames * _recorderState.mRecordFormat.mBytesPerFrame;
        else {
            UInt32 maxPacketSize;
            if (_recorderState.mRecordFormat.mBytesPerPacket > 0)
                maxPacketSize = _recorderState.mRecordFormat.mBytesPerPacket;	// constant packet size
            else {
                UInt32 propertySize = sizeof(maxPacketSize);
                ThrowError(AudioQueueGetProperty(_recorderState.mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,
                                                    &propertySize), "couldn't get queue's maximum output packet size");
            }
            if (_recorderState.mRecordFormat.mFramesPerPacket > 0)
                packets = frames / _recorderState.mRecordFormat.mFramesPerPacket;
            else
                packets = frames;	// worst-case scenario: 1 frame in a packet
            if (packets == 0)		// sanity check
                packets = 1;
            bytes = packets * maxPacketSize;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"捕获到异常: %@", [exception reason]);
        return 0;
    }	
    return bytes;
}

- (void)createAudioQueue{
	ThrowError(AudioQueueNewInput(&_recorderState.mRecordFormat, InputBufferCallBack, (__bridge void *)self, NULL, NULL, 0, &_recorderState.mQueue), "创建音频队列异常");
}

- (void)createAudioQueueBuffer:(UInt32)size{
	for (UInt32 i = 0; i < kNumberRecordBuffers; ++i) {
		ThrowError(AudioQueueAllocateBuffer(_recorderState.mQueue, size, &_recorderState.mQueueBuffer[i]),
				   "AudioQueueAllocateBuffer异常");
		ThrowError(AudioQueueEnqueueBuffer(_recorderState.mQueue, _recorderState.mQueueBuffer[i], 0, NULL),
				   "AudioQueueEnqueueBuffer异常");
	}
}

- (void)setAudioQueueProperty:(AudioQueuePropertyID)aqPropertyID inData:(const void *)inData{
	if(aqPropertyID == kAudioQueueProperty_EnableLevelMetering){
		UInt32 data = *(UInt32 *)inData;
		UInt32 sz = sizeof(data);
		ThrowError(AudioQueueSetProperty(_recorderState.mQueue, aqPropertyID, &data, sz),
				   "AudioQueueSetProperty异常");
	}
}

#pragma mark - 控制
- (void)record{
	@try {
		if(self.recorderState.mIsRunning){
			[self stop];
		}
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
		
		
		// 设置录音格式
		[self setRecordFormat];
		
		// 创建音频队列
		[self createAudioQueue];
        
        [self copyEncoderCookieToFile];
		
		// 创建缓冲区（缓冲器）
		[self createAudioQueueBuffer:[self computeBufferSize]];
		
		// 启用音频电平的声频队列
		UInt32 data = 1;
		[self setAudioQueueProperty:kAudioQueueProperty_EnableLevelMetering inData:&data];
		
		
#if FILEON
		NSString *recordFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.caf"];
		
		CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)recordFile, NULL);
        
        ThrowError(AudioFileCreateWithURL(url, kAudioFileCAFType, &_recorderState.mRecordFormat, kAudioFileFlags_EraseFile, &_recorderState.mFileID), "AudioFileCreateWithURL异常");
		CFRelease(url);
#endif

		_recorderState.mIsRunning = YES;
		ThrowError(AudioQueueStart(_recorderState.mQueue, NULL), "AudioQueueStart异常");
	}
	@catch (NSException *exception) {
		NSLog(@"捕获到异常: %@", [exception reason]);
	}
}

- (void)stop{
	if(_recorderState.mIsRunning){
		_recorderState.mIsRunning = NO;
		AudioQueueStop(_recorderState.mQueue, true);
		AudioQueueDispose(_recorderState.mQueue, true);
		[[AVAudioSession sharedInstance] setActive:NO error:nil];
	}
}

@end




