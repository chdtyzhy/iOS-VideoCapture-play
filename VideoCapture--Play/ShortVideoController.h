//
//  ShortVideoController.h
//  视频录制RocyWrite
//
//  Created by zhy on 14/12/9.
//  Copyright (c) 2014年 zhy. All rights reserved.
//

#import <UIKit/UIKit.h>


@class ShortVideoController;
@protocol ShortVideoControllerDelegate <NSObject>
@optional

-(void)ShortVideoController:(ShortVideoController *)vc didFinishShortMediaWithThumb:(NSString *)thumb andFilePath:(NSString*)path andMD5:(NSString *)str andFileDuration:(CGFloat)FileDuration andFileSize:(NSInteger)size andRotateAngle:(int)angle;
@end

@interface ShortVideoController :UIViewController
/**
 *  默认10s
 */
@property (nonatomic, assign,readonly) CGFloat defaultDuration;
/**
 *  设定最大时长
 */
@property (nonatomic,assign) CGFloat  maxDuration;

@property (nonatomic, weak) id<ShortVideoControllerDelegate>delegate;


@end
