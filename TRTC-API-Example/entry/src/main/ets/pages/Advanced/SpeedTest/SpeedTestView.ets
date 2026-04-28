import router from '@ohos.router';
import {
  getTRTCShareInstance,
  destroyTRTCShareInstance,
  TRTCCloud,
  TRTCCloudCallback,
  TRTCSpeedTestParams,
  TRTCSpeedTestResult
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';

@Entry
@Component
struct SpeedTestView {
  @State userId: string = generateUserId();
  @State isTesting: boolean = false;
  @State resultText: string = '';
  @State statusText: string = '点击按钮开始测速';
  private trtc: TRTCCloud | null = null;

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('\u2190')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.isTesting) {
              this.stopTest();
            }
            router.back();
          })
        Text('Speed Test')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      Column({ space: 15 }) {
        Text('网络测速（不需要进入房间）')
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

        Button(this.isTesting ? '停止测速' : '开始测速')
          .width('80%')
          .height(44)
          .backgroundColor(this.isTesting ? '#FF4444' : '#006EFF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (this.isTesting) {
              this.stopTest();
            } else {
              this.startTest();
            }
          })

        Text(this.statusText)
          .fontSize(14)
          .fontColor('#FFAA00')

        Scroll() {
          Text(this.resultText)
            .fontSize(12)
            .fontColor('#CCCCCC')
            .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding(10)
      }
      .width('100%')
      .layoutWeight(1)
      .padding(10)
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }

  private startTest() {
    if (!this.userId) {
      showToast('请填写用户ID');
      return;
    }
    this.trtc = getTRTCShareInstance(getContext());
    let info = genTestUserSig(this.userId);

    let callback: TRTCCloudCallback = {
      onSpeedTestResult: (result: TRTCSpeedTestResult) => {
        let text = `\n--- 测速结果 ---\n`;
        if (result) {
          text += `上行丢包率: ${result.upLostRate ?? 'N/A'}%\n`;
          text += `下行丢包率: ${result.downLostRate ?? 'N/A'}%\n`;
          text += `RTT延迟: ${result.rtt ?? 'N/A'}ms\n`;
          text += `上行带宽: ${result.availableUpBandwidth ?? 'N/A'}kbps\n`;
          text += `下行带宽: ${result.availableDownBandwidth ?? 'N/A'}kbps\n`;
          text += `服务器IP: ${result.ip ?? 'N/A'}\n`;
          text += `网络质量: ${result.quality ?? 'N/A'}\n`;
        }
        this.resultText += text;
      },
    };
    this.trtc.addCallback(callback);

    let params = new TRTCSpeedTestParams();
    params.sdkAppId = info.sdkappid;
    params.userId = this.userId;
    params.userSig = info.userSig;

    this.resultText = '开始测速...\n';
    this.statusText = '测速中...';
    this.trtc.startSpeedTest(params);
    this.isTesting = true;
  }

  private stopTest() {
    this.trtc?.stopSpeedTest();
    this.statusText = '测速已停止';
    this.isTesting = false;
    destroyTRTCShareInstance();
    this.trtc = null;
  }

  aboutToDisappear() {
    if (this.isTesting) {
      this.stopTest();
    }
  }

  onBackPress(): boolean | void {
    if (this.isTesting) {
      this.stopTest();
    }
  }
}
