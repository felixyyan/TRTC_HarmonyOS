import router from '@ohos.router';
import fs from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
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
  TRTCVideoFrame,
  TRTCAudioFrame,
  TRTCAudioFrameCallbackFormat,
  TRTCAudioFrameOperationMode,
  ITRTCAudioFrameCallback,
  ITRTCVideoRenderCallback
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

// PCM 文件参数（48000Hz、1ch、16bit），文件名里的 48000_1 已经说明了格式
// 按官方文档推荐 20ms 帧长：48000 * 0.02 * 1 * 2 byte = 1920 字节/帧
const PCM_SAMPLE_RATE: number = 48000;
const PCM_CHANNELS: number = 1;
const PCM_BITS_PER_SAMPLE: number = 16;
const PCM_FRAME_DURATION_MS: number = 20;
const PCM_FRAME_SIZE: number =
  PCM_SAMPLE_RATE * PCM_FRAME_DURATION_MS / 1000 * PCM_CHANNELS * (PCM_BITS_PER_SAMPLE / 8);
const PCM_RAWFILE_NAME: string = 'custom_audio_48000_1.pcm';

const TAG: string = '[CustomCamera]';

// 一条远端流的渲染状态 - 使用 @Observed 让属性变化能触发 UI 刷新
@Observed
class RemoteStreamState {
  userId: string;
  streamType: TRTCVideoStreamType;
  pixelMap: PixelMap | null;
  width: number;
  height: number;
  frameCount: number;

  constructor(userId: string, streamType: TRTCVideoStreamType) {
    this.userId = userId;
    this.streamType = streamType;
    this.pixelMap = null;
    this.width = 0;
    this.height = 0;
    this.frameCount = 0;
  }
}

// 远端流渲染子组件 - 使用 @ObjectLink 监听 @Observed 对象的属性变化
@Component
struct RemoteStreamView {
  @ObjectLink stream: RemoteStreamState;

  build() {
    Stack() {
      if (this.stream.pixelMap) {
        Image(this.stream.pixelMap)
          .width('100%')
          .height(180)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
      } else {
        Column() {
          Text('等待 ' + this.stream.userId + ' 首帧...').fontColor('#AAAAAA').fontSize(12)
        }
        .width('100%')
        .height(180)
        .backgroundColor('#000000')
        .justifyContent(FlexAlign.Center)
      }
      // 视频上显示用户ID
      Text(this.stream.userId)
        .fontSize(10)
        .fontColor('#FFFFFF')
        .backgroundColor('#00000088')
        .padding(4)
        .position({ x: 6, y: 6 })
    }
    .width('100%')
    .margin({ top: 6 })
  }
}

@Entry
@Component
struct CustomCameraView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State isCustomCapture: boolean = false;
  @State frameCount: number = 0;
  @State statusText: string = '';

  // === 自定义音频采集相关 state ===
  @State isCustomAudioCapture: boolean = false;
  @State audioFrameCount: number = 0;
  @State audioStatusText: string = '';

  // === 音频数据回调相关 state（示例：只计数，不做业务处理） ===
  @State isAudioFrameCallbackOn: boolean = false;
  @State capturedCnt: number = 0;
  @State localProcessedCnt: number = 0;
  @State remoteUserCnt: number = 0;
  @State mixedPlayCnt: number = 0;

  // === 自定义渲染相关 state ===
  @State isLocalCustomRender: boolean = false;
  @State localRenderPixelMap: PixelMap | null = null;
  @State localRenderFrameCount: number = 0;
  @State localRenderStatus: string = '';
  @State remoteStreams: RemoteStreamState[] = [];
  @State remoteRenderStatus: string = '';

  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'customCameraLocalView';
  // 隐藏占位 XComponent，给 SDK 采集/解码流程用；自定义渲染时不占可视面积
  private hiddenLocalViewId: string = 'customCameraHiddenLocalView';
  private yuvFile: fs.File | null = null;
  private yuvFilePath: string = '';
  private intervalId: number = 0;
  private startTime: number = 0;
  private sendedDurationMs: number = 0;

  // 自定义音频采集
  private pcmFile: fs.File | null = null;
  private pcmFilePath: string = '';
  private audioIntervalId: number = 0;
  private audioStartTime: number = 0;
  private audioSendedDurationMs: number = 0;

  // 限流渲染：避免主线程被回调刷爆
  private lastLocalRenderTs: number = 0;
  private lastRemoteRenderTs: Map<string, number> = new Map();
  private readonly RENDER_INTERVAL_MS: number = 66; // ~15fps

  // 背压：正在构建 PixelMap 时直接丢掉新帧，不排队（避免 Promise 雪崩）
  private localBusy: boolean = false;
  private remoteBusy: Map<string, boolean> = new Map();

  aboutToAppear(): void {
    try {
      this.yuvFilePath = getContext().getApplicationContext().filesDir + '/' + RAWFILE_NAME;
      let content = getContext().resourceManager.getRawFileContentSync(RAWFILE_NAME);
      let file = fs.openSync(this.yuvFilePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content.buffer);
      fs.closeSync(file);
      console.info(TAG + ' YUV copied to ' + this.yuvFilePath + ', size=' + content.byteLength);
    } catch (e) {
      console.error(TAG + ' copy rawfile failed: ' + JSON.stringify(e));
    }

    // 同样把 PCM rawfile 拷贝到 filesDir，运行时按需读取
    try {
      this.pcmFilePath = getContext().getApplicationContext().filesDir + '/' + PCM_RAWFILE_NAME;
      const pcmContent = getContext().resourceManager.getRawFileContentSync(PCM_RAWFILE_NAME);
      const pcmFile = fs.openSync(
        this.pcmFilePath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
      );
      fs.writeSync(pcmFile.fd, pcmContent.buffer);
      fs.closeSync(pcmFile);
      console.info(TAG + ' PCM copied to ' + this.pcmFilePath + ', size=' + pcmContent.byteLength);
    } catch (e) {
      console.error(TAG + ' copy pcm rawfile failed: ' + JSON.stringify(e));
    }
  }

  build() {
    Scroll() {
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
            Text('自定义视频采集 + 自定义渲染 演示')
              .fontSize(14)
              .fontColor('#999999')

            Text('· 自定义采集：SDK 不使用摄像头，改为从 YUV 文件发送\n· 本地/远端 自定义渲染：SDK 跳过 XComponent 渲染，\n  把 I420 帧回调给 ArkTS，转 RGBA → PixelMap → Image 显示')
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
          // === 本地画面区 ===
          Text('本地画面').fontSize(14).fontColor('#FFFFFF').alignSelf(ItemAlign.Start)

          // 无论是否自定义渲染，始终挂一个 XComponent 给 SDK 作为采集载体。
          // 自定义渲染开启时，SDK 会"跳过原来的渲染流程"，XComponent 就会保持黑屏，
          // 同时把帧回调给我们。我们在它上面盖一层 Image 显示自绘画面。
          Stack() {
            XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
              .width('100%')
              .height(220)
              .backgroundColor('#000000')

            if (this.isLocalCustomRender) {
              if (this.localRenderPixelMap) {
                Image(this.localRenderPixelMap)
                  .width('100%')
                  .height(220)
                  .objectFit(ImageFit.Contain)
                  .backgroundColor('#000000')
              } else {
                Column() {
                  Text('等待本地首帧... ' + this.localRenderStatus)
                    .fontColor('#AAAAAA').fontSize(12).textAlign(TextAlign.Center)
                }
                .width('100%')
                .height(220)
                .backgroundColor('#000000')
                .justifyContent(FlexAlign.Center)
              }
              Text('自定义渲染 · 已收 ' + this.localRenderFrameCount + ' 帧')
                .fontSize(10)
                .fontColor('#00FF88')
                .backgroundColor('#00000088')
                .padding(4)
                .position({ x: 6, y: 6 })
            }
          }
          .width('100%')

          // === 远端画面区 ===
          if (this.remoteStreams.length > 0) {
            Text('远端用户（' + this.remoteStreams.length + '）')
              .fontSize(14).fontColor('#FFFFFF').alignSelf(ItemAlign.Start)

            ForEach(this.remoteStreams, (s: RemoteStreamState) => {
              RemoteStreamView({ stream: s })
            }, (s: RemoteStreamState) => s.userId + '_' + s.streamType)
          }

          // === 控制区 ===
          Column({ space: 12 }) {
            Row() {
              Text('自定义视频采集: ').fontColor('#FFFFFF').fontSize(14).layoutWeight(1)
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

            Row() {
              Text('自定义音频采集: ').fontColor('#FFFFFF').fontSize(14).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.isCustomAudioCapture })
                .onChange((isOn: boolean) => {
                  if (this.isCustomAudioCapture === isOn) {
                    return;
                  }
                  this.isCustomAudioCapture = isOn;
                  this.toggleCustomAudioCapture(isOn);
                })
            }
            .width('100%')

            Row() {
              Text('本地视频自定义渲染: ').fontColor('#FFFFFF').fontSize(14).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.isLocalCustomRender })
                .onChange((isOn: boolean) => {
                  if (this.isLocalCustomRender === isOn) {
                    return;
                  }
                  this.isLocalCustomRender = isOn;
                  this.toggleLocalCustomRender(isOn);
                })
            }
            .width('100%')

            Row() {
              Text('音频数据回调（示例）: ').fontColor('#FFFFFF').fontSize(14).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.isAudioFrameCallbackOn })
                .onChange((isOn: boolean) => {
                  if (this.isAudioFrameCallbackOn === isOn) {
                    return;
                  }
                  this.isAudioFrameCallbackOn = isOn;
                  this.toggleAudioFrameCallback(isOn);
                })
            }
            .width('100%')

            if (this.isAudioFrameCallbackOn) {
              Text('captured=' + this.capturedCnt
                + '  localProc=' + this.localProcessedCnt
                + '\nremoteUser=' + this.remoteUserCnt
                + '  mixedPlay=' + this.mixedPlayCnt)
                .fontSize(11)
                .fontColor('#00DDFF')
                .padding(8)
                .backgroundColor('#222222')
                .borderRadius(6)
                .width('100%')
            }

            Text(this.isCustomCapture ?
              '自定义视频采集已开启 · 已发送 ' + this.frameCount + ' 帧\n' + this.statusText :
              '使用 SDK 内置摄像头采集中...')
              .fontSize(12)
              .fontColor(this.isCustomCapture ? '#00FF00' : '#AAAAAA')
              .padding(10)
              .backgroundColor('#333333')
              .borderRadius(8)
              .width('100%')

            Text(this.isCustomAudioCapture ?
              '自定义音频采集已开启 · 已发送 ' + this.audioFrameCount + ' 帧\n' + this.audioStatusText :
              '使用 SDK 内置麦克风采集中...')
              .fontSize(12)
              .fontColor(this.isCustomAudioCapture ? '#00FF00' : '#AAAAAA')
              .padding(10)
              .backgroundColor('#333333')
              .borderRadius(8)
              .width('100%')
              .width('100%')

            if (this.remoteRenderStatus) {
              Text(this.remoteRenderStatus)
                .fontSize(11).fontColor('#FFAA00').padding(6)
                .backgroundColor('#333333').borderRadius(6).width('100%')
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
      .padding(20)
      .backgroundColor('#1C1D1F')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1D1F')
  }

  // ========== 自定义采集（YUV 文件） ==========
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
        fs.lseek(this.yuvFile.fd, 0);
      }
    } catch (e) {
      console.error(TAG + ' send frame failed: ' + JSON.stringify(e));
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

  // ========== 自定义音频采集（PCM 文件） ==========
  private startSendCustomAudio() {
    if (!this.trtc) {
      return;
    }
    if (this.audioIntervalId !== 0) {
      return;
    }
    try {
      this.pcmFile = fs.openSync(this.pcmFilePath, fs.OpenMode.READ_ONLY);
    } catch (e) {
      this.audioStatusText = '打开 PCM 文件失败: ' + JSON.stringify(e);
      showToast(this.audioStatusText);
      return;
    }
    this.audioStartTime = Date.now();
    this.audioSendedDurationMs = 0;
    // 音频必须按"严格等间隔"投送，否则远端会变调/卡顿/杂音。
    // 不再用 1ms 轮询+时间戳追赶（会造成一次性补多帧），改为直接 20ms 等间隔。
    this.audioIntervalId = setInterval(() => {
      this.processOneAudioFrame();
    }, PCM_FRAME_DURATION_MS);
    this.audioStatusText = '音频采集已启动 · ' + PCM_SAMPLE_RATE + 'Hz/' + PCM_CHANNELS + 'ch';
  }

  private async processOneAudioFrame(): Promise<void> {
    if (!this.trtc || !this.pcmFile) {
      return;
    }
    try {
      const buffer = new ArrayBuffer(PCM_FRAME_SIZE);
      const bytesRead = await fs.read(this.pcmFile.fd, buffer, { length: PCM_FRAME_SIZE });
      if (bytesRead === PCM_FRAME_SIZE) {
        const frame: TRTCAudioFrame = new TRTCAudioFrame();
        frame.data = buffer;
        frame.sampleRate = PCM_SAMPLE_RATE;
        frame.channel = PCM_CHANNELS;
        frame.timestamp = this.trtc.generateCustomPTS();
        frame.extraData = new ArrayBuffer(0);
        this.trtc.sendCustomAudioData(frame);
        this.audioFrameCount++;
        if (this.audioFrameCount % 50 === 0) {
          console.info(TAG + ' sent audio frame #' + this.audioFrameCount
            + ' sr=' + PCM_SAMPLE_RATE + ' ch=' + PCM_CHANNELS
            + ' bytes=' + bytesRead + ' ts=' + frame.timestamp);
        }
      } else if (bytesRead > 0) {
        // 读到不完整帧：回到开头，这一帧不发（避免投不完整数据导致杂音）
        console.info(TAG + ' pcm partial read ' + bytesRead + '/' + PCM_FRAME_SIZE + ', rewind');
        fs.lseek(this.pcmFile.fd, 0);
      } else {
        // EOF：回到开头
        fs.lseek(this.pcmFile.fd, 0);
      }
    } catch (e) {
      console.error(TAG + ' send audio frame failed: ' + JSON.stringify(e));
    }
  }

  private stopSendCustomAudio() {
    if (this.audioIntervalId !== 0) {
      clearInterval(this.audioIntervalId);
      this.audioIntervalId = 0;
    }
    if (this.pcmFile) {
      try {
        fs.closeSync(this.pcmFile);
      } catch (e) { }
      this.pcmFile = null;
    }
  }

  private toggleCustomAudioCapture(enable: boolean) {
    if (!this.trtc) {
      return;
    }
    if (enable) {
      // 顺序很重要：先关掉 SDK 的麦克风采集，再开启自定义采集模式，
      // 最后才开始投送 PCM 帧。否则 SDK 内部的音频通路可能还在走麦克风，
      // 自定义数据塞进去没效果。
      this.trtc.stopLocalAudio();
      this.trtc.enableCustomAudioCapture(true);
      this.audioFrameCount = 0;
      this.startSendCustomAudio();
      showToast('自定义音频采集已开启');
    } else {
      // 关闭自定义采集：先停投送 → 关自定义模式 → 恢复 SDK 麦克风采集
      this.stopSendCustomAudio();
      this.trtc.enableCustomAudioCapture(false);
      this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
      this.audioFrameCount = 0;
      this.audioStatusText = '';
      showToast('已恢复 SDK 麦克风采集');
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
      // 联动：开启自定义采集时，默认同时打开本地自定义渲染
      if (!this.isLocalCustomRender) {
        this.isLocalCustomRender = true;
        this.toggleLocalCustomRender(true);
      }
      // 联动：开启自定义视频采集时，默认同时开启自定义音频采集
      if (!this.isCustomAudioCapture) {
        this.isCustomAudioCapture = true;
        this.toggleCustomAudioCapture(true);
      }
    } else {
      this.stopSendCustomVideo();
      this.trtc.enableCustomVideoCapture(TRTCVideoStreamType.TRTCVideoStreamTypeBig, false);
      this.frameCount = 0;
      this.statusText = '';
      // 恢复 SDK 采集到占位 XComponent
      this.trtc.startLocalPreview(true, this.localViewId);
      showToast('已恢复 SDK 摄像头采集');
      // 联动：关掉自定义采集时，同步关掉本地自定义渲染（恢复 SDK XComponent 渲染）
      if (this.isLocalCustomRender) {
        this.isLocalCustomRender = false;
        this.toggleLocalCustomRender(false);
      }
      // 联动：关掉自定义视频采集时，同步关掉自定义音频采集
      if (this.isCustomAudioCapture) {
        this.isCustomAudioCapture = false;
        this.toggleCustomAudioCapture(false);
      }
    }
  }

  // ========== 音频数据回调示例 ==========
  /**
   * setAudioFrameCallback 注册后，SDK 会把 4 路音频数据回调出来：
   *  - onCapturedAudioFrame：麦克风采集的原始 PCM
   *  - onLocalProcessedAudioFrame：经过 ANS/AEC/AGC/BGM 处理后的本地 PCM
   *  - onRemoteUserAudioFrame：混音前每个远端用户的 PCM
   *  - onMixedPlayAudioFrame：最终系统播放的混音 PCM
   *
   * 本示例仅做计数演示，不在回调里写任何业务逻辑。
   * 如果你想在这些回调里做语音识别/音频录制/自定义音效等，直接填充相应函数体即可。
   *
   * 可选：通过 setCapturedAudioFrameCallbackFormat / setLocalProcessedAudioFrameCallbackFormat /
   * setMixedPlayAudioFrameCallbackFormat 自定义回调的采样率/声道/每次回调的采样点数。
   */
  private toggleAudioFrameCallback(enable: boolean) {
    if (!this.trtc) {
      return;
    }
    if (enable) {
      // 可选：先设置期望的回调数据格式（示例取 48kHz 单声道 20ms 一次）
      //   samplesPerCall = sampleRate * 0.02 = 48000 * 0.02 = 960
      //   mode: ReadOnly（只读，不修改）
      const fmt = new TRTCAudioFrameCallbackFormat();
      fmt.sampleRate = 48000;
      fmt.channel = 1;
      fmt.samplesPerCall = 960;
      fmt.mode = TRTCAudioFrameOperationMode.TRTCAudioFrameOperationModeReadOnly;
      const r1 = this.trtc.setCapturedAudioFrameCallbackFormat(fmt);
      const r2 = this.trtc.setLocalProcessedAudioFrameCallbackFormat(fmt);
      const r3 = this.trtc.setMixedPlayAudioFrameCallbackFormat(fmt);
      console.info(TAG + ' setXxxAudioFrameCallbackFormat ret=' + r1 + '/' + r2 + '/' + r3);

      const cb: ITRTCAudioFrameCallback = {
        // ---- 示例：只计数，不写业务逻辑 ----
        onCapturedAudioFrame: (frame: TRTCAudioFrame) => {
          this.capturedCnt++;
          // 如果你想处理：frame.data 是 PCM 的 ArrayBuffer，可以读/写
          //   const pcm = new Int16Array(frame.data);
          //   ... 你的业务 ...
        },
        onLocalProcessedAudioFrame: (frame: TRTCAudioFrame) => {
          this.localProcessedCnt++;
        },
        onRemoteUserAudioFrame: (frame: TRTCAudioFrame, userId: string) => {
          this.remoteUserCnt++;
          // userId 告诉你这一路是哪个远端用户的
        },
        onMixedPlayAudioFrame: (frame: TRTCAudioFrame) => {
          this.mixedPlayCnt++;
        }
      };
      this.trtc.setAudioFrameCallback(cb);
      showToast('音频数据回调已开启');
    } else {
      this.trtc.setAudioFrameCallback(null);
      this.capturedCnt = 0;
      this.localProcessedCnt = 0;
      this.remoteUserCnt = 0;
      this.mixedPlayCnt = 0;
      showToast('音频数据回调已关闭');
    }
  }

  // ========== 本地视频自定义渲染 ==========
  private toggleLocalCustomRender(enable: boolean) {
    if (!this.trtc) {
      return;
    }
    if (enable) {
      // 关键：不调 stopLocalPreview（那会关摄像头）。
      // SDK 文档：设置回调后，"SDK 内部会跳过原来的渲染流程，并把采集到的数据回调出来"。
      // XComponent 继续挂在 UI 上让 SDK 有渲染目标（但跳过渲染后会保持黑屏/不更新）。
      const cb: ITRTCVideoRenderCallback = {
        onRenderVideoFrame: (userId: string, streamType: TRTCVideoStreamType, frame: TRTCVideoFrame) => {
          console.info(TAG + ' local onRenderVideoFrame w=' + frame.width + ' h=' + frame.height
            + ' fmt=' + frame.videoFormat + ' buf=' + frame.bufferType
            + ' dataLen=' + (frame.data ? frame.data.byteLength : -1));
          this.onLocalRenderFrame(frame);
        }
      };
      const ret = this.trtc.setLocalVideoRenderCallback(
        TRTCVideoPixelFormat.TRTCVideoPixelFormat_I420,
        TRTCVideoBufferType.TRTCVideoBufferType_Buffer,
        cb
      );
      console.info(TAG + ' setLocalVideoRenderCallback ret=' + ret);
      if (ret !== 0) {
        this.localRenderStatus = '注册失败 ret=' + ret;
        showToast('本地自定义渲染注册失败: ' + ret);
      } else {
        this.localRenderStatus = '已注册，等待首帧...';
        showToast('本地自定义渲染已开启');
      }
    } else {
      this.trtc.setLocalVideoRenderCallback(
        TRTCVideoPixelFormat.TRTCVideoPixelFormat_Unknown,
        TRTCVideoBufferType.TRTCVideoBufferType_Unknown,
        null
      );
      this.localRenderPixelMap = null;
      this.localRenderFrameCount = 0;
      this.localRenderStatus = '';
      showToast('本地自定义渲染已关闭');
    }
  }

  private async onLocalRenderFrame(frame: TRTCVideoFrame): Promise<void> {
    const now = Date.now();
    if (now - this.lastLocalRenderTs < this.RENDER_INTERVAL_MS) {
      return;
    }
    if (this.localBusy) {
      return; // 背压：上一帧还没转完，当前帧丢弃
    }
    this.lastLocalRenderTs = now;
    this.localBusy = true;
    try {
      const pm = await this.buildPixelMapFromFrame(frame);
      if (pm) {
        // 释放上一帧，避免 native 内存堆积
        const old = this.localRenderPixelMap;
        this.localRenderPixelMap = pm;
        this.localRenderFrameCount++;
        this.localRenderStatus = '';
        if (old) {
          old.release().catch((e: Object) => {
            console.warn(TAG + ' local old pixelMap release failed: ' + JSON.stringify(e));
          });
        }
      } else {
        this.localRenderStatus = 'PixelMap 构建失败（看日志）';
      }
    } finally {
      this.localBusy = false;
    }
  }

  // ========== 远端视频自定义渲染（强制开启，无 Toggle）==========
  /**
   * 注册远端自定义渲染回调。
   * 此方法应在 onFirstVideoFrame 之后调用，确保 SDK 解码管线已启动。
   */
  private registerRemoteRenderCallback(userId: string, streamType: TRTCVideoStreamType): number {
    if (!this.trtc) {
      return -1;
    }
    console.info(TAG + ' [R4] registerRemoteRenderCallback uid=' + userId);

    let frameCbHit = 0;
    const cb: ITRTCVideoRenderCallback = {
      onRenderVideoFrame: (uid: string, st: TRTCVideoStreamType, frame: TRTCVideoFrame) => {
        frameCbHit++;
        // 只打印前 3 帧 + 每 60 帧一条，避免刷屏
        if (frameCbHit <= 3 || frameCbHit % 60 === 0) {
          console.info(TAG + ' [R6] remote[' + uid + '] onRenderVideoFrame #' + frameCbHit
            + ' w=' + frame.width + ' h=' + frame.height
            + ' fmt=' + frame.videoFormat + ' dataLen=' + (frame.data ? frame.data.byteLength : -1));
        }
        this.onRemoteRenderFrame(uid, st, frame);
      }
    };

    const ret = this.trtc.setRemoteVideoRenderCallback(
      userId,
      TRTCVideoPixelFormat.TRTCVideoPixelFormat_I420,
      TRTCVideoBufferType.TRTCVideoBufferType_Buffer,
      cb
    );
    console.info(TAG + ' [R5] setRemoteVideoRenderCallback uid=' + userId + ' ret=' + ret);

    if (ret !== 0) {
      console.error(TAG + ' [R5x] setRemoteVideoRenderCallback failed ret=' + ret);
      this.remoteRenderStatus = '远端[' + userId + ']回调注册失败 ret=' + ret;
    }

    // 5 秒后检查一下有没有帧进来
    setTimeout(() => {
      if (frameCbHit === 0) {
        console.warn(TAG + ' [R7!] uid=' + userId + ' got ZERO render callbacks in 5s');
        this.remoteRenderStatus = '远端[' + userId + ']5秒无渲染帧';
      } else {
        console.info(TAG + ' [R7] uid=' + userId + ' got ' + frameCbHit + ' render callbacks in 5s, OK');
      }
    }, 5000);

    return ret;
  }

  private async onRemoteRenderFrame(userId: string, streamType: TRTCVideoStreamType, frame: TRTCVideoFrame): Promise<void> {
    const now = Date.now();
    const key = userId + '_' + streamType;
    const last = this.lastRemoteRenderTs.get(key) || 0;
    if (now - last < this.RENDER_INTERVAL_MS) {
      return;
    }
    if (this.remoteBusy.get(key)) {
      console.info(TAG + ' [R7] remote busy, skip frame for uid=' + userId);
      return; // 背压
    }
    this.lastRemoteRenderTs.set(key, now);
    this.remoteBusy.set(key, true);

    console.info(TAG + ' [R7.1] onRemoteRenderFrame processing uid=' + userId + ' w=' + frame.width + ' h=' + frame.height);

    try {
      console.info(TAG + ' [R7.2] building PixelMap...');
      const pm = await this.buildPixelMapFromFrame(frame);
      if (!pm) {
        console.warn(TAG + ' [R8x] buildPixelMap NULL for uid=' + userId);
        return;
      }
      console.info(TAG + ' [R7.3] PixelMap built successfully');

      const idx = this.remoteStreams.findIndex((s) => s.userId === userId && s.streamType === streamType);
      if (idx < 0) {
        console.warn(TAG + ' [R8y] remote stream not found in list, uid=' + userId + ', dropping pixelMap');
        pm.release().catch(() => {});
        return;
      }
      const s = this.remoteStreams[idx];
      const old = s.pixelMap;
      
      // @Observed 对象直接修改属性即可触发 @ObjectLink 子组件刷新
      s.pixelMap = pm;
      s.width = frame.width;
      s.height = frame.height;
      s.frameCount++;
      
      if (s.frameCount === 1) {
        console.info(TAG + ' [R8] first UI frame committed for uid=' + userId);
      }
      console.info(TAG + ' [R7.4] remoteStreams updated, frameCount=' + s.frameCount);

      if (old) {
        old.release().catch((e: Object) => {
          console.warn(TAG + ' old pixelMap release failed: ' + JSON.stringify(e));
        });
      }
    } catch (e) {
      console.error(TAG + ' [R7x] onRemoteRenderFrame exception: ' + JSON.stringify(e));
    } finally {
      this.remoteBusy.set(key, false);
    }
  }

  // ========== I420 → NV12 → PixelMap（走系统 native 色彩转换，JS 不做 RGB 运算）==========
  private async buildPixelMapFromFrame(frame: TRTCVideoFrame): Promise<PixelMap | null> {
    try {
      const w = frame.width;
      const h = frame.height;
      console.info(TAG + ' [PM1] buildPixelMapFromFrame w=' + w + ' h=' + h + ' dataLen=' + (frame.data ? frame.data.byteLength : -1));

      if (w <= 0 || h <= 0 || !frame.data) {
        console.warn(TAG + ' [PM2x] invalid frame dims w=' + w + ' h=' + h);
        return null;
      }
      const expected = w * h * 3 / 2;
      if (frame.data.byteLength < expected) {
        console.warn(TAG + ' [PM3x] frame data too small: got=' + frame.data.byteLength + ' expected=' + expected);
        return null;
      }

      console.info(TAG + ' [PM2] converting I420 to NV12...');
      // I420（Y + U plane + V plane）→ NV12（Y + UV 交错），让 HarmonyOS native 做 YUV→RGB
      const nv12 = this.i420ToNV12(new Uint8Array(frame.data), w, h);
      console.info(TAG + ' [PM3] NV12 buffer size=' + nv12.byteLength);

      // 关键：srcPixelFormat 告诉系统 buffer 真实格式是 NV12（9）；
      // pixelFormat 指定目标 RGBA_8888（3），Image 组件显示友好。
      const opts: image.InitializationOptions = {
        size: { width: w, height: h },
        srcPixelFormat: 9,  // NV12
        pixelFormat: 3,     // RGBA_8888
        editable: false,
        alphaType: 1        // OPAQUE
      };
      console.info(TAG + ' [PM4] creating PixelMap with opts=' + JSON.stringify(opts));
      const pm = await image.createPixelMap(nv12.buffer as ArrayBuffer, opts);
      console.info(TAG + ' [PM5] PixelMap created: ' + (pm ? 'OK' : 'NULL'));
      return pm;
    } catch (e) {
      console.error(TAG + ' [PMx] buildPixelMap failed: ' + JSON.stringify(e));
      return null;
    }
  }

  /**
   * I420（YYYY... UUUU... VVVV...）→ NV12（YYYY... UVUVUV...）
   * Y plane 直接 memcpy，UV plane 按字节交错（U 在前 V 在后）。
   */
  private i420ToNV12(i420: Uint8Array, w: number, h: number): Uint8Array {
    const ySize = w * h;
    const uvCount = (w >> 1) * (h >> 1);
    const out = new Uint8Array(ySize + uvCount * 2);
    // Y plane
    out.set(i420.subarray(0, ySize), 0);
    // UV 交错
    const uStart = ySize;
    const vStart = ySize + uvCount;
    const outUV = ySize;
    for (let i = 0; i < uvCount; i++) {
      out[outUV + i * 2] = i420[uStart + i];
      out[outUV + i * 2 + 1] = i420[vStart + i];
    }
    return out;
  }

  // ========== 进房/退房 ==========
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
            // 不管是否开启自定义渲染，都要调 startLocalPreview 让 SDK 采摄像头
            this.trtc?.startLocalPreview(true, this.localViewId);
          }, 100);
        } else {
          showToast('进房失败: ' + result);
          this.isInRoom = false;
        }
      },
      onUserVideoAvailable: (remoteUid: string, available: number) => {
        console.info(TAG + ' onUserVideoAvailable uid=' + remoteUid + ' available=' + available);
        if (available) {
          this.addRemoteStream(remoteUid, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
        } else {
          this.removeRemoteStream(remoteUid, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
        }
      },
      onRemoteUserLeaveRoom: (remoteUid: string, reason: number) => {
        console.info(TAG + ' onRemoteUserLeaveRoom uid=' + remoteUid);
        this.removeRemoteStream(remoteUid, TRTCVideoStreamType.TRTCVideoStreamTypeBig);
      },
      onFirstVideoFrame: (uid: string, streamType: TRTCVideoStreamType, w: number, h: number) => {
        // 仅打日志，远端自定义渲染不依赖此回调
        console.info(TAG + ' onFirstVideoFrame uid=' + uid + ' st=' + streamType + ' ' + w + 'x' + h);
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneVideoCall);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualitySpeech);
    this.isInRoom = true;
  }

  private addRemoteStream(userId: string, streamType: TRTCVideoStreamType) {
    const exist = this.remoteStreams.find((s) => s.userId === userId && s.streamType === streamType);
    if (exist) {
      console.info(TAG + ' [R1] addRemoteStream: uid=' + userId + ' already exists, skip');
      return;
    }
    const s = new RemoteStreamState(userId, streamType);
    this.remoteStreams.push(s);
    this.remoteStreams = this.remoteStreams.slice();
    console.info(TAG + ' [R1] addRemoteStream uid=' + userId + ' streams.length=' + this.remoteStreams.length);

    // 远端自定义渲染流程（不依赖 onFirstVideoFrame）：
    // 1. 先注册自定义渲染回调
    // 2. 再调用 startRemoteView（view 设为空字符串，让 SDK 只解码不渲染）
    // 3. 渲染帧会直接通过回调输出
    setTimeout(() => {
      console.info(TAG + ' [R2] after 300ms, setup remote custom render for uid=' + userId);

      // 第一步：先注册自定义渲染回调
      console.info(TAG + ' [R2.1] registering custom render callback...');
      const ret = this.registerRemoteRenderCallback(userId, streamType);
      console.info(TAG + ' [R2.2] registerRemoteRenderCallback ret=' + ret);

      // 第二步：再调用 startRemoteView（view 为空，触发解码但不走 SDK 渲染）
      try {
        this.trtc?.startRemoteView(userId, streamType, '');
        console.info(TAG + ' [R2.3] startRemoteView ok (empty view)');
        this.remoteRenderStatus = '等待 ' + userId + ' 视频帧回调...';
      } catch (e) {
        console.error(TAG + ' [R2x] startRemoteView failed: ' + JSON.stringify(e));
        this.remoteRenderStatus = 'startRemoteView 失败: ' + JSON.stringify(e);
      }
    }, 300);
  }

  private removeRemoteStream(userId: string, streamType: TRTCVideoStreamType) {
    const idx = this.remoteStreams.findIndex((s) => s.userId === userId && s.streamType === streamType);
    if (idx < 0) {
      return;
    }
    const key = userId + '_' + streamType;
    this.trtc?.setRemoteVideoRenderCallback(
      userId,
      TRTCVideoPixelFormat.TRTCVideoPixelFormat_Unknown,
      TRTCVideoBufferType.TRTCVideoBufferType_Unknown,
      null
    );
    this.trtc?.stopRemoteView(userId, streamType);
    this.lastRemoteRenderTs.delete(key);
    this.remoteBusy.delete(key);
    // 释放该用户的 pixelMap
    const gone = this.remoteStreams[idx];
    if (gone && gone.pixelMap) {
      gone.pixelMap.release().catch(() => {});
    }
    this.remoteStreams.splice(idx, 1);
    this.remoteStreams = this.remoteStreams.slice();
  }

  private exitRoom() {
    this.stopSendCustomVideo();
    this.stopSendCustomAudio();

    if (this.isLocalCustomRender) {
      this.trtc?.setLocalVideoRenderCallback(
        TRTCVideoPixelFormat.TRTCVideoPixelFormat_Unknown,
        TRTCVideoBufferType.TRTCVideoBufferType_Unknown,
        null
      );
      this.isLocalCustomRender = false;
      if (this.localRenderPixelMap) {
        this.localRenderPixelMap.release().catch(() => {});
      }
      this.localRenderPixelMap = null;
      this.localRenderFrameCount = 0;
      this.localRenderStatus = '';
    }

    for (const s of this.remoteStreams) {
      this.trtc?.setRemoteVideoRenderCallback(
        s.userId,
        TRTCVideoPixelFormat.TRTCVideoPixelFormat_Unknown,
        TRTCVideoBufferType.TRTCVideoBufferType_Unknown,
        null
      );
      this.trtc?.stopRemoteView(s.userId, s.streamType);
      if (s.pixelMap) {
        s.pixelMap.release().catch(() => {});
        s.pixelMap = null;
      }
    }
    this.remoteStreams = [];
    this.remoteRenderStatus = '';
    this.lastRemoteRenderTs.clear();
    this.remoteBusy.clear();
    this.localBusy = false;

    if (this.isCustomCapture) {
      this.trtc?.enableCustomVideoCapture(TRTCVideoStreamType.TRTCVideoStreamTypeBig, false);
      this.isCustomCapture = false;
    }
    if (this.isCustomAudioCapture) {
      this.trtc?.enableCustomAudioCapture(false);
      this.isCustomAudioCapture = false;
    }
    if (this.isAudioFrameCallbackOn) {
      this.trtc?.setAudioFrameCallback(null);
      this.isAudioFrameCallbackOn = false;
      this.capturedCnt = 0;
      this.localProcessedCnt = 0;
      this.remoteUserCnt = 0;
      this.mixedPlayCnt = 0;
    }
    this.trtc?.stopLocalPreview();
    this.trtc?.stopLocalAudio();
    BackgroundRunningHelper.stop();
    this.trtc?.exitRoom();
    destroyTRTCShareInstance();
    this.trtc = null;
    this.isInRoom = false;
    this.frameCount = 0;
    this.audioFrameCount = 0;
    this.audioStatusText = '';
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
