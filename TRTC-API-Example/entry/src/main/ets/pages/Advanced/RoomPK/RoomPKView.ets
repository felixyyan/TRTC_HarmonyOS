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
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct RoomPKView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State isPK: boolean = false;
  @State remoteRoomId: string = '';
  @State remoteUserId: string = '';
  @State pkStatus: string = '';
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'roomPKLocalView';
  private remoteViewId: string = 'roomPKRemoteView';

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
        Text('Room PK')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('跨房间 PK 演示')
            .fontSize(14)
            .fontColor('#999999')

          Text('主播进入自己的房间后，可与另一个房间的\n主播进行 PK 连麦。')
            .fontSize(12)
            .fontColor('#666666')

          Row() {
            Text('用户ID: ').fontColor('#FFFFFF').fontSize(14).width(80)
            TextInput({ text: this.userId, placeholder: '请输入用户ID' })
              .width('60%')
              .height(40)
              .backgroundColor('#FFFFFF')
              .fontColor('#333333')
              .onChange((value: string) => {
                this.userId = value;
              })
          }.width('100%')

          Row() {
            Text('房间号: ').fontColor('#FFFFFF').fontSize(14).width(80)
            TextInput({ text: this.roomId, placeholder: '请输入房间号' })
              .width('60%')
              .height(40)
              .backgroundColor('#FFFFFF')
              .fontColor('#333333')
              .onChange((value: string) => {
                this.roomId = value;
              })
          }.width('100%')

          Button('进入房间（主播）')
            .width('80%')
            .height(44)
            .backgroundColor('#006EFF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.enterRoom();
            })
        }
        .width('100%')
        .padding(10)
      }

      if (this.isInRoom) {
        Column({ space: 10 }) {
          Column() {
            Text('本地画面')
              .fontSize(12)
              .fontColor('#FFFFFF')
            XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
              .width('100%')
              .height(200)
              .backgroundColor('#000000')
          }
          .width('100%')

          Column() {
            Text('PK对方画面')
              .fontSize(12)
              .fontColor('#FFFFFF')
            XComponent({ id: this.remoteViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
              .width('100%')
              .height(200)
              .backgroundColor('#333333')
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)

        Scroll() {
          Column({ space: 12 }) {
            Text('当前房间: ' + this.roomId)
              .fontSize(14)
              .fontColor('#00FF00')

            if (!this.isPK) {
              Row() {
                Text('对方房间: ').fontColor('#FFFFFF').fontSize(14).width(80)
                TextInput({ text: this.remoteRoomId, placeholder: '对方房间号' })
                  .width('50%')
                  .height(40)
                  .backgroundColor('#FFFFFF')
                  .fontColor('#333333')
                  .onChange((value: string) => {
                    this.remoteRoomId = value;
                  })
              }.width('100%')

              Row() {
                Text('对方用户: ').fontColor('#FFFFFF').fontSize(14).width(80)
                TextInput({ text: this.remoteUserId, placeholder: '对方用户ID' })
                  .width('50%')
                  .height(40)
                  .backgroundColor('#FFFFFF')
                  .fontColor('#333333')
                  .onChange((value: string) => {
                    this.remoteUserId = value;
                  })
              }.width('100%')

              Button('发起 PK')
                .width('80%')
                .height(44)
                .backgroundColor('#FF6600')
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.startPK();
                })
            }

            if (this.isPK) {
              Text('PK 进行中...')
                .fontSize(16)
                .fontColor('#FF6600')
                .fontWeight(FontWeight.Bold)

              Button('停止 PK')
                .width('80%')
                .height(44)
                .backgroundColor('#FF4444')
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.stopPK();
                })
            }

            if (this.pkStatus) {
              Text(this.pkStatus)
                .fontSize(12)
                .fontColor('#CCCCCC')
                .padding(10)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
                .width('100%')
            }

            Button('退出房间')
              .width('80%')
              .height(44)
              .backgroundColor('#FF4444')
              .fontColor('#FFFFFF')
              .margin({ top: 10 })
              .onClick(() => {
                this.exitRoom();
              })
          }
          .width('100%')
          .padding(10)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }

  private startPK() {
    if (!this.trtc || !this.remoteRoomId || !this.remoteUserId) {
      showToast('请输入对方房间号和用户ID');
      return;
    }
    let pkParams = JSON.stringify({
      roomId: Number(this.remoteRoomId),
      userId: this.remoteUserId
    });
    this.trtc.connectOtherRoom(pkParams);
    this.pkStatus = '正在请求 PK 连接...';
    showToast('正在发起PK');
  }

  private stopPK() {
    if (!this.trtc) {
      return;
    }
    this.trtc.disconnectOtherRoom();
    this.isPK = false;
    this.pkStatus = 'PK 已停止';
    showToast('PK 已停止');
  }

  private enterRoom() {
    if (!this.userId || !this.roomId) {
      showToast('请填写用户ID和房间号');
      return;
    }
    this.trtc = getTRTCShareInstance(getContext());
    let info = genTestUserSig(this.userId);
    let params = new TRTCParams(
      info.sdkappid,
      this.userId,
      info.userSig,
      Number(this.roomId),
      '',
      TRTCRoleType.TRTCRoleAnchor
    );
    let callback: TRTCCloudCallback = {
      onEnterRoom: (result: number) => {
        if (result > 0) {
          showToast('进房成功');
        } else {
          showToast('进房失败: ' + result);
          this.isInRoom = false;
        }
      },
      onConnectOtherRoom: (userId: string, errCode: number, errMsg: string) => {
        if (errCode === 0) {
          this.isPK = true;
          this.pkStatus = 'PK 连接成功，对方: ' + userId;
          showToast('PK 连接成功');
        } else {
          this.pkStatus = 'PK 连接失败: ' + errMsg;
          showToast('PK 连接失败: ' + errMsg);
        }
      },
      onDisconnectOtherRoom: (errCode: number, errMsg: string) => {
        this.isPK = false;
        this.pkStatus = 'PK 已断开';
      },
      onUserVideoAvailable: (userId: string, available: number) => {
        if (available !== 0) {
          this.trtc?.startRemoteView(userId, TRTCVideoStreamType.TRTCVideoStreamTypeBig, this.remoteViewId);
        } else {
          this.trtc?.stopRemoteView(userId, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
        }
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneLIVE);
    this.trtc.startLocalPreview(true, this.localViewId);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualityDefault);
    this.isInRoom = true;
  }

  private exitRoom() {
    if (this.isPK) {
      this.stopPK();
    }
    this.trtc?.stopLocalPreview();
    this.trtc?.stopLocalAudio();
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
