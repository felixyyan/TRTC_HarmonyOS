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
import { showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct PushCDNAudienceView {
  @State userId: string = '';
  @State roomId: string = '';
  @State isInRoom: boolean = false;
  @State remoteUsers: string[] = [];
  private trtc: TRTCCloud | null = null;
  private remoteViewId: string = 'pushCDNAudienceRemoteView';

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>;
    if (params) {
      this.userId = params['userId'] ?? '';
      this.roomId = params['roomId'] ?? '';
    }
    this.enterRoom();
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('\u2190')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.isInRoom) {
              this.exitRoom();
            }
            router.back();
          })
        Text('CDN\u63a8\u6d41 - \u89c2\u4f17')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (this.isInRoom) {
        XComponent({ id: this.remoteViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
          .width('100%')
          .height(300)
          .backgroundColor('#000000')

        Text('用户: ' + this.userId + '  房间: ' + this.roomId)
          .fontSize(14)
          .fontColor('#CCCCCC')

        Text('角色: 观众 - 等待主播推流...')
          .fontSize(14)
          .fontColor('#FFAA00')

        if (this.remoteUsers.length > 0) {
          Text('远端用户: ' + this.remoteUsers.join(', '))
            .fontSize(14)
            .fontColor('#00FF00')
        }

        Button('退出房间')
          .width('80%')
          .height(44)
          .backgroundColor('#FF4444')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.exitRoom();
            router.back();
          })
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }

  private enterRoom() {
    this.trtc = getTRTCShareInstance(getContext());
    let info = genTestUserSig(this.userId);
    let params = new TRTCParams(
      info.sdkappid,
      this.userId,
      info.userSig,
      Number(this.roomId),
      '',
      TRTCRoleType.TRTCRoleAudience
    );
    let callback: TRTCCloudCallback = {
      onEnterRoom: (result: number) => {
        if (result > 0) {
          showToast('进房成功（观众）');
        } else {
          showToast('进房失败: ' + result);
          this.isInRoom = false;
        }
      },
      onRemoteUserEnterRoom: (userId: string) => {
        this.remoteUsers.push(userId);
        this.remoteUsers = [...this.remoteUsers];
      },
      onRemoteUserLeaveRoom: (userId: string, reason: number) => {
        this.remoteUsers = this.remoteUsers.filter(id => id !== userId);
      },
      onUserVideoAvailable: (userId: string, available: number) => {
        if (available !== 0) {
          showToast('主播开始推流');
        }
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneLIVE);
    this.isInRoom = true;
  }

  private exitRoom() {
    BackgroundRunningHelper.stop();
    this.trtc?.exitRoom();
    destroyTRTCShareInstance();
    this.trtc = null;
    this.isInRoom = false;
  }

  aboutToDisappear() {
    if (this.isInRoom) {
      this.exitRoom();
    }
  }

  onBackPress(): boolean | void {
    if (this.isInRoom) {
      this.exitRoom();
    }
  }
}
