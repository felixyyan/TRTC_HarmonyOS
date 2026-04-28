import router from '@ohos.router';
import fs from '@ohos.file.fs';
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
  TRTCVideoPixelFormat,
  TRTCVideoBufferType,
  TRTCVideoRotation,
  TRTCVideoFrame
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

// YUV 文件参数（320x240 I420），资源文件名与工程 rawfile 一致
const YUV_WIDTH: number = 320;
const YUV_HEIGHT: number = 240;
const YUV_FRAME_SIZE: number = YUV_WIDTH * YUV_HEIGHT * 3 / 2;
const YUV_FPS: number = 15;
const YUV_FRAME_DURATION_MS: number = 1000 / YUV_FPS;
const RAWFILE_NAME: string = '320x240_video.yuv';

@Entry
@Component
struct CustomCameraView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State isCustomCapture: boolean = false;
  @State frameCount: number = 0;
  @State statusText: string = '';
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'customCameraLocalView';
  private yuvFile: fs.File | null = null;
  private yuvFilePath: string = '';
  private intervalId: number = 0;
  private startTime: number = 0;
  private sendedDurationMs: number = 0;

  aboutToAppear(): void {
    // 按照官方 Demo：先把 rawfile 拷贝到 app 的 filesDir，再通过 fs.open/read 按需读取
    try {
      this.yuvFilePath = getContext().getApplicationContext().filesDir + '/' + RAWFILE_NAME;
      let content = getContext().resourceManager.getRawFileContentSync(RAWFILE_NAME);
      let file = fs.openSync(this.yuvFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content.buffer);
      fs.closeSync(file);
      console.info('[CustomCamera] YUV copied to ' + this.yuvFilePath + ', size=' + content.byteLength);
    } catch (e) {
      console.error('[CustomCamera] copy rawfile failed: ' + JSON.stringify(e));
    }
  }

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
        Text('Custom Camera')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('自定义视频采集演示')
            .fontSize(14)
            .fontColor('#999999')

          Text('开启后 SDK 不再使用内置摄像头，\n改为从 filesDir 持续读取 YUV 文件，\n通过 sendCustomVideoData 发送视频帧。')
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
        if (!this.isCustomCapture) {
          XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
            .width('100%')
            .height(250)
            .backgroundColor('#000000')
        } else {
          Column() {
            Text('自定义采集模式中...\n远端应能看到 YUV 视频画面')
              .fontSize(14)
              .fontColor('#00FF00')
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height(250)
          .backgroundColor('#000000')
          .justifyContent(FlexAlign.Center)
        }

        Column({ space: 12 }) {
          Row() {
            Text('自定义视频采集: ').fontColor('#FFFFFF').fontSize(14)
            Toggle({ type: ToggleType.Switch, isOn: this.isCustomCapture })
              .onChange((isOn: boolean) => {
                if (this.isCustomCapture === isOn) {
                  return;
                }
                this.isCustomCapture = isOn;
                this.toggleCustomCapture(isOn);
              })
          }
          .width('100%')

          Text(this.isCustomCapture ?
            '自定义采集已开启\n已发送 ' + this.frameCount + ' 帧\n' + this.statusText :
            '使用 SDK 内置摄像头采集中...')
            .fontSize(12)
            .fontColor(this.isCustomCapture ? '#00FF00' : '#AAAAAA')
            .padding(10)
            .backgroundColor('#333333')
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

  private startSendCustomVideo() {
    if (!this.trtc) {
      return;
    }
    if (this.intervalId !== 0) {
      return;
    }
    try {
      this.yuvFile = fs.openSync(this.yuvFilePath, fs.OpenMode.READ_ONLY);
    } catch (e) {
      this.statusText = '打开 YUV 文件失败: ' + JSON.stringify(e);
      showToast(this.statusText);
      return;
    }
    this.startTime = Date.now();
    this.sendedDurationMs = 0;
    // 按官方 Demo：1ms 轮询，按时间戳判断是否到发送时机
    this.intervalId = setInterval(() => {
      this.processOneFrame();
    }, 1);
    this.statusText = '采集已启动';
  }

  private async processOneFrame(): Promise<void> {
    if (!this.trtc || !this.yuvFile) {
      return;
    }
    const elapsed = Date.now() - this.startTime;
    const timeToWait = (this.sendedDurationMs + YUV_FRAME_DURATION_MS) - elapsed;
    if (timeToWait > 0) {
      return;
    }
    try {
      this.sendedDurationMs += YUV_FRAME_DURATION_MS;
      const buffer = new ArrayBuffer(YUV_FRAME_SIZE);
      const bytesRead = await fs.read(this.yuvFile.fd, buffer, { length: YUV_FRAME_SIZE });
      if (bytesRead === YUV_FRAME_SIZE) {
        const frame: TRTCVideoFrame = new TRTCVideoFrame();
        frame.data = buffer;
        frame.videoFormat = TRTCVideoPixelFormat.TRTCVideoPixelFormat_I420;
        frame.bufferType = TRTCVideoBufferType.TRTCVideoBufferType_Buffer;
        frame.width = YUV_WIDTH;
        frame.height = YUV_HEIGHT;
        frame.rotatioin = TRTCVideoRotation.TRTCVideoRotation0;
        frame.timestamp = this.trtc.generateCustomPTS();
        this.trtc.sendCustomVideoData(TRTCVideoStreamType.TRTCVideoStreamTypeBig, frame);
        this.frameCount++;
      } else {
        // 读到文件末尾，循环回到开头
        fs.lseek(this.yuvFile.fd, 0);
      }
    } catch (e) {
      console.error('[CustomCamera] send frame failed: ' + JSON.stringify(e));
    }
  }

  private stopSendCustomVideo() {
    if (this.intervalId !== 0) {
      clearInterval(this.intervalId);
      this.intervalId = 0;
    }
    if (this.yuvFile) {
      try {
        fs.closeSync(this.yuvFile);
      } catch (e) { }
      this.yuvFile = null;
    }
  }

  private toggleCustomCapture(enable: boolean) {
    if (!this.trtc) {
      return;
    }
    if (enable) {
      this.trtc.stopLocalPreview();
      this.trtc.enableCustomVideoCapture(TRTCVideoStreamType.TRTCVideoStreamTypeBig, true);
      this.frameCount = 0;
      this.startSendCustomVideo();
      showToast('自定义视频采集已开启');
    } else {
      this.stopSendCustomVideo();
      this.trtc.enableCustomVideoCapture(TRTCVideoStreamType.TRTCVideoStreamTypeBig, false);
      this.frameCount = 0;
      this.statusText = '';
      this.trtc.startLocalPreview(true, this.localViewId);
      showToast('已恢复 SDK 摄像头采集');
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
          setTimeout(() => {
            this.trtc?.startLocalPreview(true, this.localViewId);
          }, 100);
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
    this.stopSendCustomVideo();
    if (this.isCustomCapture) {
      this.trtc?.enableCustomVideoCapture(TRTCVideoStreamType.TRTCVideoStreamTypeBig, false);
      this.isCustomCapture = false;
    }
    this.trtc?.stopLocalPreview();
    this.trtc?.stopLocalAudio();
    BackgroundRunningHelper.stop();
    this.trtc?.exitRoom();
    destroyTRTCShareInstance();
    this.trtc = null;
    this.isInRoom = false;
    this.frameCount = 0;
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
