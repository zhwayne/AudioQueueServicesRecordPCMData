//
//  ViewController.m
//  AudioQueueServices
//
//  Created by wayne on 15/1/14.
//  Copyright (c) 2015年 zh.wayne. All rights reserved.
//

#import "ViewController.h"
#import "MyAQRecorder.h"
#import "MyAudioDataParse.h"
#import "MyAudioDataQueue.h"

@interface ViewController ()
<
MyAudioDataParseDelegate
>
{
	AVAudioPlayer *audioPlayer;
	MyAQRecorder *recorder;
	MyAudioDataParse *audioDataParse;
	
    int iiii;
    float positionArray[3];
	
	BOOL flag;
	FILE *fpl, *fpr;
	
	dispatch_queue_t ql, qr;
}

@property (nonatomic, strong) UIView *bview;


@end

@implementation ViewController


- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    positionArray[0] = 80;
    positionArray[1] = 160;
    positionArray[2] = 240;
    
    _bview = [[UIView alloc] init];
    [_bview setFrame:CGRectMake(0, 0, 40, 40)];
    [_bview setCenter:CGPointMake(positionArray[1], 160)];
    [_bview setBackgroundColor:[UIColor blackColor]];
    
    [self.view addSubview:_bview];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLabel:) name:@"GotData" object:nil];
	
	NSLog(@"%@", NSTemporaryDirectory());
	
	recorder = [MyAQRecorder shareInstance];
	audioDataParse = [MyAudioDataParse shareInstance];
    audioDataParse.delegate = (id)self;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateLabel:(NSNotification *)notification{
    _DataLabel.text = [[notification userInfo] objectForKey:@"data"];
}

- (IBAction)record:(id)sender
{
	UIButton *btn = (UIButton *)sender;
	if(recorder.recorderState.mIsRunning){
		[recorder stop];
        [btn setTitle:@"R" forState:UIControlStateNormal];
	}
	else{
		[recorder record];
        [btn setTitle:@"P" forState:UIControlStateNormal];
	}
	
}

#pragma mark - MyAudioDataParseDelegate
- (void)didParsedDataToDirectionControlState:(TCDirectionControlState)direction{
    switch (direction) {
        case TCDirectionControlStateAdvance:
//            NSLog(@"前进");
            break;
        
        case TCDirectionControlStateBack:
//            NSLog(@"后退");
            break;
            
        case TCDirectionControlStateLeft:
//            NSLog(@"向左");
            iiii--;
            if(iiii < 0){
                iiii = 0;
            }
            break;
            
        case TCDirectionControlStateRight:
//            NSLog(@"向右");
            iiii++;
            if(iiii > 2){
                iiii = 2;
            }
            break;
            
        case TCDirectionControlStateNoAdvanceAndBack:
//            NSLog(@"不前进，也不后退");
            break;
            
        case TCDirectionControlStateNoLeftAndRight:
//            NSLog(@"不向左，也不向右");
			iiii = 1;
			[UIView animateWithDuration:0.1 animations:^{
				[_bview setCenter:CGPointMake(positionArray[iiii], 160)];
			}];
            break;
    }
    
    [UIView animateWithDuration:0.1 animations:^{
        [_bview setCenter:CGPointMake(positionArray[iiii], 160)];
    }];
}

@end
