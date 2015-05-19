//
//  thumVideoView.m
//  JobHunting
//
//  Created by zhy on 14/11/13.
//  Copyright (c) 2014年 123. All rights reserved.
//  生成预览层
#import <AVFoundation/AVFoundation.h>
#import "thumVideoView.h"

@interface thumVideoView()

@property (nonatomic,strong)AVAsset      *movieAsset;

@property (nonatomic,strong)AVPlayerItem   *playerIteam;

@property (nonatomic, strong)AVPlayer    *player;

@property (nonatomic, strong)AVPlayerLayer  *playerLayer;
/**
 *  背景图片
 */
@property (nonatomic, weak) UIImageView  *bgView;

@property (nonatomic,strong) NSTimer  *timer;
/**
 *网络转圈
 */
@property (nonatomic, weak)   UIActivityIndicatorView  *actiView;

@property (nonatomic, assign) CGRect  rect;

@property (nonatomic, strong) NSURL *url;

/**
 *  是否来自服务器
 */
@property (nonatomic, assign,readonly) BOOL  isLocal;
/**
 *  播放按钮
 */
@property (nonatomic, weak) UIButton  *playBtn;

@end


@implementation thumVideoView
#pragma mark 网络转圈
-(UIActivityIndicatorView*)actiView
{
    if (_actiView==nil) {
        UIActivityIndicatorView  *actiView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        actiView.center = CGPointMake(self.playerLayer.frame.size.width/2, CGRectGetMaxY(self.playerLayer.frame)-CGRectGetHeight(self.playerLayer.frame)/2);
        [actiView setHidesWhenStopped:YES];
        [self addSubview:actiView];
         _actiView = actiView;
    }
     return  _actiView;
}
#pragma mark  播放按钮
-(UIButton*)playBtn
{
    if (_playBtn==nil) {
        UIButton  *playBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 30, 30)];
        [playBtn setImage:[UIImage imageNamed:@"video_icon"] forState:UIControlStateNormal];
        [self addSubview:playBtn];
        playBtn.center = CGPointMake(self.playerLayer.frame.size.width/2, CGRectGetMaxY(self.playerLayer.frame)-CGRectGetHeight(self.playerLayer.frame)/2);
        playBtn.userInteractionEnabled=NO;
        _playBtn = playBtn;
       }
    return _playBtn;
}
-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = YES;
        _isPlaying = NO;
        _isLocal = YES;
    }
    return self;
}
#pragma mark  部分显示
+(instancetype)videoViewWithFilePathStr:(NSString*)FilePath andFrame:(CGRect)frame
{
    return [[self alloc]initWithFilePath:FilePath andFrame:frame];
}
-(instancetype)initWithFilePath:(NSString*)FilePath andFrame:(CGRect)frame
{
    if (self = [super init]) {
        self.frame = frame;
        self.userInteractionEnabled = YES;
        [self initVideoLayer:FilePath andFrame:frame];
        }
    return self;
}
#pragma mark 全屏显示
+(instancetype)videoViewWithFilePathStr:(NSString*)filePath andFrame:(CGRect)frame andVideoFrame:(CGRect)VF;
{
    NSLog(@"---%@----%@",NSStringFromCGRect(frame),NSStringFromCGRect(VF));
    return [[self alloc]initWithFilePathStr:filePath andFrame:frame andVideoFrame:VF];
}
-(void)layoutSubviews
{
    [super layoutSubviews];
    

}
-(instancetype)initWithFilePathStr:(NSString*)filePath andFrame:(CGRect)frame andVideoFrame:(CGRect)VF
{
    if (self = [super init]) {
        self.backgroundColor = [UIColor blackColor];
        self.frame = frame;
        self.userInteractionEnabled = YES;
        [self initVideoLayer:filePath andFrame:VF];
        UILabel *back = [[UILabel alloc]init];
        [self.player pause];
        back.text = @"如果长时间没有反应,请点击退出";
        back.textAlignment = NSTextAlignmentCenter;
        back.font = [UIFont systemFontOfSize:13];
        back.textColor = [UIColor whiteColor];
        self.timer=[NSTimer scheduledTimerWithTimeInterval:12.0 target:self selector:@selector(reminder:) userInfo:back repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        back.frame = CGRectMake(0, CGRectGetMaxY(self.playerLayer.frame)+10, self.frame.size.width, 50);
        [self addSubview:back];
    }
    return self;
}

#pragma mark －－－－－
-(void)initVideoLayer:(NSString*)FilePath andFrame:(CGRect)bounds
{
    self.VideoPath = FilePath;
    UIImageView *bgView =[[UIImageView alloc]initWithFrame:bounds];
    _bgView = bgView;
    _bgView.userInteractionEnabled = YES;
    _bgView.hidden = NO;
    bgView.image = [UIImage imageNamed:(@"common_surfaceview_default_bg")];
    [self addSubview:_bgView];
    if (FilePath.length) {
    _bgView.hidden =YES;
    _isPlaying = NO;
    NSURL  *url=nil;
    if ([FilePath hasPrefix:@"http"]) {
        _isLocal = NO;
        url = [NSURL URLWithString:FilePath];//网络路径
    }else{
        _isLocal = YES;
        if (![FilePath hasSuffix:@".mp4"]) {//不是mp4
             NSFileManager  *mgr = [NSFileManager defaultManager];
            if ([mgr fileExistsAtPath:FilePath]) {
               NSString* FilePathMP4=[FilePath stringByAppendingPathExtension:@"mp4"];//生成mp4文件
                [mgr copyItemAtPath:FilePath toPath:FilePathMP4 error:nil];
                url = [NSURL fileURLWithPath:FilePathMP4];
            }
        }else{
         url = [NSURL fileURLWithPath:FilePath];//本地路径
        }
        
    }
    AVAsset  *movieAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.playerIteam = [AVPlayerItem playerItemWithAsset:movieAsset];
    [_playerIteam seekToTime:kCMTimeZero];
    self.player = [AVPlayer playerWithPlayerItem:_playerIteam];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    self.playerLayer.frame =bounds;
    _playerLayer.videoGravity =AVLayerVideoGravityResizeAspectFill;
     [self.layer addSublayer:_playerLayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avPlayerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];//添加播放停止监听
    if (!self.isLocal) {//网络
        [self.playerIteam addObserver:self forKeyPath:@"status" options:0 context:nil];
        if (self.actiView) {
            [self.actiView startAnimating];//网络动画
        }
        self.playBtn.hidden  = YES;
    }else{
        self.playBtn.hidden  = NO;
    }
     [self.player pause];
    }
 
}
#pragma mark 全屏展示
-(void)show
{
    if (!self.actiView.isAnimating) {
        [self.actiView startAnimating];
    }
    [[UIApplication sharedApplication].keyWindow addSubview:self];
}
#pragma  mark  生产缩略图
- (NSString*) thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];        assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    NSError *thumbnailImageGenerationError = nil;
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60) actualTime:NULL error:&thumbnailImageGenerationError];
    if (!thumbnailImageRef){
    //NSLog(@"thumbnailImageGenerationError %@", thumbnailImageGenerationError);
    }
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
        NSString  *FilePath = [[videoURL absoluteString]substringFromIndex:7];
    FilePath =[[FilePath substringToIndex:FilePath.length-3] stringByAppendingString:@"png"];
    if ([UIImagePNGRepresentation(thumbnailImage) writeToFile:FilePath atomically:YES]){
        return FilePath;
    }
    return @"error";
}
#pragma  mark KVO
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItem *playIteam = (AVPlayerItem*)object;
        if (playIteam.status == AVPlayerItemStatusReadyToPlay) {
            NSLog(@"开始播放");
            if (self.actiView.isAnimating) {
                [self.actiView stopAnimating];
            }
            if (self.playBtn) {
                self.playBtn.hidden = YES;
            }
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(avPlayerItemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerIteam];
            [self play];
            
        }else{
            NSLog(@"网络加载失败");
        }
    }
}
-(void)reminder:(NSTimer*)timer
{
    UILabel *lable =[timer userInfo];
    [UIView animateWithDuration:2.0 animations:^{
      lable.alpha=0.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:2.0 animations:^{
            lable.alpha =0.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:2.0 animations:^{
                lable.alpha =1.0;
            } completion:^(BOOL finished) {
                lable.alpha =1.0;
            }];
        }];
    }];
    
}

-(void)play
{  _isPlaying = YES;
    if(_bgView){
        [_bgView removeFromSuperview];
        _bgView = nil;
    }
    [_playerIteam seekToTime:kCMTimeZero];
    [_player play];
    self.playBtn.hidden = YES;
}


-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
   
    UITouch  *touch = [touches anyObject];
    CGPoint  touchPoint = [touch locationInView:self];
//    if (CGRectContainsPoint(_playBtn.frame, touchPoint))
//    {
    if(_bgView){
        [_bgView removeFromSuperview];
        _bgView = nil;
    }
    if (_isPlaying) {
        _isPlaying = NO;
        [_player pause];
        [self.playerIteam seekToTime:kCMTimeZero];
        _playBtn.hidden = NO;
    }else{
        _isPlaying = YES;
        [_playerIteam seekToTime:kCMTimeZero];
        [_player play];
        _playBtn.hidden = YES;
    }
//}
    if (!CGRectContainsPoint(_playerLayer.frame, touchPoint)) {
        [_player pause];
        [UIView animateWithDuration:1.0 animations:^{
            self.hidden = NO;
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
            [self.timer invalidate];
            self.timer = nil;
        }];
    }
}

- (void)avPlayerItemDidPlayToEnd:(NSNotification *)notification
{
    if ((AVPlayerItem *)notification.object != _playerIteam) {
        return;
    }
     _isPlaying = NO;
    [UIView animateWithDuration:0.3f animations:^{
        _playBtn.hidden = NO;
    }];
    if ([_delegate respondsToSelector:@selector(thumVideoViewDidEnd)])
    {
        [_delegate thumVideoViewDidEnd];
    }
}
-(void)stop
{
    if (self.player) {
    [self.player setClosedCaptionDisplayEnabled:YES];
        
    [self.playerLayer removeFromSuperlayer];
    [self.playerIteam seekToTime:kCMTimeZero];
        
        
    [self.player pause];
    }
}
-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [self.timer invalidate];
    if (!self.isLocal) {
      [self.playerLayer.player.currentItem removeObserver:self forKeyPath:@"status" context:nil];//移除kvo
    }
}
@end
