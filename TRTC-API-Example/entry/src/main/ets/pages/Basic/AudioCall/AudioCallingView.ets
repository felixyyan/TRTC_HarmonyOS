import router from '@ohos.router';
import {
  getTRTCShareInstance,
  destroyTRTCShareInstance,
  TRTCCloud,
  TRTCParams,
  TRTCCloudCallback,
  TRTCAppScene,
  TRTCAudioQuality
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { requestPermissions, showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

interface AudioCallRouterParams {
  userId: string;
  roomId: string;
}

@Entry
@Component
struct AudioCallingView {
  @State userId: string = '';
  @State roomId: string = '';
  @State isAudioMuted: boolean = false;
  @State isSpeakerOn: boolean = true;
  @State remoteUsers: string[] = [];
  private trtc: TRTCCloud | null = null;

  private callback: TRTCCloudCallback = {
    onEnterRoom: (result: number) => {
      if (result > 0) {
        showToast('进房成功，耗时 ' + result + 'ms');
        // 进房成功后申请后台运行，避免切后台后音频采集被系统挂起导致 crash
        BackgroundRunningHelper.start(['audioPlayback', 'audioRecording']);
      } else {
        showToast('进房失败，错误码：' + result);
      }
    },
    onExitRoom: (reason: number) => {
      showToast('退房，reason=' + reason);
      // 退房时同步释放后台任务
      BackgroundRunningHelper.stop();
    },
    onRemoteUserEnterRoom: (userId: string) => {
      showToast('远端用户进房：' + userId);
      if (this.remoteUsers.indexOf(userId) === -1) {
        this.remoteUsers = [...this.remoteUsers, userId];
      }
    },
    onRemoteUserLeaveRoom: (userId: string, reason: number) => {
      showToast('远端用户退房：' + userId);
      const index = this.remoteUsers.indexOf(userId);
      if (index !== -1) {
        let arr = [...this.remoteUsers];
        arr.splice(index, 1);
        this.remoteUsers = arr;
      }
    },
    onUserAudioAvailable: (userId: string, available: number) => {
      showToast(userId + (available ? ' 开启音频' : ' 关闭音频'));
    }
  };

  aboutToAppear(): void {
    const params = router.getParams() as AudioCallRouterParams;
    if (params) {
      this.userId = params.userId;
      this.roomId = params.roomId;
    }
    this.startCall();
  }

  aboutToDisappear(): void {
    if (this.trtc) {
      this.trtc.exitRoom();
      this.trtc.removeCallback(this.callback);
    }
    destroyTRTCShareInstance();
    // 兜底：确保后台任务一定被释放
    BackgroundRunningHelper.stop();
  }

  onBackPress(): boolean | void {
    if (this.trtc) {
      this.trtc.exitRoom();
    }
    BackgroundRunningHelper.stop();
  }

  private async startCall(): Promise<void> {
    const granted = await requestPermissions(['ohos.permission.MICROPHONE']);
    if (!granted) {
      showToast('麦克风权限未授权');
      return;
    }

    this.trtc = getTRTCShareInstance(getContext());
    this.trtc.addCallback(this.callback);

    const info = genTestUserSig(this.userId);
    const params = new TRTCParams(
      info.sdkappid,
      this.userId,
      info.userSig,
      Number(this.roomId),
      '',
      0
    );
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneAudioCall);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
  }

  build() {
    Column() {
      // Top bar
      Row() {
        Text('< ')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('语音通话')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.userId + ' - ' + this.roomId)
          .fontSize(14)
          .fontColor('#AAAAAA')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      // Remote user list
      Column() {
        Text('房间内用户')
          .fontColor('#FFFFFF')
          .fontSize(16)
          .margin({ bottom: 10 })

        Text(this.userId + '（本地）')
          .fontColor('#00FF00')
          .fontSize(14)
          .width('100%')
          .padding(8)
          .backgroundColor('#333333')
          .borderRadius(8)
          .margin({ bottom: 5 })

        ForEach(this.remoteUsers, (user: string) => {
          Text(user + '（远端）')
            .fontColor('#FFFFFF')
            .fontSize(14)
            .width('100%')
            .padding(8)
            .backgroundColor('#333333')
            .borderRadius(8)
            .margin({ bottom: 5 })
        }, (user: string) => user)
      }
      .width('100%')
      .layoutWeight(1)
      .padding(16)

      // Control buttons
      Row({ space: 20 }) {
        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text(this.isAudioMuted ? '🔇' : '🎤')
              .fontSize(24)
          }
          .width(60)
          .height(60)
          .backgroundColor(this.isAudioMuted ? '#FF4444' : '#444444')
          .onClick(() => {
            this.isAudioMuted = !this.isAudioMuted;
            this.trtc?.muteLocalAudio(this.isAudioMuted);
            showToast(this.isAudioMuted ? '已静音' : '已取消静音');
          })

          Text(this.isAudioMuted ? '已静音' : '麦克风')
            .fontColor('#FFFFFF')
            .fontSize(12)
        }

        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text(this.isSpeakerOn ? '🔊' : '🔈')
              .fontSize(24)
          }
          .width(60)
          .height(60)
          .backgroundColor('#444444')
          .onClick(() => {
            this.isSpeakerOn = !this.isSpeakerOn;
            const trtcDeviceManager = this.trtc?.getDeviceManager();
            trtcDeviceManager?.setAudioRoute(this.isSpeakerOn ? 0 : 1);
            showToast(this.isSpeakerOn ? '扬声器' : '听筒');
          })

          Text(this.isSpeakerOn ? '扬声器' : '听筒')
            .fontColor('#FFFFFF')
            .fontSize(12)
        }

        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text('📞')
              .fontSize(24)
          }
          .width(60)
          .height(60)
          .backgroundColor('#FF4444')
          .onClick(() => {
            this.trtc?.exitRoom();
            BackgroundRunningHelper.stop();
            router.back();
          })

          Text('挂断')
            .fontColor('#FFFFFF')
            .fontSize(12)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 40, top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1D1F')
  }
}
