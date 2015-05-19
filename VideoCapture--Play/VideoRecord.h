//
//  Recoder.h
//  视频录制RocyWrite
//
//  Created by zhy on 14/12/2.
//  Copyright (c) 2014年 zhy. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define  DEVICE_OS_VERSION   [[[UIDevice currentDevice] systemVersion] floatValue]

#define  color(r,g,b,a)  [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]

#define VIDEO_FOLDER  @"videos"

#define DEVICE_SIZE [[UIScreen mainScreen] applicationFrame].size

#define   isIphone5later  ([UIScreen mainScreen].bounds.size.height > 480.0?YES:NO)

// 1.判断是否为iOS7
#define iOS7 ([[UIDevice currentDevice].systemVersion doubleValue] >= 7.0)

typedef enum : NSUInteger {
    KVideoRecordStatusReadyed,
    KVideoRecodeStatusPlaying,
    KVideoRecodeStatusEnd,
}KVideoRecodeStatus;



@class VideoRecord;

@protocol RecoderDelegate <NSObject>

@optional


//recorder完成一段视频的录制时
-(void)videoRecorder:(VideoRecord *)videoRecorder didFinishRecordingToOutPutFileAtURL:(NSURL *)outputFileURL duration:(CGFloat)videoDuration andRotateAngle:(int)angel error:(NSString *)error;

//recorder正在录制的过程中
- (void)videoRecorder:(VideoRecord *)videoRecorder didRecordingToOutPutFileduration:(CGFloat)videoDuration;

- (void)videoRecorderIsFaild;


@end


@interface VideoRecord : NSObject<AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>


/**
 *  视频预览层
 */
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer  *VideoPreviewLayer;
/**
 *
 */
@property (nonatomic ,strong) CALayer  *coverLayer;
/**
 *
 */
@property (nonatomic ,strong) CAShapeLayer *cropLayer;

/**
 *  设定最大时长
 */
@property (nonatomic, assign) CGFloat maxDurationTime;
/**
 *   视频录制状态
 */
@property (nonatomic, assign,readonly) KVideoRecodeStatus   status;

@property (nonatomic,assign)AVCaptureVideoOrientation videoOrientation;

@property (nonatomic, weak) id<RecoderDelegate>delegate;
/**
 *  配置session
 */
-(void)Ready;

/**
 *  停止采集
 *
 */
-(void)cleanUp;

/**
 *  转换摄像头
 */
-(void)switchCarmer;

/**
 *  开始录制
 */
-(void)start;
/**
 *  停止录制
 */
-(void)stop;
/**
 *  对焦
 */
- (void)focusInPoint:(CGPoint)touchPoint;
/**
 *  开始采集
 */
-(void)startRuning;


@end
