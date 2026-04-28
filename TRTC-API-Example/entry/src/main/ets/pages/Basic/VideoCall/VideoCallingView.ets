import router from '@ohos.router';
import {
  getTRTCShareInstance,
  destroyTRTCShareInstance,
  TRTCCloud,
  TRTCParams,
  TRTCCloudCallback,
  TRTCAppScene,
  TRTCAudioQuality,
  TRTCVideoEncParam,
  TRTCVideoResolution,
  TRTCVideoResolutionMode,
  TRTCVideoStreamType
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { requestPermissions, showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

interface VideoCallRouterParams {
  userId: string;
  roomId: string;
}

class RemoteUserInfo {
  userId: string;
  viewId: string;
  isVideoAvailable: boolean = false;

  constructor(userId: string) {
    this.userId = userId;
    this.viewId = userId + '#MainStream';
  }
}

@Entry
@Component
struct VideoCallingView {
  @State userId: string = '';
  @State roomId: string = '';
  @State isVideoMuted: boolean = false;
  @State isAudioMuted: boolean = false;
  @State isFrontCamera: boolean = true;
  @State isSpeakerOn: boolean = true;
  @State remoteUsers: RemoteUserInfo[] = [];
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'local_video_view';

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
      const index = this.remoteUsers.findIndex(u => u.userId === userId);
      if (index === -1) {
        this.remoteUsers = [...this.remoteUsers, new RemoteUserInfo(userId)];
      }
    },
    onRemoteUserLeaveRoom: (userId: string, reason: number) => {
      showToast('远端用户退房：' + userId);
      const index = this.remoteUsers.findIndex(u => u.userId === userId);
      if (index !== -1) {
        let arr = [...this.remoteUsers];
        arr.splice(index, 1);
        this.remoteUsers = arr;
      }
    },
    onUserVideoAvailable: (userId: string, available: number) => {
      const index = this.remoteUsers.findIndex(u => u.userId === userId);
      if (index !== -1) {
        let arr = [...this.remoteUsers];
        arr[index].isVideoAvailable = available !== 0;
        this.remoteUsers = arr;

        if (available) {
          this.trtc?.startRemoteView(userId, TRTCVideoStreamType.TRTCVideoStreamTypeBig,
            this.remoteUsers[index].viewId);
        } else {
          this.trtc?.stopRemoteView(userId, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
        }
      }
    },
    onUserAudioAvailable: (userId: string, available: number) => {
      showToast(userId + (available ? ' 开启音频' : ' 关闭音频'));
    }
  };

  aboutToAppear(): void {
    const params = router.getParams() as VideoCallRouterParams;
    if (params) {
      this.userId = params.userId;
      this.roomId = params.roomId;
    }
    this.startCall();
  }

  aboutToDisappear(): void {
    if (this.trtc) {
      this.trtc.stopLocalPreview();
      this.trtc.stopLocalAudio();
      BackgroundRunningHelper.stop();
      this.trtc.exitRoom();
      this.trtc.removeCallback(this.callback);
    }
    destroyTRTCShareInstance();
  }

  onBackPress(): boolean | void {
    if (this.trtc) {
      BackgroundRunningHelper.stop();
      this.trtc.exitRoom();
    }
  }

  private async startCall(): Promise<void> {
    const granted = await requestPermissions(['ohos.permission.CAMERA', 'ohos.permission.MICROPHONE']);
    if (!granted) {
      showToast('相机或麦克风权限未授权');
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
      20
    );
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);
    this.trtc.startLocalPreview(this.isFrontCamera, this.localViewId);
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
        Text('视频通话')
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

      // Video area
      Grid() {
        // Local video
        GridItem() {
          Stack() {
            XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
              .width('100%')
              .height('100%')
              .backgroundColor(Color.Black)
            Text(this.userId + '（本地）')
              .fontColor('#FFFFFF')
              .fontSize(12)
              .backgroundColor('#80000000')
              .padding(4)
              .borderRadius(4)
              .position({ x: 5, y: 5 })
          }
          .width('100%')
          .height('100%')
        }

        // Remote videos
        ForEach(this.remoteUsers, (user: RemoteUserInfo) => {
          GridItem() {
            Stack() {
              XComponent({ id: user.viewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
                .width('100%')
                .height('100%')
                .backgroundColor(Color.Black)
              Text(user.userId + '（远端）')
                .fontColor('#FFFFFF')
                .fontSize(12)
                .backgroundColor('#80000000')
                .padding(4)
                .borderRadius(4)
                .position({ x: 5, y: 5 })
            }
            .width('100%')
            .height('100%')
          }
        }, (user: RemoteUserInfo) => user.userId)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(2)
      .rowsGap(2)
      .height('55%')
      .width('100%')
      .padding(4)

      // Control buttons
      Row({ space: 15 }) {
        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text(this.isVideoMuted ? '📷' : '🎥')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .backgroundColor(this.isVideoMuted ? '#FF4444' : '#444444')
          .onClick(() => {
            this.isVideoMuted = !this.isVideoMuted;
            if (this.isVideoMuted) {
              // 关视频：暂停推流 + 停止摄像头（保护隐私）
              this.trtc?.muteLocalVideo(true, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
              this.trtc?.stopLocalPreview();
            } else {
              // 开视频：恢复推流 + 重新开启摄像头预览
              this.trtc?.startLocalPreview(this.isFrontCamera, this.localViewId);
              this.trtc?.muteLocalVideo(false, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
            }
            showToast(this.isVideoMuted ? '已关闭视频' : '已开启视频');
          })

          Text(this.isVideoMuted ? '视频关' : '视频开')
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
            Text('🔄')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .backgroundColor('#444444')
          .onClick(() => {
            this.isFrontCamera = !this.isFrontCamera;
            const deviceManager = this.trtc?.getDeviceManager();
            deviceManager?.switchCamera(this.isFrontCamera);
            showToast(this.isFrontCamera ? '前置摄像头' : '后置摄像头');
          })

          Text('翻转')
            .fontColor('#FFFFFF')
            .fontSize(11)
        }

        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text(this.isSpeakerOn ? '🔊' : '🔈')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .backgroundColor('#444444')
          .onClick(() => {
            this.isSpeakerOn = !this.isSpeakerOn;
            const deviceManager = this.trtc?.getDeviceManager();
            deviceManager?.setAudioRoute(this.isSpeakerOn ? 0 : 1);
            showToast(this.isSpeakerOn ? '扬声器' : '听筒');
          })

          Text(this.isSpeakerOn ? '扬声器' : '听筒')
            .fontColor('#FFFFFF')
            .fontSize(11)
        }

        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text('📞')
              .fontSize(20)
          }
          .width(56)
          .height(56)
          .backgroundColor('#FF4444')
          .onClick(() => {
            BackgroundRunningHelper.stop();
            this.trtc?.exitRoom();
            router.back();
          })

          Text('挂断')
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
