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
  TRTCLocalRecordingParams,
  TRTCLocalRecordType
} from '@tencentcloud/liteavsdk_trtc';
import genTestUserSig from '../../../debug/gen-test-user-sig';
import { showToast, generateUserId } from '../../../common/TRTCUtils';
import { BackgroundRunningHelper } from '../../../common/BackgroundRunningHelper';

@Entry
@Component
struct LocalRecordView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';
  @State isInRoom: boolean = false;
  @State isRecording: boolean = false;
  @State recordingStatus: string = '';
  @State recordFilePath: string = '';
  private trtc: TRTCCloud | null = null;
  private localViewId: string = 'localRecordLocalView';

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
        Text('Local Record')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      if (!this.isInRoom) {
        Column({ space: 15 }) {
          Text('本地音视频录制演示')
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

        Column({ space: 12 }) {
          Button(this.isRecording ? '停止录制' : '开始录制')
            .width('80%')
            .height(44)
            .backgroundColor(this.isRecording ? '#FF4444' : '#00AA00')
            .fontColor('#FFFFFF')
            .onClick(() => {
              if (this.isRecording) {
                this.stopRecording();
              } else {
                this.startRecording();
              }
            })

          if (this.isRecording) {
            Text('录制中...')
              .fontSize(14)
              .fontColor('#FF4444')
          }

          if (this.recordingStatus) {
            Text(this.recordingStatus)
              .fontSize(12)
              .fontColor('#CCCCCC')
              .padding(10)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .width('100%')
          }

          if (this.recordFilePath) {
            Text('录制文件: ' + this.recordFilePath)
              .fontSize(12)
              .fontColor('#00FF00')
              .padding(10)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .width('100%')
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
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }

  private startRecording() {
    if (!this.trtc) {
      return;
    }
    let filePath = getContext().getApplicationContext().filesDir + '/trtc_record_' + Date.now() + '.mp4';
    let recordParams: TRTCLocalRecordingParams = new TRTCLocalRecordingParams();
    recordParams.filePath = filePath;
    recordParams.recordType = TRTCLocalRecordType.TRTCRecordTypeBoth;
    recordParams.interval = 5000;
    recordParams.maxDurationPerFile = 60000;
    this.trtc.startLocalRecording(recordParams);
    this.isRecording = true;
    this.recordFilePath = filePath;
    this.recordingStatus = '正在录制...';
    showToast('开始录制');
  }

  private stopRecording() {
    if (!this.trtc) {
      return;
    }
    this.trtc.stopLocalRecording();
    this.isRecording = false;
    this.recordingStatus = '录制已停止';
    showToast('录制已停止');
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
      },
      onLocalRecordBegin: (errCode: number, storagePath: string) => {
        if (errCode === 0) {
          this.recordingStatus = '录制开始: ' + storagePath;
        } else {
          this.recordingStatus = '录制开始失败: ' + errCode;
          this.isRecording = false;
        }
      },
      onLocalRecording: (duration: number, storagePath: string) => {
        this.recordingStatus = '录制中... 时长: ' + Math.floor(duration / 1000) + '秒';
      },
      onLocalRecordComplete: (errCode: number, storagePath: string) => {
        this.recordingStatus = '录制完成: ' + storagePath;
        this.isRecording = false;
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
    if (this.isRecording) {
      this.stopRecording();
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
