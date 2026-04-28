import router from '@ohos.router';
import {
  getTRTCShareInstance,
  destroyTRTCShareInstance,
  TRTCCloud,
  TRTCParams,
  TRTCCloudCallback,
  TRTCAppScene,
  TRTCRoleType,
  TRTCVideoStreamType
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

interface LiveRouterParams {
  userId: string;
  roomId: string;
}

class AnchorInfo {
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
struct LiveAudienceView {
  @State userId: string = '';
  @State roomId: string = '';
  @State anchors: AnchorInfo[] = [];
  @State isSpeakerOn: boolean = true;
  private trtc: TRTCCloud | null = null;

  private callback: TRTCCloudCallback = {
    onEnterRoom: (result: number) => {
      if (result > 0) {
        showToast('观众进房成功，耗时 ' + result + 'ms');
      } else {
        showToast('进房失败，错误码：' + result);
      }
    },
    onExitRoom: (reason: number) => {
      showToast('退房，reason=' + reason);
    },
    onRemoteUserEnterRoom: (userId: string) => {
      showToast('用户进房：' + userId);
      const index = this.anchors.findIndex(u => u.userId === userId);
      if (index === -1) {
        this.anchors = [...this.anchors, new AnchorInfo(userId)];
      }
    },
    onRemoteUserLeaveRoom: (userId: string, reason: number) => {
      showToast('用户退房：' + userId);
      const index = this.anchors.findIndex(u => u.userId === userId);
      if (index !== -1) {
        let arr = [...this.anchors];
        arr.splice(index, 1);
        this.anchors = arr;
      }
    },
    onUserVideoAvailable: (userId: string, available: number) => {
      const index = this.anchors.findIndex(u => u.userId === userId);
      if (index !== -1) {
        let arr = [...this.anchors];
        arr[index].isVideoAvailable = available !== 0;
        this.anchors = arr;

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
    this.enterRoom();
  }

  aboutToDisappear(): void {
    if (this.trtc) {
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

  private enterRoom(): void {
    this.trtc = getTRTCShareInstance(getContext());
    this.trtc.addCallback(this.callback);

    const info = genTestUserSig(this.userId);
    const params = new TRTCParams(
      info.sdkappid,
      this.userId,
      info.userSig,
      Number(this.roomId),
      '',
      TRTCRoleType.TRTCRoleAudience
    );
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneLIVE);
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
        Text('直播（观众）')
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

      // Remote anchor video(s)
      if (this.anchors.length > 0) {
        Stack() {
          // Show the first anchor's video as main view
          XComponent({
            id: this.anchors[0].viewId,
            type: XComponentType.SURFACE,
            libraryname: 'liteavsdk'
          })
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Black)
          Text(this.anchors[0].userId + '（主播）')
            .fontColor('#FFFFFF')
            .fontSize(12)
            .backgroundColor('#80000000')
            .padding(4)
            .borderRadius(4)
            .position({ x: 10, y: 10 })
        }
        .height('55%')
        .width('100%')
      } else {
        Column() {
          Text('等待主播开播...')
            .fontColor('#AAAAAA')
            .fontSize(18)
        }
        .height('55%')
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }

      // Control buttons
      Row({ space: 20 }) {
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
            Text('🚪')
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
