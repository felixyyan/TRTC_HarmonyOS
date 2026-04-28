import router from '@ohos.router';
import {
  getTRTCShareInstance,
  destroyTRTCShareInstance,
  TRTCCloud,
  TRTCParams,
  TRTCCloudCallback,
  TRTCAppScene,
  TRTCAudioQuality,
  TRTCVideoStreamType,
  TRTCVideoEncParam,
  TRTCVideoResolution,
  TRTCVideoResolutionMode
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { requestPermissions, showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

interface ScreenShareRouterParams {
  userId: string;
  roomId: string;
}

@Entry
@Component
struct ScreenShareView {
  @State userId: string = '';
  @State roomId: string = '';
  @State isScreenSharing: boolean = false;
  @State isAudioMuted: boolean = false;
  @State remoteUsers: string[] = [];
  private trtc: TRTCCloud | null = null;

  private callback: TRTCCloudCallback = {
    onEnterRoom: (result: number) => {
      if (result > 0) {
        showToast('进房成功，耗时 ' + result + 'ms');
      } else {
        showToast('进房失败，错误码：' + result);
      }
    },
    onExitRoom: (reason: number) => {
      showToast('退房，reason=' + reason);
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
    },
    onUserSubStreamAvailable: (userId: string, available: number) => {
      showToast(userId + (available ? ' 开启屏幕分享' : ' 关闭屏幕分享'));
    }
  };

  aboutToAppear(): void {
    const params = router.getParams() as ScreenShareRouterParams;
    if (params) {
      this.userId = params.userId;
      this.roomId = params.roomId;
    }
    this.enterRoom();
  }

  aboutToDisappear(): void {
    if (this.isScreenSharing) {
      this.trtc?.stopScreenCapture();
    }
    if (this.trtc) {
      this.trtc.stopLocalAudio();
      BackgroundRunningHelper.stop();
      this.trtc.exitRoom();
      this.trtc.removeCallback(this.callback);
    }
    destroyTRTCShareInstance();
  }

  onBackPress(): boolean | void {
    if (this.isScreenSharing) {
      this.trtc?.stopScreenCapture();
    }
    if (this.trtc) {
      BackgroundRunningHelper.stop();
      this.trtc.exitRoom();
    }
  }

  private async enterRoom(): Promise<void> {
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
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneLIVE);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
  }

  private startScreenShare(): void {
    if (!this.trtc) {
      return;
    }

    const encParam = new TRTCVideoEncParam(
      TRTCVideoResolution.TRTCVideoResolution_1280_720,
      TRTCVideoResolutionMode.TRTCVideoResolutionModeLandscape,
      15,
      1600,
      0,
      true
    );
    this.trtc.startScreenCapture(TRTCVideoStreamType.TRTCVideoStreamTypeBig, encParam);
    this.isScreenSharing = true;
    showToast('开始录屏');
  }

  private stopScreenShare(): void {
    if (!this.trtc) {
      return;
    }

    this.trtc.stopScreenCapture();
    this.isScreenSharing = false;
    showToast('停止录屏');
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
        Text('录屏直播')
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

      // Status area
      Column({ space: 15 }) {
        // Screen share status
        Column({ space: 10 }) {
          Text(this.isScreenSharing ? '📺 正在录屏直播中...' : '📺 录屏未开始')
            .fontColor(this.isScreenSharing ? '#00FF00' : '#AAAAAA')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)

          if (this.isScreenSharing) {
            Text('屏幕内容正在分享给房间内的用户')
              .fontColor('#AAAAAA')
              .fontSize(14)
          } else {
            Text('点击下方按钮开始录屏分享')
              .fontColor('#AAAAAA')
              .fontSize(14)
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#333333')
        .borderRadius(12)
        .alignItems(HorizontalAlign.Center)

        // User list
        Column({ space: 5 }) {
          Text('房间内用户')
            .fontColor('#FFFFFF')
            .fontSize(16)
            .margin({ bottom: 5 })

          Text(this.userId + '（本地）')
            .fontColor('#00FF00')
            .fontSize(14)
            .width('100%')
            .padding(10)
            .backgroundColor('#333333')
            .borderRadius(8)

          ForEach(this.remoteUsers, (user: string) => {
            Text(user + '（远端）')
              .fontColor('#FFFFFF')
              .fontSize(14)
              .width('100%')
              .padding(10)
              .backgroundColor('#333333')
              .borderRadius(8)
          }, (user: string) => user)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .padding(16)

      // Control buttons
      Row({ space: 20 }) {
        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text(this.isScreenSharing ? '⏹' : '🖥')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .backgroundColor(this.isScreenSharing ? '#FF4444' : '#007AFF')
          .onClick(() => {
            if (this.isScreenSharing) {
              this.stopScreenShare();
            } else {
              this.startScreenShare();
            }
          })

          Text(this.isScreenSharing ? '停止录屏' : '开始录屏')
            .fontColor('#FFFFFF')
            .fontSize(11)
        }

        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text(this.isAudioMuted ? '🔇' : '🎤')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .backgroundColor(this.isAudioMuted ? '#FF4444' : '#444444')
          .onClick(() => {
            this.isAudioMuted = !this.isAudioMuted;
            this.trtc?.muteLocalAudio(this.isAudioMuted);
            showToast(this.isAudioMuted ? '已静音' : '已取消静音');
          })

          Text(this.isAudioMuted ? '已静音' : '麦克风')
            .fontColor('#FFFFFF')
            .fontSize(11)
        }

        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text('🚪')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .backgroundColor('#FF4444')
          .onClick(() => {
            if (this.isScreenSharing) {
              this.trtc?.stopScreenCapture();
            }
            BackgroundRunningHelper.stop();
            this.trtc?.exitRoom();
            router.back();
          })

          Text('退出')
            .fontColor('#FFFFFF')
            .fontSize(11)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 30, top: 15 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1D1F')
  }
}
