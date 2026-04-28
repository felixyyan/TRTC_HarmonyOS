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
  TRTCPublishMode,
  TRTCPublishTarget,
  TRTCPublishCdnUrl,
  TRTCStreamEncoderParam,
  TRTCStreamMixingConfig
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

/**
 * CDN 推流 - 主播页
 *
 * 鸿蒙 SDK 没有 Android 的旧 API onStartPublishing/onStopPublishing，
 * 必须用 startPublishMediaStream 并提供：
 *   - TRTCPublishTarget: mode + cdnUrlList（必填，之前没填导致推失败）
 *   - TRTCStreamEncoderParam: 视频/音频编码参数
 *
 * 推流状态回调：
 *   - onStartPublishMediaStream   请求接单结果（返回 taskId）
 *   - onCdnStreamStateChanged     CDN 链路状态（status=2 才是真推流成功）
 *   - onStopPublishMediaStream    停止结果
 */

// ⚠️ 使用前请到 腾讯云控制台 TRTC/CSS -> 域名管理 查看 你自己的【推流域名】
// 示例："push.example.com"。没有配域名时可先留空字符串走 TRTC 默认线路
const PUSH_DOMAIN: string = '';

@Entry
@Component
struct PushCDNAnchorView {
  @State userId: string = '';
  @State roomId: string = '';
  @State isInRoom: boolean = false;
  @State isPublishing: boolean = false;
  @State streamId: string = '';
  @State cdnUrl: string = '';
  @State publishTaskId: string = '';
  @State publishStatusText: string = '未推流';
  @State publishStatusColor: string = '#AAAAAA';
  @State cdnStatusLog: string = '';
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'pushCDNAnchorLocalView';

  aboutToAppear() {
    let params = router.getParams() as Record<string, string>;
    if (params) {
      this.userId = params['userId'] ?? '';
      this.roomId = params['roomId'] ?? '';
    }
    if (!this.streamId) {
      this.streamId = this.userId + '_main';
    }
    this.refreshCdnUrl();
  }

  private refreshCdnUrl() {
    if (PUSH_DOMAIN) {
      this.cdnUrl = 'rtmp://' + PUSH_DOMAIN + '/live/' + this.streamId;
    } else {
      this.cdnUrl = '';
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
        Text('CDN推流 - 主播')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      XComponent({ id: this.localViewId, type: XComponentType.SURFACE, libraryname: 'liteavsdk' })
        .width('100%')
        .height(260)
        .backgroundColor('#000000')

      Column({ space: 10 }) {
        Text('用户: ' + this.userId + '  房间: ' + this.roomId)
          .fontSize(14)
          .fontColor('#CCCCCC')

        Row() {
          Text('StreamID: ').fontColor('#FFFFFF').fontSize(14).width(80)
          TextInput({ text: this.streamId, placeholder: '字母+数字' })
            .width('60%')
            .height(40)
            .backgroundColor('#FFFFFF')
            .fontColor('#333333')
            .enabled(!this.isPublishing)
            .onChange((value: string) => {
              this.streamId = value;
              this.refreshCdnUrl();
            })
        }.width('100%')

        Row() {
          Text('推流地址: ').fontColor('#FFFFFF').fontSize(14).width(80)
          TextInput({ text: this.cdnUrl, placeholder: 'rtmp://推流域名/live/streamid' })
            .width('60%')
            .height(40)
            .backgroundColor('#FFFFFF')
            .fontColor('#333333')
            .enabled(!this.isPublishing)
            .onChange((value: string) => {
              this.cdnUrl = value;
            })
        }.width('100%')

        Text('拉流地址: https://<播放域名>/live/' + this.streamId + '.flv')
          .fontSize(11)
          .fontColor('#888888')

        if (!this.isInRoom) {
          Button('进入房间')
            .width('80%')
            .height(44)
            .backgroundColor('#006EFF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.enterRoom();
            })
        }

        if (this.isInRoom) {
          Button(this.isPublishing ? '停止CDN推流' : '开始CDN推流')
            .width('80%')
            .height(44)
            .backgroundColor(this.isPublishing ? '#FF4444' : '#00AA00')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.togglePublishing();
            })

          // 状态展示
          Column({ space: 6 }) {
            Text('推流状态：' + this.publishStatusText)
              .fontSize(14)
              .fontColor(this.publishStatusColor)
              .fontWeight(FontWeight.Bold)
            if (this.publishTaskId) {
              Text('TaskID: ' + this.publishTaskId)
                .fontSize(11)
                .fontColor('#888888')
            }
            if (this.cdnStatusLog) {
              Text(this.cdnStatusLog)
                .fontSize(11)
                .fontColor('#CCCCCC')
                .width('100%')
                .textAlign(TextAlign.Start)
            }
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#2A2B2E')
          .borderRadius(8)

          Button('退出房间')
            .width('80%')
            .height(44)
            .backgroundColor('#FF4444')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.exitRoom();
            })
        }
      }
      .width('100%')
      .padding(10)
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }

  private appendLog(line: string) {
    let ts = new Date().toLocaleTimeString();
    let lines = ('[' + ts + '] ' + line + '\n' + this.cdnStatusLog).split('\n');
    if (lines.length > 5) {
      lines = lines.slice(0, 5);
    }
    this.cdnStatusLog = lines.join('\n');
    console.info('[PushCDN] ' + line);
  }

  private togglePublishing() {
    if (!this.trtc) {
      return;
    }
    if (this.isPublishing) {
      if (this.publishTaskId) {
        this.trtc.stopPublishMediaStream(this.publishTaskId);
      }
      this.isPublishing = false;
      this.publishStatusText = '停止中...';
      this.publishStatusColor = '#FFAA00';
      return;
    }
    if (!this.streamId) {
      showToast('请输入 StreamID');
      return;
    }
    if (!this.cdnUrl) {
      showToast('请填写完整的 rtmp 推流地址');
      return;
    }

    // 1. 构造 TRTCPublishTarget —— mode + cdnUrlList（这是之前推失败的主因，之前 cdnUrlList 为空）
    let target: TRTCPublishTarget = new TRTCPublishTarget();
    target.mode = TRTCPublishMode.TRTCPublishBigStreamToCdn; // 主路视频转推 CDN
    let cdn: TRTCPublishCdnUrl = new TRTCPublishCdnUrl();
    cdn.rtmpUrl = this.cdnUrl;
    cdn.isInternalLine = false;
    target.cdnUrlList = [cdn];

    // 2. 构造 TRTCStreamEncoderParam —— 即使 BigStreamToCdn 模式也建议填
    let encParam: TRTCStreamEncoderParam = new TRTCStreamEncoderParam();
    encParam.videoEncodedWidth = 720;
    encParam.videoEncodedHeight = 1280;
    encParam.videoEncodedFPS = 15;
    encParam.videoEncodedGOP = 2;
    encParam.videoEncodedKbps = 1500;
    encParam.audioEncodedSampleRate = 48000;
    encParam.audioEncodedChannelNum = 2;
    encParam.audioEncodedKbps = 64;
    encParam.audioEncodedCodecType = 2; // 2=AAC

    // 3. 单流转推模式下 mixConfig 无效，但 SDK Native 层要求必须是 TRTCStreamMixingConfig 实例，不能传 null
    let mixConfig: TRTCStreamMixingConfig = new TRTCStreamMixingConfig();
    this.trtc.startPublishMediaStream(target, encParam, mixConfig);
    this.isPublishing = true;
    this.publishStatusText = '请求中...';
    this.publishStatusColor = '#FFAA00';
    this.cdnStatusLog = '';
    this.appendLog('调用 startPublishMediaStream, url=' + this.cdnUrl);
  }

  private enterRoom() {
    if (!this.userId || !this.roomId) {
      showToast('请先填写用户ID和房间号');
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
          showToast('进房成功，可以点击开始CDN推流');
          this.appendLog('onEnterRoom ok ' + result + 'ms');
        } else {
          showToast('进房失败: ' + result);
          this.publishStatusText = '进房失败: ' + result;
          this.publishStatusColor = '#FF4444';
          this.isInRoom = false;
        }
      },
      onExitRoom: (reason: number) => {
        this.appendLog('onExitRoom reason=' + reason);
      },
      // 推流请求提交到 TRTC 后台的结果（首次回调）
      onStartPublishMediaStream: (taskId: string, code: number, message: string,
                                  extraInfo: Record<string, number | string>) => {
        this.publishTaskId = taskId;
        if (code === 0) {
          this.publishStatusText = '已提交到后台，等待 CDN 握手...';
          this.publishStatusColor = '#FFAA00';
          this.appendLog('onStartPublishMediaStream code=0 taskId=' + taskId);
        } else {
          this.publishStatusText = '❌ 推流启动失败 code=' + code + ' ' + message;
          this.publishStatusColor = '#FF4444';
          this.isPublishing = false;
          this.appendLog('onStartPublishMediaStream code=' + code + ' msg=' + message);
          showToast('推流启动失败: ' + message);
        }
      },
      // CDN 链路运行态 —— status=2 才是真正推流成功
      onCdnStreamStateChanged: (cdnUrl: string, status: number, code: number,
                                msg: string, extraInfo: Record<string, number | string>) => {
        let statusDesc = '';
        let color = '#CCCCCC';
        switch (status) {
          case 0: statusDesc = '未开始/已结束'; color = '#AAAAAA'; break;
          case 1: statusDesc = '连接中...'; color = '#FFAA00'; break;
          case 2: statusDesc = '✅ 推流成功（CDN 已就绪）'; color = '#00FF00'; break;
          case 3: statusDesc = '推流中断，正在重连'; color = '#FFAA00'; break;
          case 4: statusDesc = '❌ 推流失败（重连超时）'; color = '#FF4444'; break;
          case 5: statusDesc = '正在断开'; color = '#FFAA00'; break;
          default: statusDesc = '未知状态 ' + status; color = '#FF4444';
        }
        this.publishStatusText = statusDesc + (code !== 0 ? ' (code=' + code + ')' : '');
        this.publishStatusColor = color;
        this.appendLog('CDN[' + cdnUrl + '] status=' + status + ' code=' + code + ' msg=' + msg);
      },
      onStopPublishMediaStream: (taskId: string, code: number, message: string,
                                 extraInfo: Record<string, number | string>) => {
        this.publishStatusText = code === 0 ? '推流已停止' : '停止失败 code=' + code;
        this.publishStatusColor = code === 0 ? '#AAAAAA' : '#FF4444';
        this.publishTaskId = '';
        this.appendLog('onStopPublishMediaStream code=' + code);
      },
      onError: (errCode: number, errMsg: string) => {
        this.appendLog('onError code=' + errCode + ' msg=' + errMsg);
      }
    };
    this.trtc.addCallback(callback);
    BackgroundRunningHelper.start();
    this.trtc.enterRoom(params, TRTCAppScene.TRTCAppSceneLIVE);
    this.trtc.startLocalPreview(true, this.localViewId);
    this.trtc.startLocalAudio(TRTCAudioQuality.TRTCAudioQualityDefault);
    this.isInRoom = true;
  }

  private exitRoom() {
    if (this.isPublishing && this.publishTaskId) {
      this.trtc?.stopPublishMediaStream(this.publishTaskId);
      this.isPublishing = false;
    }
    this.trtc?.stopLocalPreview();
    this.trtc?.stopLocalAudio();
    BackgroundRunningHelper.stop();
    this.trtc?.exitRoom();
    destroyTRTCShareInstance();
    this.trtc = null;
    this.isInRoom = false;
    this.publishTaskId = '';
    this.publishStatusText = '未推流';
    this.publishStatusColor = '#AAAAAA';
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
