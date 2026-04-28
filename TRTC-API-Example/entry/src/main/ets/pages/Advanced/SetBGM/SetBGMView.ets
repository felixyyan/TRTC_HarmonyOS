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
  AudioMusicParam
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct SetBGMView {
  // 默认 BGM 地址（腾讯云官方示例音频）
  private static readonly DEFAULT_BGM_URL: string =
    '填写BGM 地址，可以是URL 链接';

  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State isBGMPlaying: boolean = false;
  @State bgmVolume: number = 50;
  @State bgmPublishVolume: number = 50;
  @State bgmPlayoutVolume: number = 50;
  @State bgmPath: string = SetBGMView.DEFAULT_BGM_URL;
  private trtc: TRTCCloud | null = null;
  private bgmId: number = 1001;

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
        Text('Set BGM')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('背景音乐播放演示')
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

          Row() {
            Text('BGM路径: ').fontColor('#FFFFFF').fontSize(14).width(80)
            TextInput({ text: this.bgmPath, placeholder: '输入BGM文件路径或HTTP(S) URL' })
              .width('60%')
              .height(40)
              .backgroundColor('#FFFFFF')
              .fontColor('#333333')
              .onChange((value: string) => {
                this.bgmPath = value;
              })
          }.width('100%')

          Row({ space: 8 }) {
            Button('使用默认在线BGM')
              .height(32)
              .fontSize(12)
              .backgroundColor('#2A2B2E')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.bgmPath = SetBGMView.DEFAULT_BGM_URL;
                showToast('已填入默认BGM地址');
              })
            Button('清空')
              .height(32)
              .fontSize(12)
              .backgroundColor('#2A2B2E')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.bgmPath = '';
              })
          }.width('100%').justifyContent(FlexAlign.Center)

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
            Text('BGM 控制')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)

            Row({ space: 10 }) {
              Button(this.isBGMPlaying ? '暂停' : '播放')
                .height(40)
                .backgroundColor(this.isBGMPlaying ? '#FFAA00' : '#00AA00')
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.toggleBGM();
                })

              Button('停止')
                .height(40)
                .backgroundColor('#FF4444')
                .fontColor('#FFFFFF')
                .onClick(() => {
                  this.stopBGM();
                })
            }.width('100%').justifyContent(FlexAlign.Center)

            Text('BGM 本地播放音量: ' + this.bgmPlayoutVolume)
              .fontColor('#FFFFFF')
              .fontSize(14)
            Slider({
              value: this.bgmPlayoutVolume,
              min: 0,
              max: 100,
              step: 1
            })
              .blockColor('#006EFF')
              .trackColor('#2A2B2E')
              .selectedColor('#006EFF')
              .onChange((value: number) => {
                this.bgmPlayoutVolume = value;
                this.updateBGMPlayoutVolume();
              })

            Text('BGM 远端发布音量: ' + this.bgmPublishVolume)
              .fontColor('#FFFFFF')
              .fontSize(14)
            Slider({
              value: this.bgmPublishVolume,
              min: 0,
              max: 100,
              step: 1
            })
              .blockColor('#006EFF')
              .trackColor('#2A2B2E')
              .selectedColor('#006EFF')
              .onChange((value: number) => {
                this.bgmPublishVolume = value;
                this.updateBGMPublishVolume();
              })

            Text('提示: 支持本地文件路径或 HTTP(S) 在线音频 URL，已预置一个腾讯云示例 BGM。')
              .fontSize(12)
              .fontColor('#666666')

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

  private toggleBGM() {
    if (!this.trtc) {
      return;
    }
    let audioEffectManager = this.trtc.getAudioEffectManager();
    if (this.isBGMPlaying) {
      audioEffectManager.pausePlayMusic(this.bgmId);
      this.isBGMPlaying = false;
      showToast('BGM 已暂停');
    } else {
      if (!this.bgmPath) {
        showToast('请先输入BGM文件路径');
        return;
      }
      let musicParam: AudioMusicParam = new AudioMusicParam(this.bgmId, this.bgmPath);
      musicParam.loopCount = -1;
      musicParam.publish = true;
      musicParam.isShortFile = false;
      musicParam.startTimeMS = 0;
      musicParam.endTimeMS = 0;
      audioEffectManager.startPlayMusic(musicParam);
      this.isBGMPlaying = true;
      showToast('BGM 播放中');
    }
  }

  private stopBGM() {
    if (!this.trtc) {
      return;
    }
    let audioEffectManager = this.trtc.getAudioEffectManager();
    audioEffectManager.stopPlayMusic(this.bgmId);
    this.isBGMPlaying = false;
    showToast('BGM 已停止');
  }

  private updateBGMPlayoutVolume() {
    if (!this.trtc) {
      return;
    }
    let audioEffectManager = this.trtc.getAudioEffectManager();
    audioEffectManager.setMusicPlayoutVolume(this.bgmId, this.bgmPlayoutVolume);
  }

  private updateBGMPublishVolume() {
    if (!this.trtc) {
      return;
    }
    let audioEffectManager = this.trtc.getAudioEffectManager();
    audioEffectManager.setMusicPublishVolume(this.bgmId, this.bgmPublishVolume);
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
    if (this.isBGMPlaying) {
      this.stopBGM();
    }
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
