import router from '@ohos.router';
import util from '@ohos.util';
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

@Entry
@Component
struct SEIMessageView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State seiInput: string = '';
  @State receivedMessages: string = '';
  @State sendCount: number = 0;
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'seiMessageLocalView';

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
        Text('SEI Message')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('SEI 消息收发演示')
            .fontSize(14)
            .fontColor('#999999')

          Text('SEI 消息可随视频帧发送自定义数据，\n常用于同步歌词、时间戳等信息。')
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
          .height(180)
          .backgroundColor('#000000')

        Column({ space: 10 }) {
          Text('发送 SEI 消息')
            .fontSize(14)
            .fontColor('#FFFFFF')

          Row() {
            TextInput({ text: this.seiInput, placeholder: '输入SEI消息内容' })
              .width('60%')
              .height(40)
              .backgroundColor('#FFFFFF')
              .fontColor('#333333')
              .onChange((value: string) => {
                this.seiInput = value;
              })
            Button('发送')
              .height(40)
              .margin({ left: 10 })
              .backgroundColor('#006EFF')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.sendSEI();
              })
          }.width('100%')

          Text('已发送: ' + this.sendCount + ' 条')
            .fontSize(12)
            .fontColor('#999999')

          Text('接收到的 SEI 消息:')
            .fontSize(14)
            .fontColor('#FFFFFF')

          Scroll() {
            Text(this.receivedMessages || '暂无收到的SEI消息...')
              .fontSize(12)
              .fontColor('#333333')
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .height(140)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding(10)
          .align(Alignment.TopStart)

          Text('提示:\n- 对端必须在发视频帧时才能搭载 SEI 发送\n- 中文消息已使用 UTF-8 编解码，避免乱码')
            .fontSize(11)
            .fontColor('#888888')
            .width('100%')

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

  private sendSEI() {
    if (!this.trtc || !this.seiInput) {
      showToast('请输入消息内容');
      return;
    }
    // 必须使用 UTF-8 编码，直接 charCodeAt 会截断中文高位导致对端乱码
    let textEncoder = new util.TextEncoder('utf-8');
    let encoded = textEncoder.encodeInto(this.seiInput);
    if (!encoded) {
      showToast('消息编码失败');
      return;
    }
    let ok = this.trtc.sendSEIMsg(encoded.buffer as ArrayBuffer, 1);
    if (ok) {
      this.sendCount++;
      showToast('SEI 消息已发送');
    } else {
      showToast('SEI 消息发送失败（码率过低或频率超限）');
    }
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
      onRecvSEIMsg: (userId: string, data: ArrayBuffer) => {
        // 必须使用 UTF-8 解码，否则中文会变乱码
        let textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
        let message: string = textDecoder.decodeToString(new Uint8Array(data));
        let timestamp = new Date().toLocaleTimeString();
        this.receivedMessages = `[${timestamp}] ${userId}: ${message}\n` + this.receivedMessages;
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);
    this.trtc.startLocalPreview(true, this.localViewId);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
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
  }
}
