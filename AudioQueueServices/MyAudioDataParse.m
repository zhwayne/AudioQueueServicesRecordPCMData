//
//  MyAudioDataParse.m
//  AudioQueueServices
//
//  Created by wayne on 15/1/21.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//



/*
 
 采样率默认设置为5000Hz
 控制码高电平时间为0.018s, 采样数90个。
 控制码低电平时间为0.006s, 采样数30个。
 
 数字1高电平时间为0.0032s, 采样数16个。
 数字1低电平时间为0.0012s, 采样数6个。
 
 数字0高电平时间为0.0012s, 采样数6个。
 数字0低电平时间为0.0012s, 采样数6个。
 
 
 通过观察分析数据波形，为简单起见，约定：
 
 连续高电平采样数超过80个，且小于100个，定为判断控制码标志。
 连续高电平采样数超过12个，且小于16个，定为判断1码标志。
 连续高电平采样数超过4个，且小于8个，定为判断0码标志。
 
 连续低电平采样数超过250个，定为静音标志。
 
 采样值的容错个数（需要纠正判断的个数）为3个。
 
 
 还有一种情况比较特殊，蓝牙为了省电可能会停止发送数据，
 这时需要判断是否属于停止发送数据的情况，如果属于，需要
 程序自己组合32个0构成一个信号，表示什么都不干。
 
 
 一秒5个信号，如果一个信号连续超过3个，则判定为有意图的再次发送。
 
 */




#import "MyAudioDataParse.h"
#import "MyAQRecorder.h"


/***********************************************
 采样率为10000的情况：
 */
const UInt32 lenForGet				= 1000;				// 每次取出的字节数
const UInt32 controlCodeSection[2]	= {140, 200};		// 控制码高电平个数范围
const UInt32 oneCodeSection[2]		= {22, 38};			// 1码高电平个数范围
const UInt32 zeroCodeSection[2]		= {6, 16};			// 0码高电平个数范围
const UInt32 silenceDetectionCount	= 1000;				// 静音检测个数
const UInt32 maxRepeatSignalCount	= 3;				// 连续重复信号个数
const UInt32 testCount				= 0;				// 需要校验的采样值个数
const UInt32 signalCount			= 24;				// 一个波的信号个数



@interface MyAudioDataParse ()
{
	@private
	NSUInteger sequentPositiveCount;	// 连续正数的个数
	NSUInteger currentIndex;			// 当前解析的点
    BOOL foundHead;                     // 是否找到了引导码
    char referenceValue;                // 动态基准值
	NSString *signal;					// 待解析的信号
	BOOL isParsing;						// 是否正在解析信号
	
	UInt32 len2;						// 需要循环的次数，减去5是为了防止数组越界
	char minAmax[2];					// 波中最小值和最大值
	UInt32 repeatSignalCount;			// 连续重复的信号个数
	UInt32 notFoundCodeCount;			// 未找到任何码时已检测的采样点个数
	NSMutableString *codeStr;
}

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) dispatch_queue_t praseQueue;

@end

@implementation MyAudioDataParse

#pragma mark - 单例
+ (instancetype)shareInstance{
	static id share = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		share = [[self alloc] init];
	});
	
	return share;
}

- (id)init{
	if(self = [super init]){
        _praseQueue = dispatch_queue_create("praseQueue", NULL);
		_timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(testAudioQueueLength) userInfo:nil repeats:YES];
		len2 = lenForGet - 5;  // 需要循环的次数，减去5是为了防止数组越界
		minAmax[0] = 127, minAmax[1] = -128;      // 波中最小值和最大值
		repeatSignalCount = 0;		// 连续重复的信号个数
		notFoundCodeCount = 0;       // 未找到任何码时已检测的采样点个数
		codeStr = [[NSMutableString alloc] init];
	}
	return self;
}

- (void)dealloc{
	if(_timer){
		[_timer invalidate];
	}
}

- (void)testAudioQueueLength{
	if([[MyAudioDataQueue shareInstance] length] >= lenForGet && !isParsing){
//		NSLog(@"startParseData...");
		isParsing = YES;
		dispatch_async(dispatch_get_global_queue(0, 0), ^{
			[self parseData];
			isParsing = NO;
		});
	}
//	NSLog(@"listening...");
}

- (void)parseData{
	while ([[MyAudioDataQueue shareInstance] length] >= lenForGet) {
		NSRange range = NSMakeRange(0, lenForGet);
		char *buffer = (char *)malloc(lenForGet + 1);
		memset(buffer, 0, lenForGet + 1);
		[[MyAudioDataQueue shareInstance] getBytes:buffer range:range];
		currentIndex = len2;
		
		if(notFoundCodeCount >= silenceDetectionCount){
			// 如果连续silenceDetectionCount个采样点内都没有发现任何码，则判定为静音归位
			notFoundCodeCount = 0;
			signal = @"000000000000000000000000";
			[self detachSignal:signal];
		}else{
			// 遍历取到的字节，找到引导码
			for(UInt32 i = 0; i < len2; ++i, ++notFoundCodeCount){
				
				char v = buffer[i];
//				printf("%-5d", v);
				
				if(v < minAmax[0]) minAmax[0] = v;
				if(v > minAmax[1]) minAmax[1] = v;
				
				// 如果值大于基准值，计数器加1
				if(v > referenceValue){
					++sequentPositiveCount;
				}
				else{
					if(sequentPositiveCount >= oneCodeSection[0] && sequentPositiveCount <= oneCodeSection[1]){//printf("1");
						// 如果满足1码的条件
						notFoundCodeCount = 0;
						sequentPositiveCount = 0;
						[codeStr appendString:@"1"];
						currentIndex = i;   // 标志需要截断的坐标
						break;
					}
					else if(sequentPositiveCount >= zeroCodeSection[0] && sequentPositiveCount <= zeroCodeSection[1]){//printf("0");
						// 如果满足0码的条件
						notFoundCodeCount = 0;
						sequentPositiveCount = 0;
						[codeStr appendString:@"0"];
						currentIndex = i;   // 标志需要截断的坐标
						break;
					}
					else if(sequentPositiveCount >= controlCodeSection[0] && sequentPositiveCount <= controlCodeSection[1]){//printf("\n >>>>>>>>>>【找到引导码】<<<<<<<<<< \n");
						// 如果满足引导码的条件
						notFoundCodeCount = 0;
						sequentPositiveCount = 0;
						// 判断字符串中字节的个数是不是signalCount个
						if([codeStr length] == signalCount){
							if(![codeStr isEqualToString:signal]){
								signal = [NSString stringWithString:codeStr];
								//											NSLog(@"--------------------------------m new signal");
								[self detachSignal:signal];
							}
							else{
								//											NSLog(@"repeatA signal");
								++repeatSignalCount;
								if(repeatSignalCount >= maxRepeatSignalCount){
									[self detachSignal:codeStr];
									repeatSignalCount = 0;
								}
							}
						}
						else{
							//										NSLog(@"filter signal<<<<<<<<<>>>>>>>>");
						}
						[codeStr setString:@""];
						
						currentIndex = i;   // 标志需要截断的坐标
						referenceValue = (minAmax[0] + minAmax[1]) / 2; // 校正基准值
						minAmax[0] = 127, minAmax[1] = -128;            // 重置波中最小值和最大值
						break;
					}
					
					// 重置计数器
					sequentPositiveCount = 0;
				}
			}
		}
		
		// 队列中前currentIndex个字节出队
		free(buffer);
		[[MyAudioDataQueue shareInstance] dequeueBytesWithLength:currentIndex];
//		NSLog(@"-----------------------------------------------------------------%ld", [[MyAudioDataQueue shareInstance] length]);
	}
//	NSLog(@"这一轮的解析完成");
}

- (void)detachSignal:(NSString *)signalStr{
	NSString *signalEctype = [signalStr copy];

	
	// TODO: 分离出第9-16位, 将其转变成8位的数字
	const char *advanceCode = [[signalEctype substringWithRange:NSMakeRange(8, 8)] UTF8String];
	int digital = 0;
	for(int i = 0; i < 8; ++i){
		int ch = advanceCode[i] - 48;
		digital += ch * (1 << (7 - i));
	}
	NSLog(@"%d", digital);
	
	NSString *s = [NSString stringWithFormat:@" %@ %@ %@ %@ %@ %@ - %d", [signalEctype substringWithRange:NSMakeRange(0, 4)], [signalEctype substringWithRange:NSMakeRange(4, 4)], [signalEctype substringWithRange:NSMakeRange(8, 4)], [signalEctype substringWithRange:NSMakeRange(12, 4)], [signalEctype substringWithRange:NSMakeRange(16, 4)], [signalEctype substringFromIndex:20], digital];
	
	// 在主线程中异步发送通知
	dispatch_sync(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"GotData" object:nil userInfo:@{@"data":s}];
	});
	
	// TODO: 根据取得的数字判断方向
	if(digital >= 49 && digital <= 79){
		dispatch_sync(dispatch_get_main_queue(), ^{
//			NSLog(@"左右不动");
			if([self.delegate respondsToSelector:@selector(didParsedDataToDirectionControlState:)]){
				[self.delegate didParsedDataToDirectionControlState:TCDirectionControlStateNoLeftAndRight];
			}
		});
	}
	else if(digital < 49){
		dispatch_sync(dispatch_get_main_queue(), ^{
//			NSLog(@"向左");
			if([self.delegate respondsToSelector:@selector(didParsedDataToDirectionControlState:)]){
				[self.delegate didParsedDataToDirectionControlState:TCDirectionControlStateLeft];
			}
		});
	}
	else if(digital > 79){
		dispatch_sync(dispatch_get_main_queue(), ^{
//			NSLog(@"向右");
			if([self.delegate respondsToSelector:@selector(didParsedDataToDirectionControlState:)]){
				[self.delegate didParsedDataToDirectionControlState:TCDirectionControlStateRight];
			}
		});
	}
}

@end
