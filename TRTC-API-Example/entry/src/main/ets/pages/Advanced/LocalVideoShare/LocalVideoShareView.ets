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
  TRTCVideoStreamType,
  TRTCVideoEncParam,
  TRTCVideoResolution,
  TRTCVideoResolutionMode
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct LocalVideoShareView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State isPublishing: boolean = false;      // 是否正在发布主流视频
  @State isScreenCapturing: boolean = false; // 是否正在屏幕采集（辅路）
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'localVideoShareView';

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
        Text('Local Video Share')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('本地视频分享演示')
            .fontSize(14)
            .fontColor('#999999')

          Text('演示主流视频发布和辅路（屏幕采集）发布的概念。\n' +
            '- 主流（Big）：摄像头画面，其他人能看到你的摄像头画面\n' +
            '- 辅路（Sub）：屏幕采集画面，用于屏幕分享\n' +
            '- 同一用户可同时发布主流和辅路')
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
        // 本地预览窗口
        Column() {
          Text('本地预览（主流）')
            .fontSize(12)
            .fontColor('#FFFFFF')
          XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
            .width('100%')
            .height(200)
            .backgroundColor('#000000')
        }
        .width('100%')

        Column({ space: 12 }) {
          Text('当前房间: ' + this.roomId)
            .fontSize(14)
            .fontColor('#00FF00')

          // 主流发布控制
          Row({ space: 10 }) {
            Button(this.isPublishing ? '停止发布主流' : '发布主流视频')
              .height(40)
              .backgroundColor(this.isPublishing ? '#FF4444' : '#00AA00')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.togglePublish();
              })

            Button(this.isScreenCapturing ? '停止屏幕采集' : '开始屏幕采集（辅路）')
              .height(40)
              .backgroundColor(this.isScreenCapturing ? '#FF4444' : '#FF6600')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.toggleScreenCapture();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          // 状态显示
          Column({ space: 4 }) {
            Text('主流状态: ' + (this.isPublishing ? '✅ 已发布（其他人能看到你的摄像头画面）' : '❌ 未发布'))
              .fontSize(12)
              .fontColor(this.isPublishing ? '#00FF00' : '#FF4444')
            Text('辅路状态: ' + (this.isScreenCapturing ? '✅ 屏幕采集中（其他人能看到你的屏幕）' : '❌ 未采集'))
              .fontSize(12)
              .fontColor(this.isScreenCapturing ? '#00FF00' : '#FF4444')
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#333333')
          .borderRadius(8)

          Text('说明:\n' +
            '- 发布主流：其他人能在远端看到你的摄像头画面\n' +
            '- 屏幕采集（辅路）：其他人能看到你的屏幕内容\n' +
            '- 可用另一台设备进入同一房间测试效果')
            .fontSize(12)
            .fontColor('#999999')
            .padding(10)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
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

  // 切换主流发布状态
  private togglePublish() {
    if (!this.trtc) {
      return;
    }
    if (this.isPublishing) {
      // 停止发布主流（摄像头预览）
      this.trtc.stopLocalPreview();
      this.isPublishing = false;
      showToast('已停止发布主流视频');
    } else {
      // 开始发布主流（摄像头预览）
      this.trtc.startLocalPreview(true, this.localViewId);
      this.isPublishing = true;
      showToast('已开始发布主流视频');
    }
  }

  // 切换屏幕采集状态（辅路）
  private toggleScreenCapture() {
    if (!this.trtc) {
      return;
    }
    if (this.isScreenCapturing) {
      // 停止屏幕采集
      this.trtc.stopScreenCapture();
      this.isScreenCapturing = false;
      showToast('已停止屏幕采集');
    } else {
      // 开始屏幕采集（辅路），使用推荐的屏幕分享编码参数
      let encParam: TRTCVideoEncParam = new TRTCVideoEncParam(
        TRTCVideoResolution.TRTCVideoResolution_1280_720,
        TRTCVideoResolutionMode.TRTCVideoResolutionModeLandscape,
        15,
        1600,
        0,
        true
      );
      this.trtc.startScreenCapture(TRTCVideoStreamType.TRTCVideoStreamTypeSub, encParam);
      this.isScreenCapturing = true;
      showToast('已开始屏幕采集（辅路）');
    }
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
          // 进房成功后自动开始发布主流视频
          setTimeout(() => {
            this.togglePublish();
          }, 500);
        } else {
          showToast('进房失败: ' + result);
          this.isInRoom = false;
        }
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
    this.isInRoom = true;
  }

  private exitRoom() {
    if (this.isPublishing) {
      this.trtc?.stopLocalPreview();
      this.isPublishing = false;
    }
    if (this.isScreenCapturing) {
      this.trtc?.stopScreenCapture();
      this.isScreenCapturing = false;
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
