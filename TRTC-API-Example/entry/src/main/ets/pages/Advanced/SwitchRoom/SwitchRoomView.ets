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
  TRTCSwitchRoomConfig
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct SwitchRoomView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State newRoomId: string = '';
  @State isInRoom: boolean = false;
  @State currentRoomId: string = '';
  @State switchHistory: string[] = [];
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'switchRoomLocalView';

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
        Text('Switch Room')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('快速切换房间演示')
            .fontSize(14)
            .fontColor('#999999')

          Text('使用 switchRoom 可在不退出当前房间的情况下\n快速切换到另一个房间，适用于大班课等场景。')
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

          Button('进入房间')
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
        XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
          .width('100%')
          .height(200)
          .backgroundColor('#000000')

        Column({ space: 12 }) {
          Text('当前房间: ' + this.currentRoomId)
            .fontSize(16)
            .fontColor('#00FF00')

          Row() {
            Text('新房间: ').fontColor('#FFFFFF').fontSize(14).width(70)
            TextInput({ text: this.newRoomId, placeholder: '输入目标房间号' })
              .width('45%')
              .height(40)
              .backgroundColor('#FFFFFF')
              .fontColor('#333333')
              .onChange((value: string) => {
                this.newRoomId = value;
              })
            Button('切换')
              .height(40)
              .margin({ left: 10 })
              .backgroundColor('#006EFF')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.switchRoom();
              })
          }.width('100%')

          if (this.switchHistory.length > 0) {
            Text('切换记录:')
              .fontSize(14)
              .fontColor('#FFFFFF')
            Scroll() {
              Column({ space: 4 }) {
                ForEach(this.switchHistory, (item: string, index: number) => {
                  Text(item)
                    .fontSize(12)
                    .fontColor('#CCCCCC')
                }, (item: string, index: number) => index + '_' + item)
              }
              .width('100%')
            }
            .width('100%')
            .height(100)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .padding(8)
          }

          Button('退出房间')
            .width('80%')
            .height(44)
            .backgroundColor('#FF4444')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.exitRoom();
            })
        }
        .width('100%')
        .padding(10)
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }

  private switchRoom() {
    if (!this.trtc || !this.newRoomId) {
      showToast('请输入目标房间号');
      return;
    }
    if (this.newRoomId === this.currentRoomId) {
      showToast('已在该房间中');
      return;
    }
    let info = genTestUserSig(this.userId);
    let switchConfig: TRTCSwitchRoomConfig = new TRTCSwitchRoomConfig();
    switchConfig.roomId = Number(this.newRoomId);
    switchConfig.userSig = info.userSig;
    this.trtc.switchRoom(switchConfig);
    let timestamp = new Date().toLocaleTimeString();
    this.switchHistory.push('[' + timestamp + '] ' + this.currentRoomId + ' -> ' + this.newRoomId);
    this.switchHistory = [...this.switchHistory];
    this.currentRoomId = this.newRoomId;
    this.newRoomId = '';
    showToast('正在切换到房间 ' + this.currentRoomId);
  }

  private enterRoom() {
    if (!this.userId || !this.roomId) {
      showToast('请填写用户ID和房间号');
      return;
    }
    this.trtc = getTRTCShareInstance(getContext(this));
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
      onSwitchRoom: (errCode: number, errMsg: string) => {
        if (errCode === 0) {
          showToast('切换房间成功');
        } else {
          showToast('切换房间失败: ' + errMsg);
        }
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);
    this.trtc.startLocalPreview(true, this.localViewId);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
    this.currentRoomId = this.roomId;
    this.isInRoom = true;
  }

  private exitRoom() {
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
    return true;
  }
}
