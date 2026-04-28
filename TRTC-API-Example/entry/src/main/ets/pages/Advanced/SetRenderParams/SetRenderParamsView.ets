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
  TRTCVideoFillMode,
  TRTCVideoRotation,
  TRTCVideoMirrorType,
  TRTCRenderParams
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct SetRenderParamsView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State selectedFillMode: number = 0;
  @State selectedRotation: number = 0;
  @State selectedMirror: number = 0;
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'renderParamsLocalView';

  private fillModeNames: string[] = ['Fill（填充）', 'Fit（适应）'];
  private fillModeValues: TRTCVideoFillMode[] = [
    TRTCVideoFillMode.TRTCVideoFillMode_Fill,
    TRTCVideoFillMode.TRTCVideoFillMode_Fit,
  ];

  private rotationNames: string[] = ['0\u00B0', '90\u00B0', '180\u00B0', '270\u00B0'];
  private rotationValues: TRTCVideoRotation[] = [
    TRTCVideoRotation.TRTCVideoRotation0,
    TRTCVideoRotation.TRTCVideoRotation90,
    TRTCVideoRotation.TRTCVideoRotation180,
    TRTCVideoRotation.TRTCVideoRotation270,
  ];

  private mirrorNames: string[] = ['Auto', 'Enable', 'Disable'];
  private mirrorValues: TRTCVideoMirrorType[] = [
    TRTCVideoMirrorType.TRTCVideoMirrorType_Auto,
    TRTCVideoMirrorType.TRTCVideoMirrorType_Enable,
    TRTCVideoMirrorType.TRTCVideoMirrorType_Disable,
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
        Text('Set Render Params')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('设置本地视频渲染参数')
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
            Text('填充模式').fontColor('#FFFFFF').fontSize(14)
            Row({ space: 8 }) {
              ForEach(this.fillModeNames, (name: string, index: number) => {
                Button(name)
                  .height(36)
                  .backgroundColor(this.selectedFillMode === index ? '#006EFF' : '#2A2B2E')
                  .fontColor('#FFFFFF')
                  .fontSize(12)
                  .onClick(() => {
                    this.selectedFillMode = index;
                    this.applyRenderParams();
                  })
              })
            }.width('100%')

            Text('旋转角度').fontColor('#FFFFFF').fontSize(14)
            Row({ space: 8 }) {
              ForEach(this.rotationNames, (name: string, index: number) => {
                Button(name)
                  .height(36)
                  .backgroundColor(this.selectedRotation === index ? '#006EFF' : '#2A2B2E')
                  .fontColor('#FFFFFF')
                  .fontSize(12)
                  .onClick(() => {
                    this.selectedRotation = index;
                    this.applyRenderParams();
                  })
              })
            }.width('100%')

            Text('镜像模式').fontColor('#FFFFFF').fontSize(14)
            Row({ space: 8 }) {
              ForEach(this.mirrorNames, (name: string, index: number) => {
                Button(name)
                  .height(36)
                  .backgroundColor(this.selectedMirror === index ? '#006EFF' : '#2A2B2E')
                  .fontColor('#FFFFFF')
                  .fontSize(12)
                  .onClick(() => {
                    this.selectedMirror = index;
                    this.applyRenderParams();
                  })
              })
            }.width('100%')

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

  private applyRenderParams() {
    if (!this.trtc) {
      return;
    }
    let renderParams: TRTCRenderParams = new TRTCRenderParams();
    renderParams.fillMode = this.fillModeValues[this.selectedFillMode];
    renderParams.rotation = this.rotationValues[this.selectedRotation];
    renderParams.mirrorType = this.mirrorValues[this.selectedMirror];
    this.trtc.setLocalRenderParams(renderParams);
    showToast('渲染参数已更新');
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
