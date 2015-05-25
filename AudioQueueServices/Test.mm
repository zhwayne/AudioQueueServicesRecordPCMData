//
//  Test.cpp
//  AudioQueueServices
//
//  Created by wayne on 15/1/22.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//

#include "Test.h"


Test::Test()
{
	recorder = [[MyAQRecorder alloc] init];
	dataParse = [[MyAudioDataParse alloc] init];
	
	[recorder record];
}
