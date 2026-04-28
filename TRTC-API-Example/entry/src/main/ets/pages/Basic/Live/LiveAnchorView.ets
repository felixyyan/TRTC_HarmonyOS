import router from '@ohos.router';
import {
  getTRTCShareInstance,
  destroyTRTCShareInstance,
  TRTCCloud,
  TRTCParams,
  TRTCCloudCallback,
  TRTCAppScene,
  TRTCRoleType,
  TRTCAudioQuality,
  TRTCVideoStreamType
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { requestPermissions, showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

interface LiveRouterParams {
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
struct LiveAnchorView {
  @State userId: string = '';
  @State roomId: string = '';
  @State isVideoMuted: boolean = false;
  @State isAudioMuted: boolean = false;
  @State isFrontCamera: boolean = true;
  @State remoteUsers: RemoteUserInfo[] = [];
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'anchor_local_video';

  private callback: TRTCCloudCallback = {
    onEnterRoom: (result: number) => {
      if (result > 0) {
        showToast('主播进房成功，耗时 ' + result + 'ms');
      } else {
        showToast('进房失败，错误码：' + result);
      }
    },
    onExitRoom: (reason: number) => {
      showToast('退房，reason=' + reason);
    },
    onRemoteUserEnterRoom: (userId: string) => {
      showToast('用户进房：' + userId);
      const index = this.remoteUsers.findIndex(u => u.userId === userId);
      if (index === -1) {
        this.remoteUsers = [...this.remoteUsers, new RemoteUserInfo(userId)];
      }
    },
    onRemoteUserLeaveRoom: (userId: string, reason: number) => {
      showToast('用户退房：' + userId);
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
            arr[index].viewId);
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
    const params = router.getParams() as LiveRouterParams;
    if (params) {
      this.userId = params.userId;
      this.roomId = params.roomId;
    }
    this.startLive();
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

  private async startLive(): Promise<void> {
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
      TRTCRoleType.TRTCRoleAnchor
    );
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneLIVE);
    this.trtc.startLocalPreview(this.isFrontCamera, this.localViewId);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualityMusic);
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
        Text('直播（主播）')
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

      // Local preview (main area)
      Stack() {
        XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
          .width('100%')
          .height('100%')
          .backgroundColor(Color.Black)
        Text(this.userId + '（主播）')
          .fontColor('#FFFFFF')
          .fontSize(12)
          .backgroundColor('#80000000')
          .padding(4)
          .borderRadius(4)
          .position({ x: 10, y: 10 })

        // Remote user thumbnails (overlay at bottom)
        if (this.remoteUsers.length > 0) {
          Row({ space: 4 }) {
            ForEach(this.remoteUsers, (user: RemoteUserInfo) => {
              Stack() {
                XComponent({ id: user.viewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
                  .width(120)
                  .height(160)
                  .backgroundColor(Color.Black)
                Text(user.userId)
                  .fontColor('#FFFFFF')
                  .fontSize(10)
                  .backgroundColor('#80000000')
                  .padding(2)
                  .position({ x: 2, y: 2 })
              }
            }, (user: RemoteUserInfo) => user.userId)
          }
          .position({ x: 10, y: '70%' })
        }
      }
      .height('55%')
      .width('100%')

      // Control buttons
      Row({ space: 20 }) {
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
            this.trtc?.muteLocalVideo(this.isVideoMuted, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
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
          })

          Text('翻转')
            .fontColor('#FFFFFF')
            .fontSize(11)
        }

        Column({ space: 5 }) {
          Button({ type: ButtonType.Circle }) {
            Text('⏹')
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

          Text('停止直播')
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
