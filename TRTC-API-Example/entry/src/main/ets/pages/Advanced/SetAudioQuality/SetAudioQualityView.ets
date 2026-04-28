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
struct SetAudioQualityView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State selectedQuality: TRTCAudioQuality = TRTCAudioQuality.TRTCAudioQualityDefault;
  @State selectedQualityIndex: number = 1;
  private trtc: TRTCCloud | null = null;

  private qualityNames: string[] = ['语音 (Speech)', '默认 (Default)', '音乐 (Music)'];
  private qualityValues: TRTCAudioQuality[] = [
    TRTCAudioQuality.TRTCAudioQualitySpeech,
    TRTCAudioQuality.TRTCAudioQualityDefault,
    TRTCAudioQuality.TRTCAudioQualityMusic
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
        Text('Set Audio Quality')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('设置音频质量（进房前选择）')
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

          Text('选择音频质量:')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .margin({ top: 10 })

          Column({ space: 8 }) {
            ForEach(this.qualityNames, (name: string, index: number) => {
              Row() {
                Radio({ value: name, group: 'audioQuality' })
                  .checked(this.selectedQualityIndex === index)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) {
                      this.selectedQualityIndex = index;
                      this.selectedQuality = this.qualityValues[index];
                    }
                  })
                Text(name).fontColor('#FFFFFF').fontSize(14).margin({ left: 8 })
              }
              .width('100%')
            })
          }
          .padding(10)

          Text('Speech: 采样率16k，单声道，适合语音通话\n' +
            'Default: 采样率48k，单声道，SDK默认\n' +
            'Music: 采样率48k，全频带立体声，适合音乐')
            .fontSize(12)
            .fontColor('#666666')
            .padding(10)

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
        Column({ space: 15 }) {
          Text('当前音频质量: ' + this.qualityNames[this.selectedQualityIndex])
            .fontSize(16)
            .fontColor('#00FF00')

          Text('已进入房间: ' + this.roomId)
            .fontSize(14)
            .fontColor('#CCCCCC')

          Text('音频采集中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 20 })

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
    this.trtc.startLocalAudio(this.selectedQuality);
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
