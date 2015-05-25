//
//  Test.h
//  AudioQueueServices
//
//  Created by wayne on 15/1/22.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//

#ifndef __AudioQueueServices__Test__
#define __AudioQueueServices__Test__

#include <stdio.h>
#include "MyAQRecorder.h"
#include "MyAudioDataParse.h"


class Test
{
public:
	Test();
	
private:
	MyAQRecorder *recorder;
	MyAudioDataParse *dataParse;
};

#endif /* defined(__AudioQueueServices__Test__) */
