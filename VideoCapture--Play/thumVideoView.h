//
//  thumVideoView.h
//  JobHunting
//
//  Created by zhy on 14/11/13.
//  Copyright (c) 2014年 123. All rights reserved.
//  生成预览层

#import <UIKit/UIKit.h>

@protocol thumVideoViewDelegate <NSObject>

@optional

-(void)thumVideoViewDidEnd;

@end

@interface thumVideoView : UIImageView

/**
 *  path
 */
@property (nonatomic,copy)NSString    *VideoPath;

@property (nonatomic, weak)id<thumVideoViewDelegate>delegate;

@property (nonatomic, assign)BOOL isPlaying;

-(void)play;

-(void)stop;
/**
 *  视频简历
 */
+(instancetype)videoViewWithFilePathStr:(NSString*)FilePath andFrame:(CGRect)frame;
/**
 *  展示空间
 */
+(instancetype)videoViewWithFilePathStr:(NSString*)filePath andFrame:(CGRect)frame andVideoFrame:(CGRect)VF;
/**
 * 全屏展示
 */
-(void)show;
@end
