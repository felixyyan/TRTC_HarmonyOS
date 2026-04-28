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

@Entry
@Component
struct SetAudioEffectView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State selectedVoiceChanger: number = 0;
  @State selectedReverb: number = 0;
  private trtc: TRTCCloud | null = null;

  private voiceChangerNames: string[] = [
    '原声', '熊孩子', '萝莉', '大叔', '重金属',
    '感冒', '外国人', '困兽', '死肥宅', '强电流',
    '重机械', '空灵'
  ];

  private reverbNames: string[] = [
    '无效果', 'KTV', '小房间', '大会堂', '低沉',
    '洪亮', '金属声', '磁性', '空灵'
  ];

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
        Text('Set Audio Effect')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('音效设置（变声/混响）')
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
        Scroll() {
          Column({ space: 12 }) {
            Text('变声效果')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.voiceChangerNames, (name: string, index: number) => {
                Button(name)
                  .height(36)
                  .margin(4)
                  .backgroundColor(this.selectedVoiceChanger === index ? '#006EFF' : '#2A2B2E')
                  .fontColor('#FFFFFF')
                  .fontSize(12)
                  .onClick(() => {
                    this.selectedVoiceChanger = index;
                    this.applyVoiceChanger(index);
                  })
              })
            }
            .width('100%')

            Text('混响效果')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .margin({ top: 10 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.reverbNames, (name: string, index: number) => {
                Button(name)
                  .height(36)
                  .margin(4)
                  .backgroundColor(this.selectedReverb === index ? '#006EFF' : '#2A2B2E')
                  .fontColor('#FFFFFF')
                  .fontSize(12)
                  .onClick(() => {
                    this.selectedReverb = index;
                    this.applyReverb(index);
                  })
              })
            }
            .width('100%')

            Button('退出房间')
              .width('80%')
              .height(44)
              .backgroundColor('#FF4444')
              .fontColor('#FFFFFF')
              .margin({ top: 20 })
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

  private applyVoiceChanger(type: number) {
    if (!this.trtc) {
      return;
    }
    let audioEffectManager = this.trtc.getAudioEffectManager();
    audioEffectManager.setVoiceChangerType(type);
    showToast('变声: ' + this.voiceChangerNames[type]);
  }

  private applyReverb(type: number) {
    if (!this.trtc) {
      return;
    }
    let audioEffectManager = this.trtc.getAudioEffectManager();
    audioEffectManager.setVoiceReverbType(type);
    showToast('混响: ' + this.reverbNames[type]);
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
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualityMusic);
    this.isInRoom = true;
  }

  private exitRoom() {
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
