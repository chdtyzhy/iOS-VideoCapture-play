//
//  Recoder.m
//  视频录制RocyWrite
//
//  Created by zhy on 14/12/2.
//  Copyright (c) 2014年 zhy. All rights reserved.
//

#import "VideoRecord.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define BYTES_PER_PIXEL 4

#define COUNT_DUR_TIMER_INTERVAL  0.02  //定时间隔

@interface VideoRecord()
{
    NSURL *movieURL;
    AVCaptureSession  *_captureSession;
    NSDictionary *_videoCompressionSettings;
    NSDictionary *_audioCompressionSettings;
    AVCaptureDevice *_videoDevice;
    AVCaptureConnection *_audioConnection;
    AVCaptureConnection *_videoConnection;
    
    AVCaptureVideoDataOutput *videoOutput;
    AVCaptureAudioDataOutput *audioOutput;
    
    AVCaptureDeviceInput  *videoInput;
    AVCaptureDeviceInput  *_audioInput;
  
    dispatch_queue_t audioWritingQueue;
    
    dispatch_queue_t _writingQueue;
    
    dispatch_queue_t _videoDataOutputQueue;
    
    NSMutableArray *previousSecondTimestamps;
    CMVideoDimensions videoDimensions;
    CMVideoCodecType videoType;
    Float64 videoFrameRate;
    
    AVCaptureVideoOrientation  referenceOrientation;
    

    
    
    BOOL readyToRecordAudio;
    BOOL readyToRecordVideo;
    
    BOOL _runing;
    /**
     *  是否打开摄像头
     */
    BOOL isOpenCamer;
    /**
     *  是否支持前置摄像头
     */
    BOOL isSupportFrontCarma;
    /**
     *  是否支持后置摄像头
     */
    BOOL isSupportBackCarma;
    
    BOOL  _isRecording;
    
}
@property (nonatomic,strong)AVAssetWriter *videoWriter;

@property (nonatomic,strong)AVAssetWriterInput *videoWriterInput;
@property (nonatomic,strong)AVAssetWriterInput *audioWriterInput;

@property (nonatomic, assign) int  RotateAngle;

@property (nonatomic, strong) NSTimer  *countTimer;

@property (nonatomic, assign) CGFloat currentTime;

@property (nonatomic, assign) BOOL   audioDataSuccess;
@property (nonatomic, assign) BOOL   videoDataSuccess;

@property (nonatomic, assign) CGRect cropRect;

/**
  是否使用前置摄像头
 */
@property (nonatomic, assign)BOOL isUsingFrontCamera;

@end

@implementation VideoRecord
-(id)init
{
    if (self = [super init]) {
    _writingQueue = dispatch_queue_create( "com.rjping.writing", DISPATCH_QUEUE_SERIAL );

    _videoDataOutputQueue = dispatch_queue_create( "com.rjping.session.videodata", DISPATCH_QUEUE_SERIAL );
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didStartRuning:) name:AVCaptureSessionDidStartRunningNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(didStopRuning:) name:AVCaptureSessionDidStopRunningNotification object:nil];
    _audioDataSuccess = NO;
    _videoDataSuccess = NO;
    }
    return self;
}

-(void)Ready
{
    previousSecondTimestamps =[NSMutableArray array];
    referenceOrientation=AVCaptureVideoOrientationPortrait;
    //  [self createVideoFolderIfNotExist];
    _isUsingFrontCamera=NO;//设定默认摄像头
    [self setupCaptureSessionWithIsFrontCamer:_isUsingFrontCamera];
    if (isOpenCamer) {
        if (!_captureSession.isRunning) {
         [_captureSession startRunning];
        }
    }
    else{
        [[NSNotificationCenter defaultCenter]postNotificationName:@"VideoRecordErrorClose" object:self userInfo:nil];
    }
    _RotateAngle = 90;//默认旋转角度
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
 
    readyToRecordAudio = NO;
    readyToRecordVideo = NO;
    _status = KVideoRecordStatusReadyed;
}

- (void)deviceOrientationDidChange_video
{
    NSLog(@"屏幕旋转了");
   UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if ( UIDeviceOrientationIsPortrait(orientation) || UIDeviceOrientationIsLandscape(orientation) )
    {
        referenceOrientation=(AVCaptureVideoOrientation)orientation;
    }
}

#pragma mark 切换前后摄像头
- (void)switchCarmer
{
    if (!isSupportFrontCarma || !isSupportFrontCarma || !videoInput) {
        return;
    }
    if (_captureSession.isRunning) {
        [_captureSession stopRunning];
    }
    [_captureSession removeInput:videoInput];
    [_captureSession removeOutput:videoOutput];

    [_captureSession beginConfiguration];
    
    self.isUsingFrontCamera = !_isUsingFrontCamera;
    AVCaptureDevice *device = [self getCameraDevice:_isUsingFrontCamera];
    
    [device lockForConfiguration:nil];
    if ([device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
    }
    [device unlockForConfiguration];
    
    _videoDevice =device;
    videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    if([_captureSession canAddInput:videoInput])
    {
        [_captureSession addInput:videoInput];
    }
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
    [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    [videoOutput setSampleBufferDelegate:self queue:_videoDataOutputQueue];
    
    if ([_captureSession canAddOutput:videoOutput]) {
        [_captureSession addOutput:videoOutput];
    }
    _videoConnection =[videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    self.videoOrientation = [_videoConnection videoOrientation];//判断视频方向
   [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
   [_captureSession commitConfiguration];
   [_captureSession startRunning];
}

- (AVCaptureDevice *)getCameraDevice:(BOOL)isFront
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    
    for (AVCaptureDevice *camera in cameras) {
        if (camera.position == AVCaptureDevicePositionBack) {
            backCamera = camera;
            isSupportBackCarma =YES;
        } else {
            frontCamera = camera;
            isSupportFrontCarma = YES;
        }
    }
    
    if (isFront) {
        return frontCamera;
    }
    
    return backCamera;
}

#pragma mark 开始
-(void)start
{

    if (_audioDataSuccess&&_videoDataSuccess) {
        return;
    }
  
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];//获取屏幕方向
    NSLog(@"deviceOrientationDidChange = %ld",(long)orientation);
    if (orientation==UIDeviceOrientationPortrait) {
            _RotateAngle = 90;
         }else if (orientation==UIDeviceOrientationPortraitUpsideDown){
            _RotateAngle = 270;
         }else if (orientation == UIDeviceOrientationLandscapeLeft){
            _RotateAngle = 0;
         }else if (orientation == UIDeviceOrientationLandscapeRight)
         {
            _RotateAngle = 180;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange_video) name:UIDeviceOrientationDidChangeNotification object:nil];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    if (![_captureSession isRunning]) {
        [_captureSession startRunning];
    }
    [self startCountTimer];
    NSError *error;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    NSString *fileName = [nowTimeStr stringByAppendingString:@".mp4"];
    movieURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), fileName]];
#pragma mark  输出文件类型
    _videoWriter = [[AVAssetWriter alloc] initWithURL:movieURL fileType:(NSString *)kUTTypeMPEG4 error:&error];
        if (error){
            NSLog(@"=error==%@",error.localizedDescription) ;
        }
        else{
            _status = KVideoRecodeStatusPlaying;
    }
}
/**
 *  开始采集
 */
-(void)didStartRuning:(NSNotification*)noti
{
//    if (!self.isDidStartRuning) {
//        return;
//    }
//    self.isDidStartRuning = YES;
    NSLog(@"确实开始了---%@",[NSThread currentThread]);
}

/**
 *  开始计时器
 */
-(void)startCountTimer
{
    self.currentTime = 0.0f;
    if (self.countTimer==nil) {
      self.countTimer =[NSTimer scheduledTimerWithTimeInterval:COUNT_DUR_TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
    }
}
-(void)onTimer:(NSTimer*)timer
{
    self.currentTime+=COUNT_DUR_TIMER_INTERVAL;
        if ([_delegate respondsToSelector:@selector(videoRecorder:didRecordingToOutPutFileduration:)]) {
            [_delegate videoRecorder:self didRecordingToOutPutFileduration:COUNT_DUR_TIMER_INTERVAL];
        }
    if (_currentTime >= self.maxDurationTime)
    {
        [self stop];
    }
}
- (void)stopCountDurTimer
{
    self.currentTime=0.0;
    if (self.countTimer) {
        [_countTimer invalidate];
        self.countTimer = nil;
    }
}
- (NSString *)getVideoSaveFilePathString
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    NSFileManager  *mgr = [NSFileManager defaultManager];
    if ([mgr fileExistsAtPath:path]) {
         [mgr createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
   
   NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mp4"];
    
    return fileName;
}



#pragma mark 停止
-(void)stop
{
 [_captureSession stopRunning];
}
-(void)didStopRuning:(NSNotification*)noti
{
    if (_videoWriter==nil) {
        return;
    }
    if (_videoWriter.status==AVAssetWriterStatusUnknown) {
        return;
    }
    if (_writingQueue==nil) {
        return;
    }
    if (self.countTimer) {
        [self stopCountDurTimer];
    }
    dispatch_async(_writingQueue, ^{
        [_videoWriter finishWritingWithCompletionHandler:^{
            NSLog(@"确实完成");
            _audioWriterInput=nil;
            _videoWriterInput=nil;
            readyToRecordVideo = NO;
            readyToRecordAudio = NO;
            _videoWriter=nil;
            _audioDataSuccess = NO;
            _videoDataSuccess = NO;
            if (_videoWriter.error) {//失败
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([_delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutPutFileAtURL:duration:andRotateAngle:error:)]){
                        [_delegate videoRecorder:self didFinishRecordingToOutPutFileAtURL:movieURL duration:_currentTime andRotateAngle:_RotateAngle error:@"写入失败"];
                    }
                });
            }else{//成功
//               [self videoClipFileUrl:movieURL];//裁剪视频
                _status = KVideoRecodeStatusEnd;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([_delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutPutFileAtURL:duration:andRotateAngle:error:)]){
                        [_delegate videoRecorder:self didFinishRecordingToOutPutFileAtURL:movieURL duration:_currentTime andRotateAngle:_RotateAngle error:nil];
                    }
                });
            }
        }];
    });
}
-(void)cleanUp
{
    if (_captureSession.isRunning)
    {
        [_captureSession stopRunning];
    }
    if (_writingQueue) {
        _writingQueue = nil;
    }
    if (_videoDataOutputQueue) {
        _videoDataOutputQueue=nil;
    }
    if (audioWritingQueue) {
        audioWritingQueue = nil;
    }
}

#pragma 设置session
- (void)setupCaptureSessionWithIsFrontCamer:(BOOL)isBackCamer
{
    
    _captureSession = [[AVCaptureSession alloc] init];
    /**
     * 设置采样设置图片指令
     */

    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }else{
          _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }
    /**
     *   添加视频预览层
     */
    _VideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    /**
     *  填充模式
     */
    _VideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    _VideoPreviewLayer.masksToBounds = YES;
//    
//    //添加视频裁剪层
//    _coverLayer = [CALayer layer];
//    
//    _cropLayer = [CAShapeLayer layer];

    
    isOpenCamer = YES;
    if ([_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
    [_captureSession beginConfiguration];
  
    /**创建音频*/
    AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
    _audioInput = audioIn;
    if ([_captureSession canAddInput:audioIn]) {
        [_captureSession addInput:audioIn];
    }
    else
    {
         isOpenCamer =NO;
    }
   audioOutput= [[AVCaptureAudioDataOutput alloc] init];
   dispatch_queue_t audioCaptureQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    audioWritingQueue=audioCaptureQueue;
    if ([_captureSession canAddOutput:audioOutput]) {
        [_captureSession addOutput:audioOutput];
    }else{
        isOpenCamer = NO;
    }
    _audioCompressionSettings = [audioOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    NSLog(@"-_audioCompressionSettings--%@",_audioCompressionSettings);
    [audioOutput setSampleBufferDelegate:self queue:audioCaptureQueue];
    _audioConnection=[audioOutput connectionWithMediaType:AVMediaTypeAudio];
    
    /**创建视频－－－－默认为后置摄像头*/
    NSError  *error;
    AVCaptureDeviceInput *videoInputBack =  [[AVCaptureDeviceInput alloc] initWithDevice:[self getCameraDevice:isBackCamer] error:&error];
    NSLog(@"%@",error);
    videoInput =videoInputBack;
    if ([_captureSession canAddInput:videoInput]) {
    
        [_captureSession addInput:videoInput];
    }
    else
    {
        isOpenCamer = NO;
    }
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    if ([_captureSession canAddOutput:videoOutput]) {
        [_captureSession addOutput:videoOutput];
    }
    _videoCompressionSettings = [videoOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
      NSLog(@"-_videoCompressionSettings--%@",_videoCompressionSettings);
   [videoOutput setSampleBufferDelegate:self queue:_videoDataOutputQueue];
    
    _videoConnection =[videoOutput connectionWithMediaType:AVMediaTypeVideo];
   self.videoOrientation = [_videoConnection videoOrientation];//判断视频方向
  [_videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
   [_captureSession commitConfiguration];

}
- (AVCaptureDevice *)audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0)
        return [devices objectAtIndex:0];
    
    return nil;
}
-(void)startRuning
{
      [self setupCaptureSessionWithIsFrontCamer:NO];
      _runing = YES;
      [_captureSession startRunning];
}


#pragma mark 设定音频输入
- (BOOL) setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription
{
    const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    
    size_t aclSize = 0;
    const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
    NSData *currentChannelLayoutData = nil;
    
    // AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
    if ( currentChannelLayout && aclSize > 0 )
        currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
    else
        currentChannelLayoutData = [NSData data];
//    NSLog(@"%f－－－－%@",currentASBD->mSampleRate,currentChannelLayoutData);
//    if (_audioCompressionSettings==nil) {
        NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                                  [NSNumber numberWithFloat:16000.f], AVSampleRateKey,
                                                  [NSNumber numberWithInt:33000], AVEncoderBitRatePerChannelKey,
                                                  [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame], AVNumberOfChannelsKey,
                                                  currentChannelLayoutData, AVChannelLayoutKey,
                                                  nil];
        _audioCompressionSettings =audioCompressionSettings;
//    }
    if ([_videoWriter canApplyOutputSettings:_audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
        _audioWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:_audioCompressionSettings];
        _audioWriterInput.expectsMediaDataInRealTime = YES;
        if ([_videoWriter canAddInput:_audioWriterInput])
            [_videoWriter addInput:_audioWriterInput];
        else {
            NSLog(@"Couldn't add asset writer audio input.");
            return NO;
        }
    }
    else {
        NSLog(@"Couldn't apply audio output settings.");
        return NO;
    }
    return YES;
}
#pragma mark 设定视频输入
- (BOOL) setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription
{
  float bitsPerPixel;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
    int numPixels = dimensions.width * dimensions.height;
    int bitsPerSecond;
  NSLog(@"-dimensions--%d====%d",dimensions.width,dimensions.height);
    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
//    if ( numPixels < (320 * 240) )
//        bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
//    else
//        bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
    bitsPerSecond = numPixels/2.0;
//    if (_videoCompressionSettings==nil) {
    NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              AVVideoCodecH264, AVVideoCodecKey,
                                              [NSNumber numberWithInteger:320], AVVideoWidthKey,
                                              [NSNumber numberWithInteger:240], AVVideoHeightKey,
                                              [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
                                               [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,   //
                                               AVVideoProfileLevelH264BaselineAutoLevel,AVVideoProfileLevelKey,
                                               nil], AVVideoCompressionPropertiesKey,
                                              nil];
        _videoCompressionSettings = videoCompressionSettings;
//    }
    if ([_videoWriter canApplyOutputSettings:_videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
    _videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:_videoCompressionSettings];
//  NSLog(@"add asset writer video input.====%@",_videoWriterInput);
        _videoWriterInput.expectsMediaDataInRealTime = YES;
//   _videoWriterInput.transform =[self transformFromCurrentVideoOrientationToOrientation:referenceOrientation andIsMirror:_isUsingFrontCamera];
    if ([_videoWriter canAddInput:_videoWriterInput])
        [_videoWriter addInput:_videoWriterInput];
        else {
            NSLog(@"Couldn't add asset writer video input.");
            return NO;
        }
    }
    else {
        NSLog(@"Couldn't apply video output settings.");
        return NO;
    }
    
    return YES;
}
#pragma mark 点击对焦
- (void)focusInPoint:(CGPoint)touchPoint
{
   CGPoint devicePoint = [self convertToPointOfInterestFromViewCoordinates:touchPoint];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = _VideoPreviewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.VideoPreviewLayer;//
    
    if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        
        for(AVCaptureInputPort *port in [videoInput ports]) {//正在使用的videoInput
            if([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if(point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
//    NSLog(@"focus point: %f %f", point.x, point.y);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVCaptureDevice *device = [videoInput device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            if ([device isFocusPointOfInterestSupported]) {
                [device setFocusPointOfInterest:point];
            }
            
            if ([device isFocusModeSupported:focusMode]) {
                [device setFocusMode:focusMode];
            }
            
            if ([device isExposurePointOfInterestSupported]) {
                [device setExposurePointOfInterest:point];
            }
            
            if ([device isExposureModeSupported:exposureMode]) {
                [device setExposureMode:exposureMode];
            }
            
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        } else {
            NSLog(@"对焦错误:%@", error);
        }
    });
}
#pragma mark 屏幕旋转
- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation andIsMirror:(BOOL)mirror
{
   CGAffineTransform transform = CGAffineTransformIdentity;
//    
//    // Calculate offsets from an arbitrary reference orientation (portrait)
//    CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
//    CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.videoOrientation];
//    
//    // Find the difference in angle between the passed in orientation and the current video orientation
//    CGFloat angleOffset = orientationAngleOffset-videoOrientationAngleOffset;
////    NSLog(@"angleOffset=%f",angleOffset);
//    transform = CGAffineTransformMakeRotation(angleOffset);
////    transform = CGAffineTransformScale(transform, 1, 2.0);
//    if ( _videoDevice.position == AVCaptureDevicePositionFront )//前置摄像头
//    {
//        if ( mirror ) {
//            transform = CGAffineTransformScale( transform, -1, 1 );
//        }
//        else {
//            if ( UIInterfaceOrientationIsPortrait( orientation ) ) {
//                transform = CGAffineTransformRotate( transform, M_PI );
//            }
//        }
//    }
//    transform  = CGAffineTransformScale(transform, 0.5, 0.5);
    transform = CGAffineTransformTranslate(transform,500, 500);
    return transform;
}
- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
    CGFloat angle = 0.0;
    
    switch (orientation) {
        case AVCaptureVideoOrientationPortrait:
            angle = 0.0;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            angle = -M_PI_2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
        default:
            break;
    }
    
    return angle;
}

-(NSString *)getVideoMergeFilePathString
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@"merge.mp4"];
    return fileName;
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"--captureOutput-%@",[NSThread currentThread]);
    if (_videoWriter==nil||_writingQueue==nil) {
        return;
    }
    @synchronized(self){
        CMFormatDescriptionRef formatDescription;
        formatDescription  = CMSampleBufferGetFormatDescription(sampleBuffer);
        CFRetain(sampleBuffer);
        CFRetain(formatDescription);
    dispatch_async(_writingQueue, ^{
        if ( _videoWriter ) {
            BOOL wasReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
               if (connection == _videoConnection) {
                if (!readyToRecordVideo)
                    readyToRecordVideo = [self setupAssetWriterVideoInput:formatDescription];
                if (readyToRecordVideo && readyToRecordAudio)
                    [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
                }
            else if (connection == _audioConnection) {
                if (!readyToRecordAudio)
                    readyToRecordAudio = [self setupAssetWriterAudioInput:formatDescription];
                if (readyToRecordAudio && readyToRecordVideo)
                    [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
            }
            BOOL isReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
            if ( !wasReadyToRecord && isReadyToRecord ) {

            }
        }
        CFRelease(sampleBuffer);
        CFRelease(formatDescription);
   });
}

}

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
int bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
#else
int bitmapInfo = kCGImageAlphaPremultipliedLast;
#endif
#pragma mark  ---获取帧图片------
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 得到pixel buffer的基地址
   void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    //NSLog(@"%zu,%zu",width,height);
    
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // 释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    
    return (image);
}

#pragma mark  -----获取裁剪的图片
/**
 * 计算裁剪图片的尺寸
 */
- (CGRect) calcRect:(CGSize)imageSize{
    NSLog(@"imageSize=%@",NSStringFromCGSize(imageSize));
    NSString* gravity = self.VideoPreviewLayer.videoGravity;
    self.cropRect = self.VideoPreviewLayer.frame;
    CGRect cropRect = self.cropRect;
    CGSize screenSize = self.VideoPreviewLayer.bounds.size;
    
    CGFloat screenRatio = screenSize.height / screenSize.width;
    CGFloat imageRatio = imageSize.height /imageSize.width;
    
    CGRect presentImageRect = self.VideoPreviewLayer.bounds;
    CGFloat scale = 1.0;
    
    
    if([AVLayerVideoGravityResizeAspect isEqual: gravity]){
        
        CGFloat presentImageWidth = imageSize.width;
        CGFloat presentImageHeigth = imageSize.height;
        if(screenRatio > imageRatio){
            presentImageWidth = screenSize.width;
            presentImageHeigth = presentImageWidth * imageRatio;
            
        }else{
            presentImageHeigth = screenSize.height;
            presentImageWidth = presentImageHeigth / imageRatio;
        }
        
        presentImageRect.size = CGSizeMake(presentImageWidth, presentImageHeigth);
        presentImageRect.origin = CGPointMake((screenSize.width-presentImageWidth)/2.0, (screenSize.height-presentImageHeigth)/2.0);
        
    }else if([AVLayerVideoGravityResizeAspectFill isEqual:gravity]){
        
        CGFloat presentImageWidth = imageSize.width;
        CGFloat presentImageHeigth = imageSize.height;
        if(screenRatio > imageRatio){
            presentImageHeigth = screenSize.height;
            presentImageWidth = presentImageHeigth / imageRatio;
        }else{
            presentImageWidth = screenSize.width;
            presentImageHeigth = presentImageWidth * imageRatio;
        }
        
        presentImageRect.size = CGSizeMake(presentImageWidth, presentImageHeigth);
        presentImageRect.origin = CGPointMake((screenSize.width-presentImageWidth)/2.0, (screenSize.height-presentImageHeigth)/2.0);
        
    }else{
        NSAssert1(0, @"dont support:%@",gravity);
    }
    
    scale = CGRectGetWidth(presentImageRect) / imageSize.width;
    
    CGRect rect = cropRect;
    rect.origin = CGPointMake(CGRectGetMinX(cropRect)-CGRectGetMinX(presentImageRect), CGRectGetMinY(cropRect)-CGRectGetMinY(presentImageRect));
    
    rect.origin.x /= scale;
    rect.origin.y /= scale;
    rect.size.width /= scale;
    rect.size.height  /= scale;
    
    return rect;
}
- (UIImage*) cropImageInRect:(UIImage*)aImage andRect:(CGRect)Rect{
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return [self getSubImage:Rect andImage:aImage];
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width,aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return  [self getSubImage:CGRectMake(0, 0, 320, 240) andImage:img];
}

//截取部分图像
-(UIImage*)getSubImage:(CGRect)rect andImage:(UIImage*)image
{
    CGImageRef subImageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
    CGRect smallBounds = CGRectMake(0, 0, CGImageGetWidth(subImageRef), CGImageGetHeight(subImageRef));
    printf("===%f,%f",smallBounds.size.width,smallBounds.size.height);
    UIGraphicsBeginImageContext(smallBounds.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context, smallBounds, subImageRef);
    UIImage* smallImage = [UIImage imageWithCGImage:subImageRef];
    UIGraphicsEndImageContext();
    
    return [self thumbnailWithImageWithoutScale:smallImage size:CGSizeMake(320, 240)];
}
//缩放图片
- (UIImage *)thumbnailWithImageWithoutScale:(UIImage *)image size:(CGSize)asize
{
    UIImage *newimage;
    if (nil == image) {
        newimage = nil;
    }
    else{
        CGSize oldsize = image.size;
        CGRect rect;
        if (asize.width/asize.height > oldsize.width/oldsize.height) {
            rect.size.width = asize.height*oldsize.width/oldsize.height;
            rect.size.height = asize.height;
            rect.origin.x = (asize.width - rect.size.width)/2;
            rect.origin.y = 0;
        }
        else{
            rect.size.width = asize.width;
            rect.size.height = asize.width*oldsize.height/oldsize.width;
            rect.origin.x = 0;
            rect.origin.y = (asize.height - rect.size.height)/2;
        }
        UIGraphicsBeginImageContext(asize);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [[UIColor clearColor] CGColor]);
        UIRectFill(CGRectMake(0, 0, asize.width, asize.height));//clear background
        [image drawInRect:rect];
        newimage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return newimage;
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
    if ( _videoWriter.status == AVAssetWriterStatusUnknown ) {
            if ([_videoWriter startWriting]) {
            NSLog(@"startWriting");
            [_videoWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        }
        else {
               NSLog(@"%@",_videoWriter.error);
        }
    }
    
    if ( _videoWriter.status == AVAssetWriterStatusWriting ) {
               if (mediaType == AVMediaTypeVideo) {
                    if (_videoWriterInput.readyForMoreMediaData) {
                    NSLog(@"--_videoWriterInput-%@",[NSThread currentThread]);
                        UIImage *fullImage = [self imageFromSampleBuffer:sampleBuffer];
                        CGRect rect = [self calcRect:fullImage.size];
                        UIImage *cropImage = [self cropImageInRect:fullImage andRect:rect];
                        CMSampleBufferRef  cropSamBuf = [self CMSampleBufferCreateCopyWithDeep:sampleBuffer exchangeImage:cropImage];
                           sampleBuffer = cropSamBuf;
                       if (![_videoWriterInput appendSampleBuffer:cropSamBuf]) {
                                NSLog(@"视频写入失败%@",_videoWriter.error);
                            }
                            else{
                                NSLog(@"视频写入成功");
                                _videoDataSuccess = YES;
                            }
                            CFRelease(cropSamBuf);
                }
        }
        else if (mediaType == AVMediaTypeAudio) {
            if (_audioWriterInput.readyForMoreMediaData) {
                NSLog(@"--_audioWriterInput-%@",[NSThread currentThread]);
                if (![_audioWriterInput appendSampleBuffer:sampleBuffer]) {
                   NSLog(@"音频写入失败＝%@",_videoWriter.error);
                }
                else{
                    NSLog(@"音频写入成功");
                   _audioDataSuccess = YES;
                }
            }
        }
    }
}
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
#define kCGImageAlphaPremultipliedLast  (kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast)
#else
#define kCGImageAlphaPremultipliedLast  kCGImageAlphaPremultipliedLast
#endif
//- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
//{
//    
//    CFDictionaryRef empty; // empty value for attr value.
//    CFMutableDictionaryRef attrs;
//    empty = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
//                               NULL,
//                               NULL,
//                               0,
//                               &kCFTypeDictionaryKeyCallBacks,
//                               &kCFTypeDictionaryValueCallBacks);
//    attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
//                                      1,
//                                      &kCFTypeDictionaryKeyCallBacks,
//                                      &kCFTypeDictionaryValueCallBacks);
//    
//    CFDictionarySetValue(attrs,
//                         kCVPixelBufferIOSurfacePropertiesKey,
//                         empty);
//    
//    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
//   
//    CVPixelBufferRef pxbuffer = NULL;
//    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
//                                          frameSize.height,  kCVPixelFormatType_32ARGB, attrs,
//                                          &pxbuffer);
//    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
//    
//    CVPixelBufferLockBaseAddress(pxbuffer, 0);
//    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
//    
//
//    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
//    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width,
//                                                 frameSize.height, 8, 4*frameSize.width, rgbColorSpace,
//                                                 1);
//    
//    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
//                                           CGImageGetHeight(image)), image);
//    CGColorSpaceRelease(rgbColorSpace);
//    CGContextRelease(context);
//    
//    CVPixelBufferUnlockBaseAddress(pxbuffer, 0); 
//    
//    return pxbuffer; 
//}

/**
 *  帧处理
 *  @return
 */

- (CMSampleBufferRef)CMSampleBufferCreateCopyWithDeep:(CMSampleBufferRef)sampleBuffer exchangeImage:(UIImage*)image
{
    CFDictionaryRef empty; // empty value for attr value.
    CFMutableDictionaryRef attrs;
    empty = CFDictionaryCreate(kCFAllocatorDefault, // our empty IOSurface properties dictionary
                               NULL,
                               NULL,
                               0,
                               &kCFTypeDictionaryKeyCallBacks,
                               &kCFTypeDictionaryValueCallBacks);
    attrs = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                      1,
                                      &kCFTypeDictionaryKeyCallBacks,
                                      &kCFTypeDictionaryValueCallBacks);
    
    CFDictionarySetValue(attrs,
                         kCVPixelBufferIOSurfacePropertiesKey,
                         empty);
    

    
    CGRect cropRect = CGRectMake(0, 0, 320, 240);
    
    CIImage *ciImage = [CIImage imageWithCGImage:image.CGImage]; //options: [NSDictionary dictionaryWithObjectsAndKeys:[NSNull null], kCIImageColorSpace, nil]];
    ciImage = [ciImage imageByCroppingToRect:cropRect];
    
    CVPixelBufferRef pixelBuffer;
    CVPixelBufferCreate(kCFAllocatorSystemDefault, 320, 240, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer);
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    
    CIContext * ciContext = [CIContext contextWithOptions: nil];
    [ciContext render:ciImage toCVPixelBuffer:pixelBuffer];
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
    CMSampleTimingInfo sampleTime = {
        .duration = CMSampleBufferGetDuration(sampleBuffer),
        .presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
        .decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
    };
    
    CMVideoFormatDescriptionRef videoInfo = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &videoInfo);
    
    CMSampleBufferRef oBuf;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &sampleTime, &oBuf);
    return oBuf;
}

- (BOOL)createVideoFolderIfNotExist
{
    NSString  *mainPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    NSString  *path =[mainPath stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSFileManager  *mgr = [NSFileManager defaultManager];
    BOOL isDir;
    BOOL isExist = [mgr fileExistsAtPath:path isDirectory:&isDir];
    if (!isExist) {
        BOOL isCreat = [mgr createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (!isCreat) {
         NSLog(@"创建文件夹失败");
            return NO;
        }
        return YES;
    }
    return YES;
}

#pragma mark 裁剪视频
-(void)videoClipFileUrl:(NSURL*)url
{
    AVAsset  *avasset = [AVAsset assetWithURL:url];
    CMTime    avssetTime = [avasset duration];//视频时长
    Float64   assetDurant = CMTimeGetSeconds(avssetTime);//转换
    NSLog(@"视频时长－－－%f",assetDurant);

    AVMutableComposition   *avMutableCompos = [AVMutableComposition composition];
    NSError  *error = nil;
    //视频
    AVMutableCompositionTrack  *videoTrack = [avMutableCompos addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [videoTrack insertTimeRange:CMTimeRangeFromTimeToTime(kCMTimeZero, avssetTime) ofTrack:[[avasset tracksWithMediaType:AVMediaTypeVideo]objectAtIndex:0] atTime:kCMTimeZero error:&error];
    //音频
    AVMutableCompositionTrack *auidoTrack = [avMutableCompos addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [auidoTrack insertTimeRange:CMTimeRangeFromTimeToTime(kCMTimeZero,avssetTime) ofTrack:[[avasset tracksWithMediaType:AVMediaTypeAudio]objectAtIndex:0]  atTime:kCMTimeZero error:&error];
    
    //固定方向
    CGSize  renderSize = CGSizeMake(videoTrack.naturalSize.height, videoTrack.naturalSize.width);
    
    CGAffineTransform layerTransform = CGAffineTransformMake(videoTrack.preferredTransform.a, videoTrack.preferredTransform.b, videoTrack.preferredTransform.c, videoTrack.preferredTransform.d, videoTrack.preferredTransform.tx , videoTrack.preferredTransform.ty);
    
    layerTransform = CGAffineTransformRotate(layerTransform,M_PI_2);
    CGAffineTransform offset = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height, 0);
 
    layerTransform = CGAffineTransformConcat(layerTransform,offset);
//        CGFloat  minH = renderSize.width/videoTrack.naturalSize.height;
//        CGFloat  minW = renderSize.height/videoTrack.naturalSize.width;
//    CGAffineTransform   scale = CGAffineTransformMakeScale(minH, minW);
//    layerTransform = CGAffineTransformConcat(layerTransform, scale);
//        layerTransform = CGAffineTransformScale(layerTransform,minW , minH);//放缩，解决前后摄像结果大小不对称
    AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
    [layerInstruciton setOpacity:0.0 atTime:CMTimeAdd(kCMTimeZero, avssetTime)];
    //导出
    AVMutableVideoCompositionInstruction  *mainInstruct = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruct.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(kCMTimeZero, avssetTime));
    mainInstruct.layerInstructions=[NSArray arrayWithObject:layerInstruciton];
    
    AVMutableVideoComposition  *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruct];
    mainCompositionInst.frameDuration = CMTimeMake(1, 25);
    mainCompositionInst.renderSize = renderSize;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    NSString *fileName = [nowTimeStr stringByAppendingString:@"merge.mp4"];
    NSURL*outputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), fileName]];
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:avMutableCompos presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition =  mainCompositionInst;
    exporter.outputURL =outputURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        if (exporter.status == AVAssetExportSessionStatusCompleted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if([_delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutPutFileAtURL:duration:andRotateAngle:error:)])//写入成功
                {
                    [_delegate videoRecorder:self didFinishRecordingToOutPutFileAtURL:outputURL duration:_currentTime andRotateAngle:_RotateAngle error:nil];
                }
            });
        }else{
            dispatch_async(dispatch_get_main_queue(), ^{
                if([_delegate respondsToSelector:@selector(videoRecorder:didFinishRecordingToOutPutFileAtURL:duration:andRotateAngle:error:)])//写入失败
                {
                    [_delegate videoRecorder:self didFinishRecordingToOutPutFileAtURL:outputURL duration:_currentTime andRotateAngle:_RotateAngle error:@"写入失败"];
                }
            });
         }
        }];
}

+ (void)setView:(UIView *)view toSizeWidth:(CGFloat)width
{
    CGRect frame = view.frame;
    frame.size.width = width;
    view.frame = frame;
}

+ (void)setView:(UIView *)view toOriginX:(CGFloat)x
{
    CGRect frame = view.frame;
    frame.origin.x = x;
    view.frame = frame;
}

+ (void)setView:(UIView *)view toOriginY:(CGFloat)y
{
    CGRect frame = view.frame;
    frame.origin.y = y;
    view.frame = frame;
}

+ (void)setView:(UIView *)view toOrigin:(CGPoint)origin
{
    CGRect frame = view.frame;
    frame.origin = origin;
    view.frame = frame;
}
-(void)dealloc
{
    if (self.countTimer) {
        [self.countTimer invalidate];
        self.countTimer  = nil;
        self.currentTime =0.0;
    }
    [_captureSession removeInput:videoInput];
    [_captureSession removeOutput:videoOutput];
    [_captureSession removeOutput:audioOutput];
    [_captureSession removeInput:_audioInput];
     [[NSNotificationCenter defaultCenter] removeObserver:self];
      NSLog(@"VideoRecord dealloc");
}


@end
