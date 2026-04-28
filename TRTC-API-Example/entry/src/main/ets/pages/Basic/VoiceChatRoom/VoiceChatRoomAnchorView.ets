import router from '@ohos.router';
import {
  getTRTCShareInstance,
  destroyTRTCShareInstance,
  TRTCCloud,
  TRTCParams,
  TRTCCloudCallback,
  TRTCAppScene,
  TRTCRoleType,
  TRTCAudioQuality
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { requestPermissions, showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

interface VoiceChatRouterParams {
  userId: string;
  roomId: string;
}

@Entry
@Component
struct VoiceChatRoomAnchorView {
  @State userId: string = '';
  @State roomId: string = '';
  @State isAudioMuted: boolean = false;
  @State isSpeakerOn: boolean = true;
  @State remoteUsers: string[] = [];
  private trtc: TRTCCloud | null = null;

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
      if (this.remoteUsers.indexOf(userId) === -1) {
        this.remoteUsers = [...this.remoteUsers, userId];
      }
    },
    onRemoteUserLeaveRoom: (userId: string, reason: number) => {
      showToast('用户退房：' + userId);
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
    const params = router.getParams() as VoiceChatRouterParams;
    if (params) {
      this.userId = params.userId;
      this.roomId = params.roomId;
    }
    this.startRoom();
  }

  aboutToDisappear(): void {
    if (this.trtc) {
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

  private async startRoom(): Promise<void> {
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
      TRTCRoleType.TRTCRoleAnchor
    );
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneLIVE);
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
        Text('语音聊天室（主播）')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      // Room info
      Text('房间号: ' + this.roomId)
        .fontColor('#AAAAAA')
        .fontSize(14)
        .width('100%')
        .padding({ left: 16 })

      // User list
      Column() {
        Text('房间内用户')
          .fontColor('#FFFFFF')
          .fontSize(16)
          .margin({ bottom: 10 })

        // Local user (anchor)
        Row({ space: 10 }) {
          Text('🎙')
            .fontSize(24)
          Column({ space: 2 }) {
            Text(this.userId)
              .fontColor('#FFFFFF')
              .fontSize(14)
            Text('主播（本地）')
              .fontColor('#00FF00')
              .fontSize(12)
          }
          Blank()
          Text(this.isAudioMuted ? '🔇' : '🔊')
            .fontSize(18)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#333333')
        .borderRadius(8)
        .margin({ bottom: 5 })

        // Remote users
        ForEach(this.remoteUsers, (user: string) => {
          Row({ space: 10 }) {
            Text('👤')
              .fontSize(24)
            Column({ space: 2 }) {
              Text(user)
                .fontColor('#FFFFFF')
                .fontSize(14)
              Text('远端用户')
                .fontColor('#AAAAAA')
                .fontSize(12)
            }
          }
          .width('100%')
          .padding(12)
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

          Text('结束')
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
