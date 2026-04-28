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
  TRTCVideoEncParam,
  TRTCVideoResolution,
  TRTCVideoResolutionMode
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct SetVideoQualityView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State selectedResolution: number = TRTCVideoResolution.TRTCVideoResolution_640_360;
  @State selectedFps: number = 15;
  @State selectedBitrate: number = 800;
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'videoQualityLocalView';

  private resolutionOptions: SelectOption[] = [
    { value: '160x120' },
    { value: '320x180' },
    { value: '320x240' },
    { value: '640x360' },
    { value: '640x480' },
    { value: '960x540' },
    { value: '1280x720' },
    { value: '1920x1080' },
  ];

  private resolutionValues: number[] = [
    TRTCVideoResolution.TRTCVideoResolution_160_120,
    TRTCVideoResolution.TRTCVideoResolution_320_180,
    TRTCVideoResolution.TRTCVideoResolution_320_240,
    TRTCVideoResolution.TRTCVideoResolution_640_360,
    TRTCVideoResolution.TRTCVideoResolution_640_480,
    TRTCVideoResolution.TRTCVideoResolution_960_540,
    TRTCVideoResolution.TRTCVideoResolution_1280_720,
    TRTCVideoResolution.TRTCVideoResolution_1920_1080,
  ];

  private fpsOptions: SelectOption[] = [
    { value: '15' },
    { value: '20' },
    { value: '24' },
    { value: '30' },
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
        Text('Set Video Quality')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('设置视频编码参数（分辨率/帧率/码率）')
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
        XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
          .width('100%')
          .height(250)
          .backgroundColor('#000000')

        Scroll() {
          Column({ space: 12 }) {
            Row() {
              Text('分辨率: ').fontColor('#FFFFFF').fontSize(14).width(70)
              Select(this.resolutionOptions)
                .selected(3)
                .value('640x360')
                .fontColor('#FFFFFF')
                .selectedOptionBgColor('#006EFF')
                .optionBgColor('#2A2B2E')
                .optionFontColor('#FFFFFF')
                .onSelect((index: number) => {
                  this.selectedResolution = this.resolutionValues[index];
                  this.applyVideoParams();
                })
            }.width('100%')

            Row() {
              Text('帧率: ').fontColor('#FFFFFF').fontSize(14).width(70)
              Select(this.fpsOptions)
                .selected(0)
                .value('15')
                .fontColor('#FFFFFF')
                .selectedOptionBgColor('#006EFF')
                .optionBgColor('#2A2B2E')
                .optionFontColor('#FFFFFF')
                .onSelect((index: number) => {
                  this.selectedFps = [15, 20, 24, 30][index];
                  this.applyVideoParams();
                })
            }.width('100%')

            Row() {
              Text('码率: ').fontColor('#FFFFFF').fontSize(14).width(70)
              Text(this.selectedBitrate + ' kbps').fontColor('#FFFFFF').fontSize(14).width(80)
            }.width('100%')

            Slider({
              value: this.selectedBitrate,
              min: 200,
              max: 2000,
              step: 100
            })
              .blockColor('#006EFF')
              .trackColor('#2A2B2E')
              .selectedColor('#006EFF')
              .onChange((value: number) => {
                this.selectedBitrate = value;
                this.applyVideoParams();
              })

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
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }

  private applyVideoParams() {
    if (!this.trtc) {
      return;
    }
    let param = new TRTCVideoEncParam();
    param.videoResolution = this.selectedResolution;
    param.resMode = TRTCVideoResolutionMode.TRTCVideoResolutionModeLandscape;
    param.videoFps = this.selectedFps;
    param.videoBitrate = this.selectedBitrate;
    this.trtc.setVideoEncoderParam(param);
    showToast('视频参数已更新');
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
    this.applyVideoParams();
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
