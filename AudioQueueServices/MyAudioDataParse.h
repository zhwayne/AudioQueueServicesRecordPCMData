//
//  MyAudioDataParse.h
//  AudioQueueServices
//
//  Created by wayne on 15/1/21.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSInteger, TCDirectionControlState){
    TCDirectionControlStateAdvance               = 0,
    TCDirectionControlStateBack                  = 1,
    TCDirectionControlStateLeft                  = 2,
    TCDirectionControlStateRight                 = 3,
    TCDirectionControlStateNoAdvanceAndBack      = 4,
    TCDirectionControlStateNoLeftAndRight        = 5,
};


@protocol MyAudioDataParseDelegate <NSObject>

@optional
- (void)didParsedDataToDirectionControlState:(TCDirectionControlState)direction;

@end

@interface MyAudioDataParse : NSObject

@property (nonatomic, assign) id<MyAudioDataParseDelegate> delegate;

+ (instancetype)shareInstance;

@end
