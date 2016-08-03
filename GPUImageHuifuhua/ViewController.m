//
//  ViewController.m
//  GPUImageHuifuhua
//
//  Created by xwmedia01 on 16/8/3.
//  Copyright © 2016年 xwmedia01. All rights reserved.
//

#import "ViewController.h"
#import "GPUImage.h"
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController ()
{
    GPUImageMovie *_movieFile;
    GPUImageOutput<GPUImageInput> *_filter;
    GPUImageMovieWriter *_movieWriter;
}
@property (retain, nonatomic) GPUImageMovie *movieFile;
@property (retain, nonatomic) GPUImageOutput<GPUImageInput> *filter;
@property (retain, nonatomic) GPUImageMovieWriter *movieWriter;

@property (nonatomic) UILabel *progressLabel;
@property (nonatomic) NSTimer *timer;


@end

@implementation ViewController

@synthesize movieFile = _movieFile;
@synthesize filter = _filter;
@synthesize movieWriter = _movieWriter;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, 100)];
    _progressLabel.textColor = [UIColor blackColor];
    [self.view addSubview:_progressLabel];
    
    
    
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    
    NSURL *sampleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"150511_JiveBike" ofType:@"mov"]];
    
    //创建滤镜处理视频载体(GPUImageMovie)
    _movieFile = [[GPUImageMovie alloc] initWithURL:sampleURL];
    //runBenchmark--控制台打印current frame，就是视频处理到哪一秒了，只是一个控制台输出，YES就输出，NO就不输出
    _movieFile.runBenchmark = NO;
    
    //控制GPUImageView预览视频时的速度是否要保持真实的速度。如果设为NO，则会将视频的所有帧无间隔渲染，导致速度非常快。设为YES，则会根据视频本身时长计算出每帧的时间间隔，然后每渲染一帧，就sleep一个时间间隔，从而达到正常的播放速度。
    _movieFile.playAtActualSpeed = NO;
    
    
    //创建视频过滤器 也就是视频要处理成什么样式(例如：灰度化)
    _filter = [[GPUImageGrayscaleFilter alloc] init];
    //放入视频处理器载体中 等待处理
    [_movieFile addTarget:_filter];
    
    
    NSString *pathToTempMov = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempMovie.mov"];
    
    //unlink 是C语言中函数，简单的说就是如果本地存在改路径指定的文件，就会删除重置文件中的内容
    unlink([pathToTempMov UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
    
    //获取视频的实际size大小，也就是视频尺寸
    NSURL *outputTempMovieURL = [NSURL fileURLWithPath:pathToTempMov];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sampleURL options:nil];
    NSArray *assetVideoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (assetVideoTracks.count <= 0)
    {
        NSLog(@"Video track is empty!");
        return;
    }
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    // If this if from system camera, it will rotate 90c, and swap width and height
    CGSize sizeVideo = CGSizeMake(videoAssetTrack.naturalSize.width, videoAssetTrack.naturalSize.height);
    
    
    
    //有了载体就要开始输出了使用 （GPUImageMovieWriter）,第一个参数是原视频url，第二个参数是要输入的视频尺寸大小
    _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:outputTempMovieURL size:sizeVideo];
    if ((NSNull*)_filter != [NSNull null] && _filter != nil)
    {
        //滤镜上(GPUImageGrayscaleFilter)添加写入者（GPUImageMovieWriter）
        [_filter addTarget:_movieWriter];
    }
    else
    {
        //原视频载体(GPUImageMovie)上添加写入者（GPUImageMovieWriter）
        [_movieFile addTarget:_movieWriter];
    }
    
    
    // 4. Configure this for video from the movie file, where we want to preserve all video frames and audio samples
    //是否允许视频声音通过
    _movieWriter.shouldPassthroughAudio = YES;
    //如果允许视频声音通过，设置声音源
    _movieFile.audioEncodingTarget = _movieWriter;
    
    //保存所有的视频帧和音频样本(异步保证不丢音频)
    [_movieFile enableSynchronizedEncodingUsingMovieWriter:_movieWriter];
    
    // 5.
    //写入者开始录制
    [_movieWriter startRecording];
    
    ////视频载体开始处理(可以理解为开始播放，就是写入者开始录制，视频载体本身开始播放，这样就把每一帧都拍下来了)
    [_movieFile startProcessing];
    
    
    
    //GPUImageMovieWriter录制成功回调
    __block ViewController *ws = self;
    [ws.movieWriter setCompletionBlock:^{
        
    _progressLabel.text = @"100%";
        
        //
        if ((NSNull*)_filter != [NSNull null] && _filter != nil)
        {
            //移除写入者从滤镜中
            [_filter removeTarget:_movieWriter];
        }
        else
        {
            //移除写入者从视频载体中(主要是为了节省资源吧)
            [_movieFile removeTarget:_movieWriter];
        }
        
        //录制完毕要关闭录制动作
        [_movieWriter finishRecordingWithCompletionHandler:^{

            
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            [library writeVideoAtPathToSavedPhotosAlbum:outputTempMovieURL
                                        completionBlock:^(NSURL *assetURL, NSError *error) {
                                            if (error) {
                                                NSLog(@"Save video fail:%@",error);
                                            } else {
                                                NSLog(@"Save video succeed.");
                                               
            
                                               
                                                
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    [_timer invalidate];
                                                    _timer = nil;
                                                     _progressLabel.text = @"成功保存到相册";
                                                });
                                                
                                            }
                                        }];
        }];
        
    }];
    
    //GPUImageMovieWriter录制失败回调
    [_movieWriter setFailureBlock:^(NSError *error) {
        NSLog(@"%@", [error description]);
    }];

    
}

- (void)updateProgress
{
    NSLog(@"========");
    if (_movieFile.progress >=1) {
        [_timer invalidate];
        _timer = nil;
        return;
        
    }
    
    _progressLabel.text = [NSString stringWithFormat:@"进度%.2f %%",_movieFile.progress];
   
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
