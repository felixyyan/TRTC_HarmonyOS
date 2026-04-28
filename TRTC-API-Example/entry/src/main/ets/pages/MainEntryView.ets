import router from '@ohos.router';
import { getV2TXLivePremierShareInstance } from '@tencentcloud/liteavsdk_trtc';

interface DemoItem {
  title: string;
  desc?: string;
  route: string;
}

const BASIC_ITEMS: DemoItem[] = [
  { title: '语音通话', desc: '双人/多人语音通话，包含静音/免提等功能', route: 'pages/Basic/AudioCall/AudioCallingEnterView' },
  { title: '视频通话', desc: '双人/多人视频通话，包含静音/免提等功能', route: 'pages/Basic/VideoCall/VideoCallingEnterView' },
  { title: '视频互动直播', desc: '支持主播/观众角色进入房间', route: 'pages/Basic/Live/LiveEnterView' },
  { title: '语音互动直播', desc: '支持主播/观众角色进入语音聊天室', route: 'pages/Basic/VoiceChatRoom/VoiceChatRoomEnterView' },
  { title: '录屏直播', desc: '直播过程中分享屏幕，适用于在线教育、游戏直播等场景', route: 'pages/Basic/ScreenShare/ScreenShareEnterView' },
];

const ADVANCED_ITEMS: DemoItem[] = [
  { title: '字符串房间号', route: 'pages/Advanced/StringRoomId/StringRoomIdView' },
  { title: '画质设定', route: 'pages/Advanced/SetVideoQuality/SetVideoQualityView' },
  { title: '音质设定', route: 'pages/Advanced/SetAudioQuality/SetAudioQualityView' },
  { title: '渲染控制', route: 'pages/Advanced/SetRenderParams/SetRenderParamsView' },
  { title: '网络测速', route: 'pages/Advanced/SpeedTest/SpeedTestView' },
  { title: 'CDN发布', route: 'pages/Advanced/PushCDN/PushCDNEnterView' },
  { title: '自定义视频采集&渲染', route: 'pages/Advanced/CustomCamera/CustomCameraView' },
  { title: '设置音效', route: 'pages/Advanced/SetAudioEffect/SetAudioEffectView' },
  { title: '设置背景音乐', route: 'pages/Advanced/SetBGM/SetBGMView' },
  { title: '本地视频分享', route: 'pages/Advanced/LocalVideoShare/LocalVideoShareView' },
  { title: '本地媒体录制', route: 'pages/Advanced/LocalRecord/LocalRecordView' },
  { title: '加入多个房间', route: 'pages/Advanced/JoinMultipleRoom/JoinMultipleRoomView' },
  { title: '收发SEI消息', route: 'pages/Advanced/SEIMessage/SEIMessageView' },
  { title: '快速切换房间', route: 'pages/Advanced/SwitchRoom/SwitchRoomView' },
  { title: '跨房PK', route: 'pages/Advanced/RoomPK/RoomPKView' },
];

@Entry({ routeName: MainEntryView.name })
@Component
export struct MainEntryView {
  private scroller: Scroller = new Scroller();

  @Builder
  DemoItemCard(item: DemoItem) {
    Column() {
      Text(item.title)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
      if (item.desc) {
        Text(item.desc)
          .fontSize(12)
          .fontColor('#AAAAAA')
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 12, bottom: 12 })
    .backgroundColor('#1B8A2A')
    .borderRadius(8)
    .onClick(() => {
      router.pushUrl({ url: item.route }, router.RouterMode.Single);
    })
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(18)
      .fontColor('#FFFFFF')
      .fontWeight(FontWeight.Bold)
      .margin({ top: 24, bottom: 8 })
  }

  build() {
    Column() {
      // 标题栏
      Text('腾讯云TRTC API Example')
        .fontSize(20)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ top: 15, bottom: 5 })

      // 功能列表
      Scroll(this.scroller) {
        Column({ space: 10 }) {
          // 基础功能
          this.SectionTitle('基础功能')
          ForEach(BASIC_ITEMS, (item: DemoItem) => {
            this.DemoItemCard(item)
          }, (item: DemoItem) => item.route)

          // 进阶功能
          this.SectionTitle('进阶功能')
          ForEach(ADVANCED_ITEMS, (item: DemoItem) => {
            this.DemoItemCard(item)
          }, (item: DemoItem) => item.route)

          // SDK 版本信息
          Row() {
            Text('SDK Version: ')
              .fontSize(12)
              .fontColor('#888888')
            Text(getV2TXLivePremierShareInstance(getContext()).getSDKVersionStr())
              .fontSize(12)
              .fontColor('#888888')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 20, bottom: 20 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1C1D1F')
  }

  onBackPress(): boolean | void {
    return true;
  }
}
