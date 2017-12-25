//
//  HDCallManager.m
//  HRTCDemo
//
//  Created by afanda on 7/26/17.
//  Copyright © 2017 easemob. All rights reserved.
//

#import "HDCallManager.h"
#import "HDMemberObject.h"
#import <AVFoundation/AVFoundation.h>
@interface HDCallManager ()

@end

@implementation HDCallManager
{
    NSMutableDictionary *_memberObjDic;
    BOOL _acceptTicket; //是否正在处理ticket
}
static HDCallManager *_manager = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[HDCallManager alloc] init];
    });
    return _manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _memberObjDic = [NSMutableDictionary dictionaryWithCapacity:0];
        HCallOptions *options = [[HCallOptions alloc] init];
        options.videoOff = NO;
        options.mute = NO;
        options.previewView = self.localView;
        [[HChatClient sharedClient].callManager setCallOptions:options];
        [[HChatClient sharedClient].callManager addDelegate:self delegateQueue:nil];
        _acceptTicket = NO;
    }
    return self;
}

- (HCallLocalView *)localView {
    if (_localView == nil) {
        _localView = [[HCallLocalView alloc] init];
    }
    return _localView;
}

- (void)exitSession {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_currentCallVC){
            [_currentCallVC dismissViewControllerAnimated:YES completion:nil];
            _currentCallVC = nil;
        }
    });
    _acceptTicket = NO;
    [_memberObjDic removeAllObjects];
}

- (void)acceptCallCompletion:(void (^)(id, HError *))completion {
    [[HChatClient sharedClient].callManager acceptCallCompletion:^(id obj, HError *error) {
        if (error == nil) {
            NSLog(@"Accepted.");
        }
    }];
}

- (void)acceptCallWithNickname:(NSString *)nickname completion:(void (^)(id, HError *))completion {
    [[HChatClient sharedClient].callManager acceptCallWithNickname:nickname completion:^(id obj, HError *error) {
        if (error == nil) {
            NSLog(@"Accepted.");
        }
    }];
}


- (void)onCallReceivedNickName:(NSString *)nickName {
    [self _playSoundAndVibration];
    [self _showNotificationWithNickName:nickName];
    HDCallViewController *callVC = [[HDCallViewController alloc] init];
    callVC.nickname = nickName;
    callVC.modalPresentationStyle = UIModalPresentationFullScreen;
    self.currentCallVC = callVC;
    [self.rootViewController presentViewController:self.currentCallVC animated:NO completion:nil];
}

- (void)onMemberJoin:(HCallMember *)member {
    NSLog(@"onMemberJoin:%@",member.memberName);
    HDMemberObject *item = [self getMemberObjWithMemberName:member.memberName];
    item.agentName = [member.extension objectForKey:@"nickname"];
    [_memberObjDic setObject:item forKey:member.memberName];
}

- (void)onMemberExit:(HCallMember *)member {
    HDMemberObject *item = [_memberObjDic objectForKey:member.memberName];
    [item.remoteVideoItem.backView removeFromSuperview];
    [_memberObjDic removeObjectForKey:member.memberName];
    [self reLayoutVideos];
}

- (void)onStreamAdd:(HCallStream *)stream {
    HDMemberObject *item = [self getMemberObjWithMemberName:stream.memberName];
    if (item == nil) {
        NSLog(@"Cannot more than three videos");
        return;
    }
    if (stream.streamType == HCallStreamTypeNormal) {
        item.normalStream = stream;
    } else {
        item.deskTopStream = stream;
    }
    [_memberObjDic setObject:item forKey:stream.memberName];
    [self subscribeStreamWithMemberObj:item];
    
}

/**
 视频流被移除[指其他人]
 */
- (void)onStreamRemove:(HCallStream *)stream {
    HDMemberObject *item = [_memberObjDic objectForKey:stream.memberName];
    if (stream.streamType == HCallStreamTypeNormal) {
        item.remoteVideoItem.normalView.hidden = YES;
        item.remoteVideoItem.deskTopView.hidden = YES;
    } else {
        item.remoteVideoItem.deskTopView.hidden = YES;
        item.remoteVideoItem.normalView.hidden =NO;
        item.deskTopStream = nil;
    }
}

//视频流刷新
- (void)onStreamUpdate:(HCallStream *)stream {
    //需要标记视频状态的话，可以在这里操作
}


/**
 视频结束
 1、网络原因
 2、其他平台登录
 3、被踢
 4、通话结束
 */
- (void)onCallEndReason:(int)reason desc:(NSString *)desc {
    NSString *tip = @"";
    switch (reason) {
        case HErrorCallReasonHangup: {
            tip = NSLocalizedString(@"video_other_side_has_hungup", @"The other side hung up the video call");
            break;
        }
        default:
            tip = NSLocalizedString(@"video_is_over", @"Video is over");
            break;
    }
    [_currentCallVC passiveCloseSessionTip:tip];
    [self exitSession];
}
    
-(void)onNotice:(HMediaNoticeCode)code arg1:(NSString *)arg1 arg2:(NSString *)arg2 arg3:(id)arg3{
    switch (code) {
        case HMediaNoticeOpenCameraFail:
            NSLog(@"HMediaNoticeOpenCameraFail");
        break;
        case HMediaNoticeOpenMicFail:
            NSLog(@"HMediaNoticeOpenMicFail");
        break;
        default:
            NSLog(@"onNotice:%d", code);
        break;
    }
    
}

#pragma mark - 用户交互

- (void)endCall {
    [self exitSession];
    [[HChatClient sharedClient].callManager endCall];
}

- (void)setSpeakEnable:(BOOL)enable {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    if (enable) {
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    }else {
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
    }
    [audioSession setActive:YES error:nil];
}

#pragma 不需要主动操作
- (void)subscribeStreamWithMemberObj:(HDMemberObject *)member {
    dispatch_async(dispatch_get_main_queue(), ^{
        HDCallRemoteView *topView;
        NSString * streamId = nil;
        if (member.deskTopStream!=nil) { //一个member有两个流
            topView = member.remoteVideoItem.deskTopView;
        }
        if (member.deskTopStream == nil && member.normalStream != nil) {
            member.remoteVideoItem.deskTopView.hidden = YES;
            topView = member.remoteVideoItem.normalView;
        }
        
        if (member.deskTopStream != nil) {
            streamId = member.deskTopStream.streamId;
        } else {
            streamId = member.normalStream.streamId;
        }
        
        [[HChatClient sharedClient].callManager subscribeStreamId:streamId view:topView completion:^(id obj, HError *error) {
            if (error == nil) {
                NSLog(@"Subscribe Success!->%@", streamId);
                topView.hidden = NO;
                if (member.deskTopStream != nil) {
                    member.remoteVideoItem.normalView.hidden = YES;
                }
                [member.remoteVideoItem.backView bringSubviewToFront:member.remoteVideoItem.backView.nameLabel];
                [_currentCallVC addStreamWithHDMemberObj:member];
            } else {
                NSLog(@"Subscribe Failed. error:%@",error.errorDescription);
            }
        }];
    });
    
}



#pragma mark - initData

- (HDMemberObject *)getMemberObjWithMemberName:(NSString *)memberName {
    HDMemberObject *item = [_memberObjDic objectForKey:memberName];
    if (item == nil) {
        if (_memberObjDic.count >= 3) { //主动控制的，可更改
            return nil;
        }
        item = [self newMemberObjWithMemberName:memberName];
    }
    return item;
}


- (HDMemberObject *)newMemberObjWithMemberName:(NSString *)memberName {
    NSInteger memberCount = _memberObjDic.count;
    CGFloat x=(memberCount+1)%2 * KWH;;
    CGFloat y=(memberCount+1)/2 * KWH;
    CGRect frame = CGRectMake(x, y, KWH, KWH);
    HDMemberObject *item = [[HDMemberObject alloc] initWithMemberName:memberName frame:frame target:self];
    [item setTapBlock:^(HVideoItem *videoItem) {
        videoItem.scaleMode = EMCallViewScaleModeAspectFit;
        [self bringBtnToFrontWithMemberObj:videoItem];
    }];
    return item;
}


- (void)bringBtnToFrontWithMemberObj:(HVideoItem *)item {
    [_currentCallVC showOneVideoBackView:item.backView];
}

- (void)restoreBtnClicked {
    [self reLayoutVideos];
}

- (void)reLayoutVideos {
    NSArray *arr = [_memberObjDic allValues];
    if (arr.count == 0) {
        return;
    }
    [_currentCallVC layoutVideosWithMembers:arr];
}

#pragma mark - private

- (NSString*)dictionaryToJson:(NSDictionary *)dic
{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)dictWithString:(NSString *)string
{
    if (string && 0 != string.length)
    {
        NSError *error;
        NSData *jsonData = [string dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        if (error)
        {
            NSLog(@"json解析失败：%@", error);
            return nil;
        }
        return jsonDict;
    }
    
    return nil;
}


//private
- (void)_playSoundAndVibration
{
    // 收到视频请求消息时，播放音频
    [[HDCDDeviceManager sharedInstance] playNewMessageSound];
    // 收到消息时，震动
    [[HDCDDeviceManager sharedInstance] playVibration];
}

- (void)_showNotificationWithNickName:(NSString *)from
{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        HPushOptions *options = [[HChatClient sharedClient] hPushOptions];
        //发送本地推送
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.fireDate = [NSDate date]; //触发通知的时间
        
        if (options.displayStyle == HPushDisplayStyleMessageSummary) {
            NSString *messageStr = @"邀请你进行视频通话";
            
            NSString *title = from;
            notification.alertBody = [NSString stringWithFormat:@"%@:%@", title, messageStr];
        }
        else{
            notification.alertBody = NSLocalizedString(@"receiveMessage", @"you have a new message");
        }
        notification.alertAction = NSLocalizedString(@"open", @"Open");
        notification.timeZone = [NSTimeZone defaultTimeZone];
        notification.soundName = UILocalNotificationDefaultSoundName;
        //发送通知
        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        NSInteger badge = [UIApplication sharedApplication].applicationIconBadgeNumber;
        
        [UIApplication sharedApplication].applicationIconBadgeNumber = ++badge;
    }
}


@end
