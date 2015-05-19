//
//  ViewController.m
//  ImitateWeChatShortVideo
//
//  Created by zhy on 15/5/19.
//  Copyright (c) 2015年 zhy. All rights reserved.
//

#import "ViewController.h"
#import "ShortVideoController.h"
#import "thumVideoView.h"

@interface ViewController ()<ShortVideoControllerDelegate>
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIImageView *VideoView;

@end

@implementation ViewController
- (IBAction)captureVideo:(id)sender {

    ShortVideoController  *shorVideoVC = [[ShortVideoController alloc]init];
    shorVideoVC.delegate = self;
    [self presentViewController:shorVideoVC animated:YES completion:^{
        }];
}
-(void)awakeFromNib{
    [super awakeFromNib];
    self.playBtn.layer.masksToBounds = YES;
    self.playBtn.layer.cornerRadius = 5;
}
-(void)ShortVideoController:(ShortVideoController *)vc didFinishShortMediaWithThumb:(NSString *)thumb andFilePath:(NSString *)path andMD5:(NSString *)str andFileDuration:(CGFloat)FileDuration andFileSize:(NSInteger)size andRotateAngle:(int)angle
{
    thumVideoView *viewView = [thumVideoView videoViewWithFilePathStr:path andFrame:self.VideoView.bounds];
    [self.VideoView addSubview:viewView];

}

@end
