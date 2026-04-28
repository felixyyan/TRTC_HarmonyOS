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
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

interface SubRoomInfo {
  roomId: string;
  subCloud: TRTCCloud | null;
  isJoined: boolean;
}

@Entry
@Component
struct JoinMultipleRoomView {
  @State userId: string = generateUserId();
  @State mainRoomId: string = '1256732';
  @State isInMainRoom: boolean = false;
  @State subRoomIdInput: string = '';
  @State subRooms: SubRoomInfo[] = [];
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'multiRoomLocalView';

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('\u2190')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.isInMainRoom) {
              this.exitAllRooms();
            }
            router.back();
          })
        Text('Join Multiple Room')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInMainRoom) {
        Column({ space: 15 }) {
          Text('多房间加入演示（通过 SubCloud）')
            .fontSize(14)
            .fontColor('#999999')

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
            Text('主房间号: ').fontColor('#FFFFFF').fontSize(14).width(80)
            TextInput({ text: this.mainRoomId, placeholder: '请输入主房间号' })
              .width('60%')
              .height(40)
              .backgroundColor('#FFFFFF')
              .fontColor('#333333')
              .onChange((value: string) => {
                this.mainRoomId = value;
              })
          }.width('100%')

          Button('进入主房间')
            .width('80%')
            .height(44)
            .backgroundColor('#006EFF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.enterMainRoom();
            })
        }
        .width('100%')
        .padding(10)
      }

      if (this.isInMainRoom) {
        XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
          .width('100%')
          .height(200)
          .backgroundColor('#000000')

        Scroll() {
          Column({ space: 12 }) {
            Text('主房间: ' + this.mainRoomId)
              .fontSize(14)
              .fontColor('#00FF00')

            Row() {
              TextInput({ text: this.subRoomIdInput, placeholder: '输入子房间号' })
                .width('50%')
                .height(40)
                .backgroundColor('#FFFFFF')
                .fontColor('#333333')
                .onChange((value: string) => {
                  this.subRoomIdInput = value;
                })
              Button('加入子房间')
                .height(40)
                .margin({ left: 10 })
                .backgroundColor('#006EFF')
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.joinSubRoom();
                })
            }.width('100%')

            if (this.subRooms.length > 0) {
              Text('已加入的子房间:')
                .fontSize(14)
                .fontColor('#FFFFFF')

              ForEach(this.subRooms, (room: SubRoomInfo, index: number) => {
                Row() {
                  Text('子房间: ' + room.roomId)
                    .fontSize(14)
                    .fontColor(room.isJoined ? '#00FF00' : '#FF4444')
                    .layoutWeight(1)
                  Button('退出')
                    .height(32)
                    .backgroundColor('#FF4444')
                    .fontColor('#FFFFFF')
                    .fontSize(12)
                    .onClick(() => {
                      this.leaveSubRoom(index);
                    })
                }
                .width('100%')
                .padding(8)
                .backgroundColor('#FFFFFF')
                .borderRadius(8)
              }, (room: SubRoomInfo) => room.roomId)
            }

            Button('退出所有房间')
              .width('80%')
              .height(44)
              .backgroundColor('#FF4444')
              .fontColor('#FFFFFF')
              .margin({ top: 10 })
              .onClick(() => {
                this.exitAllRooms();
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

  private joinSubRoom() {
    if (!this.subRoomIdInput || !this.trtc) {
      showToast('请输入子房间号');
      return;
    }
    let exists = this.subRooms.some(r => r.roomId === this.subRoomIdInput);
    if (exists) {
      showToast('已加入该子房间');
      return;
    }

    let subCloud = this.trtc.createSubCloud();
    let info = genTestUserSig(this.userId);
    let params = new TRTCParams(
      info.sdkappid,
      this.userId,
      info.userSig,
      Number(this.subRoomIdInput),
      '',
      TRTCRoleType.TRTCRoleAnchor
    );

    let roomId = this.subRoomIdInput;
    let callback: TRTCCloudCallback = {
      onEnterRoom: (result: number) => {
        if (result > 0) {
          showToast('子房间 ' + roomId + ' 进入成功');
          let idx = this.subRooms.findIndex(r => r.roomId === roomId);
          if (idx >= 0) {
            this.subRooms[idx].isJoined = true;
            this.subRooms = [...this.subRooms];
          }
        } else {
          showToast('子房间进入失败: ' + result);
        }
      }
    };
    subCloud.addCallback(callback);
    BackgroundRunningHelper.start();
    subCloud.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);

    let subRoomInfo: SubRoomInfo = {
      roomId: this.subRoomIdInput,
      subCloud: subCloud,
      isJoined: false
    };
    this.subRooms.push(subRoomInfo);
    this.subRooms = [...this.subRooms];
    this.subRoomIdInput = '';
  }

  private leaveSubRoom(index: number) {
    let room = this.subRooms[index];
    if (room.subCloud) {
      BackgroundRunningHelper.stop();
      room.subCloud.exitRoom();
      this.trtc?.destroySubCloud(room.subCloud);
    }
    this.subRooms.splice(index, 1);
    this.subRooms = [...this.subRooms];
    showToast('已退出子房间');
  }

  private enterMainRoom() {
    if (!this.userId || !this.mainRoomId) {
      showToast('请填写用户ID和房间号');
      return;
    }
    this.trtc = getTRTCShareInstance(getContext());
    let info = genTestUserSig(this.userId);
    let params = new TRTCParams(
      info.sdkappid,
      this.userId,
      info.userSig,
      Number(this.mainRoomId),
      '',
      TRTCRoleType.TRTCRoleAnchor
    );
    let callback: TRTCCloudCallback = {
      onEnterRoom: (result: number) => {
        if (result > 0) {
          showToast('主房间进入成功');
        } else {
          showToast('主房间进入失败: ' + result);
          this.isInMainRoom = false;
        }
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);
    this.trtc.startLocalPreview(true, this.localViewId);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
    this.isInMainRoom = true;
  }

  private exitAllRooms() {
    for (let room of this.subRooms) {
      if (room.subCloud) {
        BackgroundRunningHelper.stop();
        room.subCloud.exitRoom();
        this.trtc?.destroySubCloud(room.subCloud);
      }
    }
    this.subRooms = [];
    this.trtc?.stopLocalPreview();
    this.trtc?.stopLocalAudio();
    BackgroundRunningHelper.stop();
    this.trtc?.exitRoom();
    destroyTRTCShareInstance();
    this.trtc = null;
    this.isInMainRoom = false;
  }

  aboutToDisappear() {
    if (this.isInMainRoom) {
      this.exitAllRooms();
    }
  }

  onBackPress(): boolean | void {
    if (this.isInMainRoom) {
      this.exitAllRooms();
    }
  }
}
