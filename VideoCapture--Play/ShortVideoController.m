//
//  ZYshortViewController.m
//  shipinchuangkou
//
//  Created by zhy on 14-10-17.
//  Copyright (c) 2014年 zhy. All rights reserved.
//

#import "ShortVideoController.h"
#import "VideoRecord.h"
#import <CommonCrypto/CommonDigest.h>
#import <AVFoundation/AVFoundation.h>

#define  offsetY   150
#define  magrgin   10
#define  minduration  1.0

//屏幕区域
#define MainScreenFrame     [[UIScreen mainScreen] bounds]
//屏幕宽度
#define MainScreenWidth     MainScreenFrame.size.width
//屏幕高度
#define MainScreenHeight    MainScreenFrame.size.height

@interface ShortVideoController ()<UIAlertViewDelegate,RecoderDelegate,UIAlertViewDelegate>

@property (nonatomic, weak) UIView  *maskView;

@property (nonatomic, strong) VideoRecord  *recoder;
@property (nonatomic, strong) UIView  *progressBar;
@property (nonatomic, strong)  UIButton  *recordButton;
@property (nonatomic, weak)  UIButton  *cancellBtn;
@property (nonatomic, weak)  UIButton  *deleBtn;

@property (strong, nonatomic) UIAlertView  *alertView;
@property (assign, nonatomic) BOOL isProcessData;
@property (strong, nonatomic) NSDate  *begin;
@property (strong, nonatomic) NSDate  *end;
@property (nonatomic, strong) NSTimer  *timer;
@property (nonatomic, weak)   UIButton  *switchButton;
@property (strong,nonatomic)  UIView  *proBg;
@property (nonatomic, assign) BOOL   isSave;

@property (nonatomic, strong)UIButton *MessBtn;

@property (nonatomic, assign)BOOL  isUpCancle;
/**
 *  第一次触摸是否有效
 */
@property (nonatomic, assign) BOOL  isFirstToch;

/**
 *  是否退出
 */
@property (nonatomic, assign) BOOL  isBack;

@end

@implementation ShortVideoController
-(UIButton *)MessBtn
{
    if (_MessBtn==nil) {
        _MessBtn =[[UIButton alloc]initWithFrame:CGRectMake(0, 0, 100, 35)];
        _MessBtn.center = CGPointMake(self.view.frame.size.width/2, CGRectGetMaxY(self.recoder.VideoPreviewLayer.frame)-30);
       
        [self.maskView addSubview:_MessBtn];
    }
     _MessBtn.titleLabel.font =[UIFont boldSystemFontOfSize:17];
    return _MessBtn;
}
- (void)viewDidLoad {
    
    [super viewDidLoad];
    //添加电话中断响应
    [[NSNotificationCenter  defaultCenter] addObserver:self selector:@selector(shortVideoApplicationWillResignActive) name:UIApplicationWillResignActiveNotification object:[UIApplication sharedApplication]];
    [[NSNotificationCenter  defaultCenter] addObserver:self selector:@selector(shortVideoApplicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    self.isBack= NO;
    [self creatNav];//创建导航栏
 
    //设置背景颜色
    self.view.backgroundColor = color(16, 16, 1, 1);
    [self  CreatMaskView];
    [self  initRecoder];//初始化录制
    [self  initRecoderBtn];
    [self  initToolBar];
}
#pragma mark 当程序进入后台
-(void)shortVideoApplicationWillResignActive{
    self.isBack = YES;
    if (self.recoder) {
        if((KVideoRecordStatusReadyed==self.recoder.status)||(KVideoRecodeStatusEnd==self.recoder.status)){
            [self backClicked];
        }else{
          [self touchesCancelled:nil withEvent:nil];
        }
    }
}
-(void)shortVideoApplicationWillEnterForeground
{
    self.isBack = YES;
    [self touchesCancelled:nil withEvent:nil];
}
-(void)creatNav
{
    UILabel*label=[[UILabel alloc]initWithFrame:CGRectMake(0, 0, 100, 50)];
    label.textColor=[UIColor whiteColor];
    label.text=@"小视频";
    label.textAlignment=NSTextAlignmentCenter;
    label.backgroundColor=[UIColor clearColor];
    self.navigationItem.titleView=label;
}
-(void)backClicked
{
    if (self.recoder) {
        [self.recoder cleanUp];
    }
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    }else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}
-(void)VideoRecordErrorClose
{
    self.alertView = [[UIAlertView alloc]initWithTitle:@"警告" message:@"请在iPhone的”设置－隐私“选项中\n允许人杰招聘访问你的摄像头和麦克风" delegate:self cancelButtonTitle:nil otherButtonTitles:@"确定",nil];
    [self.alertView show];
}
#pragma UIalertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex==0) {
        [alertView dismissWithClickedButtonIndex:0 animated:YES];
    }
   [self.navigationController popViewControllerAnimated:YES];
}

- (void)CreatMaskView
{
    UIView  *maskView =  [[UIView alloc]initWithFrame:self.view.bounds];
    self.maskView  = maskView;
    [self.maskView.layer setMasksToBounds:YES];
    [self.view addSubview:maskView];
}
- (void)initRecoder
{
    self.recoder = [[VideoRecord alloc]init];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(VideoRecordErrorClose) name:@"VideoRecordErrorClose" object:nil];
    _recoder.delegate = self;
    _defaultDuration = 9;
    _recoder.maxDurationTime = (_maxDuration>0.f?_maxDuration:_defaultDuration);
    [self.recoder Ready];
    CGFloat videoLayerX = 0;
    CGFloat videoLayerY = 0;
    CGFloat videoLayerW = DEVICE_SIZE.width;
    CGFloat videoLayerH = 240;

    _recoder.VideoPreviewLayer.frame =CGRectMake(videoLayerX, videoLayerY, videoLayerW, videoLayerH);
    
//    _recoder.coverLayer.frame = _recoder.VideoPreviewLayer.frame;
//    
//    _recoder.cropLayer.frame = _recoder.VideoPreviewLayer.frame;
//    [_recoder.VideoPreviewLayer  setAffineTransform:(CGAffineTransformMakeRotation((CGFloat)M_PI /2.0))];
     [self.maskView.layer addSublayer:_recoder.VideoPreviewLayer];

//     [self.maskView.layer addSublayer:_recoder.coverLayer];
//    
//     [self.maskView.layer addSublayer:_recoder.cropLayer];
}

- (void)initProgressBar
{
    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0,  CGRectGetMaxY(_recoder.VideoPreviewLayer.frame), DEVICE_SIZE.width, 3)];
    view.backgroundColor = [UIColor blackColor];
    [self.view addSubview:view];
    _proBg =view;
    self.progressBar = [[UIView alloc]initWithFrame:CGRectMake(0,  0, DEVICE_SIZE.width, 3)];
    self.progressBar.backgroundColor = [UIColor greenColor];
    [self.proBg addSubview:self.progressBar];
}
-(void)initRecoderBtn
{
    CGFloat buttonW = 120;
    self.recordButton = [[UIButton alloc] initWithFrame:CGRectMake((self.view.frame.size.width - buttonW) / 2.0, CGRectGetMaxY(_recoder.VideoPreviewLayer.frame)+(isIphone5later>0?80:10), buttonW, buttonW)];
    [_recordButton setTitle:@"按住拍" forState:UIControlStateNormal];
    _recordButton.titleLabel.font = [UIFont systemFontOfSize:19];
    _recordButton.backgroundColor = [UIColor colorWithRed:29/255.0 green:29/255.0 blue:29/255.0 alpha:1.0];
    _recordButton.center = CGPointMake(self.view.center.x, (MainScreenHeight-CGRectGetMaxY(_recoder.VideoPreviewLayer.frame))/2+CGRectGetMaxY(_recoder.VideoPreviewLayer.frame));
    _recordButton.layer.masksToBounds = YES;
    _recordButton.layer.cornerRadius = 60;
    [_recordButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    //CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef colorref =[UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:0.5].CGColor;
    //CGColorRef colorref = CGColorCreate(colorSpace,(CGFloat[]){ 0.7, 0.7, 0.7, 0.5 });
    
    [_recordButton.layer setBorderColor:colorref];
    [_recordButton.layer setBorderWidth:1.0];
    
    _isProcessData = YES;
    _recordButton.userInteractionEnabled = NO;
    // [_recordButton addTarget:self action:@selector(caputerManger:) forControlEvents:UIControlEventTouchUpInside];
    [self.maskView addSubview:self.recordButton];
    
}

-(void)stopCaputer
{
    if (self.recoder) {
       [_recoder stop];
    }
}
#pragma mark 创建工具条
-(void)initToolBar
{
    CGFloat buttonW = 35.0f;
    //前后摄像头转换
    UIButton *switchButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.frame.size.width-10-buttonW,CGRectGetMaxY(_recoder.VideoPreviewLayer.frame),buttonW, buttonW)];
    self.switchButton = switchButton;

    [_switchButton setImage:[UIImage imageNamed:@"overturn_up.png"] forState:UIControlStateNormal];
    [_switchButton setImage:[UIImage imageNamed:@"overturn_down.png"] forState:UIControlStateSelected];
    [_switchButton addTarget:self action:@selector(pressSwitchButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:switchButton];
    
}
#pragma mark 摄像头转换
- (void)pressSwitchButton
{
    _switchButton.selected = !_switchButton.selected;
    [_recoder switchCarmer];
}

- (void)startCaputer
{
    if (_isProcessData)
    {
        if (_end ==nil)
        {
            _switchButton.hidden = YES;
            _isSave =YES;
            [self.MessBtn setImage:[UIImage imageNamed:@"cancal_arrow.png"] forState:UIControlStateNormal];
            [self.MessBtn setTitle:@"上滑取消" forState:UIControlStateNormal];
            self.MessBtn.backgroundColor =[UIColor colorWithRed:70/255 green:51/255 blue:30/255 alpha:0.5];
            [self.MessBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [self.MessBtn performSelector:@selector(setHidden:) withObject:@(YES) afterDelay:2.0];
            [_recoder start];
        }
    }
    else
    {
        _switchButton.hidden = YES;
    }
}
#pragma mark 触摸手势
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    
    _begin = [NSDate date];
    _end = nil;
    _isProcessData = YES;
    //NSLog(@"_begin =%@",_begin);
    UITouch  *touch = [touches anyObject];
    CGPoint  touchPoint = [touch locationInView:self.view];
    if (CGRectContainsPoint(_recordButton.frame, touchPoint)){
        _isUpCancle = YES;
        _isFirstToch=YES;
        [self initProgressBar];//创建进度条
        _timer = [NSTimer scheduledTimerWithTimeInterval:minduration target:self selector:@selector(startCaputer) userInfo:nil repeats:NO];//定时器检查防止时间太短
    }else{
        _isFirstToch =NO;
         _isUpCancle = NO;
     }
    if (CGRectContainsPoint(_recoder.VideoPreviewLayer.frame, touchPoint)) {
        [_recoder focusInPoint:touchPoint];//自动聚焦
    }
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.MessBtn) {
        self.MessBtn.hidden = YES;
    }
    if (!_isFirstToch) {
        return;
    }
    if (self.progressBar) {
        [self.progressBar removeFromSuperview];
         self.progressBar.hidden = YES;
    }
    UITouch  *touch = [touches anyObject];
    CGPoint  touchPoint = [touch locationInView:self.view];
    BOOL   isCanSave =CGRectContainsPoint(_recordButton.frame, touchPoint);
    _isProcessData = NO;
    _isUpCancle =NO;
    [_timer invalidate];
    _timer = nil;
    _end = [NSDate date];
    CGFloat second =[_end timeIntervalSinceDate:_begin];
    if (second>minduration)//判断时间是否能够达到
    {
        _isSave =YES;
    }
    else
    {    _isSave = NO;
  
        
        [self.recordButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        return;
    }
    if (!isCanSave)
    {
        _isSave = NO;
    }
    [self  stopCaputer];
}
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_isFirstToch) {
        return;
    }
    UITouch  *touch = [touches anyObject];
    CGPoint  touchPoint = [touch locationInView:self.view];
    if (!CGRectContainsPoint(_recordButton.frame, touchPoint))
    {   if(!_isUpCancle)
    { self.progressBar.backgroundColor = [UIColor colorWithRed:215/255.0 green:1/255.0 blue:16/255.0 alpha:1.0];

    [self.MessBtn setImage:[UIImage imageNamed:@""] forState:UIControlStateNormal];
    [self.MessBtn setTitle:@"松手取消" forState:UIControlStateNormal];
    self.MessBtn.backgroundColor =self.progressBar.backgroundColor;
    [self.recordButton setTitleColor:[UIColor colorWithRed:215/255.0 green:1/255.0 blue:16/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.MessBtn.hidden = NO;

    _isUpCancle = YES;
    }
    else{
       return;}
    }
    else
    {
    if (_isUpCancle) {
    self.progressBar.backgroundColor = [UIColor greenColor];
    [self.MessBtn setImage:[UIImage imageNamed:@"cancal_arrow.png"] forState:UIControlStateNormal];
            [self.MessBtn setTitle:@"上滑取消" forState:UIControlStateNormal];
            self.MessBtn.backgroundColor =[UIColor clearColor];
         [self.recordButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
         self.MessBtn.hidden = NO;
//       [self.MessBtn performSelector:@selector(setHidden:) withObject:@(YES) afterDelay:1];
            _isUpCancle = NO;
        }
        else
        {
            return;
        }
    }
}
-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    //当屏幕失去作用时
     self.isSave = NO;
    [self stopCaputer];
}

#pragma mark VideoRecordDelegate
- (void)videoRecorder:(VideoRecord *)videoRecorder didFinishRecordingToOutPutFileAtURL:(NSURL *)outputFileURL duration:(CGFloat)videoDuration andRotateAngle:(int)angel error:(NSString *)error
{
    if (self.isBack) {//当退出后台/电话
        [self backClicked];
        return;
    }
    if (error.length>0) {
    NSLog(@"录制视频错误:%@", error);
  
    [self.recordButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    NSError *error;
    NSFileManager *mgr = [NSFileManager defaultManager];
    if([mgr removeItemAtURL:outputFileURL error:&error]){
        if (self.progressBar) {
        [self.progressBar removeFromSuperview];
        self.progressBar = nil;
       }
     }
    [self.recoder startRuning];
      return;
     } else{
    NSLog(@"录制视频完成: %@---%d", outputFileURL,_isSave);
    }
        if (_isSave)
        {
            self.maskView.userInteractionEnabled =NO;
            if ([_delegate respondsToSelector:@selector(ShortVideoController:didFinishShortMediaWithThumb:andFilePath:andMD5:andFileDuration:andFileSize:andRotateAngle:)]) {
                NSString  *FilePath = [[outputFileURL absoluteString]substringFromIndex:7];
//              FilePath =[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"20150309150838-0.mp4"];//test文件
                NSLog(@"FilePath = %@",FilePath);
                CGFloat  FileDuration =[self getVideoDuration:FilePath];
                NSString   *imge = [self thumbnailImageForVideo:outputFileURL atTime:0.0];
                NSData    *data = [NSData dataWithContentsOfURL:outputFileURL];
                NSString  *md5 =[self MD5WithData:data];
                NSInteger size =[self getFileSize:FilePath];
                if ([_delegate respondsToSelector:@selector(ShortVideoController:didFinishShortMediaWithThumb:andFilePath:andMD5:andFileDuration:andFileSize:andRotateAngle:)]) {
                   [_delegate ShortVideoController:self didFinishShortMediaWithThumb:imge andFilePath:FilePath andMD5:md5 andFileDuration:FileDuration andFileSize:size andRotateAngle:angel];
                }
                
            }

            [self backClicked];
        }
        else
        {
            [self.recordButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
            NSError *error;
            NSFileManager *mgr = [NSFileManager defaultManager];
            if([mgr removeItemAtURL:outputFileURL error:&error])
            {
                if (self.progressBar) {
                    [self.progressBar removeFromSuperview];
                    self.progressBar = nil;
                }
            }
            self.recoder = nil;
            [self initRecoder];
     
        }
}
/**
 * 进度条
 */
- (void)videoRecorder:(VideoRecord *)videoRecorder didRecordingToOutPutFileduration:(CGFloat)videoDuration
{
    CGRect frame;
    frame = _progressBar.frame;
    frame.size.width-=videoDuration / _recoder.maxDurationTime * DEVICE_SIZE.width;
    _progressBar.frame=frame;
    _progressBar.center = CGPointMake(DEVICE_SIZE.width/2, 2);
}
-(void)videoDurantionChange:(NSNotification*)noti
{
    CGRect frame;
    frame = _progressBar.frame;
    CGFloat videoDuration = [noti.object floatValue];
    frame.size.width-=videoDuration / _recoder.maxDurationTime * DEVICE_SIZE.width;
    _progressBar.frame=frame;
    _progressBar.center = CGPointMake(DEVICE_SIZE.width/2, 2);
}
#pragma mark  MD5加密
- (NSString*)MD5WithData:(NSData*)data
{
    NSString* s=@"";
    if (data!=nil && data.length>0) {
        
        CC_MD5_CTX md5;
        CC_MD5_Init(&md5);
        
        NSData* fileData = data;
        CC_MD5_Update(&md5, [fileData bytes], (int)[fileData length]);
        
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5_Final(digest, &md5);
        s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
             digest[0], digest[1],
             digest[2], digest[3],
             digest[4], digest[5],
             digest[6], digest[7],
             digest[8], digest[9],
             digest[10], digest[11],
             digest[12], digest[13],
             digest[14], digest[15]];
    }
    
    return s;
}
#pragma mark 创建缩略图
- (NSString*) thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset]; assetImageGenerator.appliesPreferredTrackTransform = YES;
    assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time;
    NSError *thumbnailImageGenerationError = nil;
    thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60) actualTime:NULL error:&thumbnailImageGenerationError];
    if (!thumbnailImageRef)
    {
      NSLog(@"thumbnailImageGenerationError %@", thumbnailImageGenerationError);
    }
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
    NSString  *FilePath = [[videoURL absoluteString]substringFromIndex:7];
    FilePath =[[FilePath substringToIndex:FilePath.length-3] stringByAppendingString:@"png"];
    if ([UIImagePNGRepresentation(thumbnailImage) writeToFile:FilePath atomically:YES])
    {
        return FilePath;
    }
    return @"error";
}
#pragma mark  获取视频时长
- (CGFloat)getVideoDuration:(NSString *)path
{
    NSDictionary *opts = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                     forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    NSURL *url = [NSURL fileURLWithPath:path];
    AVURLAsset *urlAsset = [AVURLAsset URLAssetWithURL:url options:opts];
    float second = 0;
    second = urlAsset.duration.value/urlAsset.duration.timescale;
    return second;
}
#pragma mark  获取文件大小
-(NSInteger)getFileSize:(NSString*)path
{
    NSFileManager * filemanager = [[NSFileManager alloc]init];
    if([filemanager fileExistsAtPath:path]){
        NSDictionary * attributes = [filemanager attributesOfItemAtPath:path error:nil];
        NSNumber *theFileSize;
        if ( (theFileSize = [attributes objectForKey:NSFileSize]) )
            return  [theFileSize intValue];
        else
            return -1;
    }
    else
    {
        return -1;
    }
}
-(void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
      
    NSLog(@"=didReceiveMemoryWarning");
    
}
-(void)dealloc
{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    NSLog(@"=ShortVideoController--dealloc==");
}
@end
