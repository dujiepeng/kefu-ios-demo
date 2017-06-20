//
//  HCallViewController.m
//  CustomerSystem-ios
//
//  Created by __阿彤木_ on 3/20/17.
//  Copyright © 2017 easemob. All rights reserved.
//

#import "HCallViewController.h"
#import "HCallManager.h"
#import "AppDelegate.h"

typedef NS_ENUM(NSUInteger, BottomMenuTag) {
    BottomMenuTagSwitchCamera = 100,
    BottomMenuTagSwitchMic,
    BottomMenuTagSwitchHorn,
    BottomMenuTagSwitchVideo
};

typedef NS_ENUM(NSUInteger, DeviceOrientation) {
    DeviceOrientationCustom=124,
    DeviceOrientationLR,
};

@interface HCallViewController ()
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;    //客服昵称
@property (weak, nonatomic) IBOutlet UILabel *remindLabel;      //给访客的提醒
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;        //计时
@property (weak, nonatomic) IBOutlet UIButton *switchButton;    //镜头转换
@property (weak, nonatomic) IBOutlet UIButton *micButton;       //麦克开关
@property (weak, nonatomic) IBOutlet UIButton *voiceButton;     //喇叭开关

@property (weak, nonatomic) IBOutlet UIButton *videoButton;     //视频开关
@property (weak, nonatomic) IBOutlet UIButton *hangupButton; //主动挂断

@property (weak, nonatomic) IBOutlet UIButton *rejectButton;    //拒绝请求
@property (weak, nonatomic) IBOutlet UIButton *acceptButton;    //接受请求

@property (nonatomic) int timeLength;
@property (strong, nonatomic) NSTimer *timeTimer;

@end

@implementation HCallViewController
{
    HCall *_callManager;
    AppDelegate *_appDelegate;
    DeviceOrientation _currentOrientation;
    BOOL _videoing;
}


- (instancetype)initWithCallSession:(HCallSession *)aCallSession {
    NSString *xibName = @"HCallViewController";
    self = [super initWithNibName:xibName bundle:nil];
    if (self) {
        _callManager = [HChatClient sharedClient].call;
        _callSession = aCallSession;
        _isDismissing = NO;
        _hangupButton.hidden = YES;
    }
    
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _currentOrientation = DeviceOrientationCustom;
    _appDelegate  = (AppDelegate *)[UIApplication sharedApplication].delegate;
    _appDelegate.allowRotation = YES;
    [self addNoti];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _appDelegate.allowRotation = NO;
    [self removeNoti];
}

- (void)addNoti {
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeOrientation) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)removeNoti {
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.isDismissing) {
        return;
    }
    [self setup];
}
- (void)setup {
    [self.rejectButton setTitle:NSLocalizedString(@"reject", @"Reject") forState:UIControlStateNormal];
    [self.acceptButton setTitle:NSLocalizedString(@"accept", @"Accept") forState:UIControlStateNormal];
    [self.hangupButton setTitle:NSLocalizedString(@"video_call_hang_up", @"Hang Up") forState:UIControlStateNormal];

    
    self.nickNameLabel.text = NSLocalizedString(@"easemob_cs_title", @"EasemobMall Customer Service");
    switch (self.callSession.type) {
        case HCallTypeVoice: {
            self.videoButton.enabled = NO;
            break;
        }
        case HCallTypeVideo: {
            break;
        }
        default:
            break;
    }
}

//镜头转换、麦克风开关、喇叭开关、视频开关{tag:100、101、102、103}
- (IBAction)BottomMenuClicked:(id)sender {
    UIButton *btn = sender;
    btn.selected = !btn.selected;
    BottomMenuTag menuTag = btn.tag;
    switch (menuTag) {
        case BottomMenuTagSwitchCamera:{ //切换前后镜头
            [self.callSession switchCameraPosition:!self.switchButton.selected];
            break;
        }
        case BottomMenuTagSwitchMic: { //开关麦克风
            if (self.micButton.selected) {
                [self.callSession pauseVoice];
            } else {
                [self.callSession resumeVoice];
            }
            break;
        }
        case BottomMenuTagSwitchHorn: { //开关喇叭
            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
            [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
            if (self.voiceButton.selected) {
                [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
            }else {
                [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
            }
            [audioSession setActive:YES error:nil];
            break;
        }
        case BottomMenuTagSwitchVideo: { //开关视频
            if (self.videoButton.selected) {
                [self.callSession pauseVideo];
            } else {
                [self.callSession resumeVideo];
            }
            break;
        }
        default:
            break;
    }
    
}

//扬声器模式
-(void)setAudioSessionSpeaker
{
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    //设置为播放
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
}

//主动挂断视频通话
- (IBAction)hangupCilcked:(id)sender {
    [_callManager endCall:self.callSession.callId reason:HCallEndReasonHangup];
}

//拒绝客服视频请求
- (IBAction)rejectCallRequest:(id)sender {
    [_callManager endCall:self.callSession.callId reason:HCallEndReasonDecline];
}

//接受客服视频请求
- (IBAction)acceptCallRequest:(id)sender {
    self.timeLabel.hidden = YES;
    self.timeLabel.text = @"";
    [[HCallManager sharedInstance] answerCall:self.callSession.callId];
}

//通道已经建立
- (void)stateToConnected {
    self.timeLabel.numberOfLines = 2;
    self.timeLabel.text = self.callSession.remoteName;
    NSLog(@"name--%@", self.callSession.remoteName);
    [self setupRemoteVideoView];
    [self setupLocalVideoView];
    
    [self remindVisitor:NSLocalizedString(@"have_connected_with", @"Invite customer service making a video call")];
   
}
//视频已经连通 
- (void)didConnected {
    NSLog(@"视频已经联通");
    self.timeLabel.hidden = NO;
    
    if (self.timeLength <= 0) {
        [self startRecordTime];
    }
    
    self.hangupButton.hidden = NO;
    [self setAudioSessionSpeaker];
    [self remindVisitor:NSLocalizedString(@"In_the_call", @"In the call..")];
}


//设置客服视频窗口
- (void)setupRemoteVideoView
{
    CGRect frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    if (self.callSession.remoteVideoView != nil) {
        self.callSession.remoteVideoView.frame = frame;
    } else {
        self.callSession.remoteVideoView = [[HCallRemoteView alloc] initWithFrame:frame];
    }
    self.callSession.remoteVideoView.hidden = YES;
    self.callSession.remoteVideoView.backgroundColor = [UIColor clearColor];
    self.callSession.remoteVideoView.scaleMode = HCallViewScaleModeAspectFit;
    [self.view addSubview:self.callSession.remoteVideoView];
    [self.view sendSubviewToBack:self.callSession.remoteVideoView];
    
    __weak HCallViewController *weakSelf = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        weakSelf.callSession.remoteVideoView.hidden = NO;
    });
}

//设置本地视频窗口
- (void)setupLocalVideoView
{
    CGFloat w =  80;
    CGFloat h = kScreenHeight / kScreenWidth * w;
    CGRect frame = CGRectMake(kScreenWidth - w -20, 20, w, h);
    if (_currentOrientation == DeviceOrientationLR) {
        h = kScreenWidth/kScreenHeight * w;
        frame = CGRectMake(20, kScreenHeight - 20 - w, h, w);
    }
    if (self.callSession.localVideoView != nil) {
        self.callSession.localVideoView.frame = frame;
    } else {
        self.callSession.localVideoView = [[HCallLocalView alloc] initWithFrame:frame];
    }
    [self.view addSubview:self.callSession.localVideoView];
    [self.view bringSubviewToFront:self.callSession.localVideoView];
}

//开始计时
- (void)startRecordTime
{
    self.timeLength = 0;
    self.timeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timeTimerAction:) userInfo:nil repeats:YES];
}

- (void)timeTimerAction:(id)sender
{
    _timeLength += 1;
    int hour = _timeLength / 3600;
    int m = (_timeLength - hour * 3600) / 60;
    int s = _timeLength - hour * 3600 - m * 60;
    
    if (hour > 0) {
        _timeLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", hour, m, s];
    } else {
        _timeLabel.text = [NSString stringWithFormat:@"%02d:%02d", m, s];
    }
}

//数据传输状态改变
- (void)setStatusWithStatus:(HCallStreamingStatus)status {
    NSString *remind = @"";
    switch (status) {
        case HCallStreamStatusVoicePause: { //语音中断
            remind = NSLocalizedString(@"the_voiceof_the_service_was_suspended", @"The voice of the service was suspended...");
            break;
        }
        case HCallStreamStatusVoiceResume: { //语音重连
            remind = NSLocalizedString(@"the_voice_of_the_service_has_been_reconnection", @"The voice of the service has been reconnection");
            break;
        }
        case HCallStreamStatusVideoPause: { //视频中断
            remind = NSLocalizedString(@"the_video_of_the_service_was_suspended", @"The video of the service was suspended...");
            break;
        }
        case HCallStreamStatusVideoResume: { //视频重连
            remind = NSLocalizedString(@"the_video_of_the_service_has_been_reconnection", @"The video of the service has been reconnection");
            break;
        }
        default:
            break;
    }
    [self remindVisitor:remind];
}

//网络状态改变
- (void)setNetworkWithNetworkStatus:(HCallNetworkStatus)status {
    NSString *remind = @"";
    switch (status) {
        case HCallNetworkStatusNormal: { //网络正常
            remind = NSLocalizedString(@"are_making_video_calls_and_customer_service", @"Are making video calls and customer service");
            break;
        }
        case HCallNetworkStatusUnstable: { //网络不稳定
            remind = NSLocalizedString(@"the_current_network_is_not_stable", @"The current network is not stable");
            break;
        }
        case HCallNetworkStatusNoData: { //网络连接中断
            remind = NSLocalizedString(@"the_current_network_has_been_interrupted", @"The current network has been interrupted");
            break;
        }
        default:
            break;
    }
    [self remindVisitor:remind];
}

- (void)clearData {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    [audioSession setActive:YES error:nil];
    
    self.callSession.remoteVideoView.hidden = YES;
    self.callSession.remoteVideoView = nil;
    _callSession = nil;
    
    [self stopTimeTimer];
}


//private
- (void)remindVisitor:(NSString *)remind {
    self.remindLabel.numberOfLines = 3;
    NSLog(@"提示语：%@",remind);
    self.remindLabel.text = remind;
}

- (void)stopTimeTimer
{
    if (self.timeTimer) {
        [self.timeTimer invalidate];
        self.timeTimer = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)changeOrientation {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if(orientation==UIDeviceOrientationFaceUp || orientation==UIDeviceOrientationFaceDown
       || orientation == UIDeviceOrientationPortraitUpsideDown)
        return;
    
    switch (orientation) {
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
        {
            _currentOrientation = DeviceOrientationLR;
            break;
        }
        default:
            _currentOrientation = DeviceOrientationCustom;
            break;
    }
    [self refreshVideoView];
}
- (void)refreshVideoView {
    [self setupRemoteVideoView];
    [self setupLocalVideoView];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
