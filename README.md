# 腾讯云实时音视频 TRTC SDK — HarmonyOS API Example

_本示例工程对标 [TRTC HarmonyOS API Example](https://github.com/LiteAVSDK/TRTC_HarmonyOS)，演示 TRTC SDK 在 HarmonyOS (ArkTS) 上的各项功能。_

## 工程结构

```
TRTC-API-Example-OHOS/
├── AppScope/                          # 应用全局配置
├── entry/
│   ├── libs/
│   │   └── LiteAVSDK_TRTC_*.har      # TRTC SDK
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/          # UIAbility 入口
│       │   ├── common/                # 公共工具（权限管理、工具函数）
│       │   ├── debug/                 # 调试工具（UserSig 生成、常量）
│       │   └── pages/
│       │       ├── MainEntryView.ets  # 主页面（功能列表导航）
│       │       ├── Basic/             # 基础功能（5 个）
│       │       │   ├── AudioCall/     # 语音通话
│       │       │   ├── VideoCall/     # 视频通话
│       │       │   ├── Live/          # 视频互动直播
│       │       │   ├── VoiceChatRoom/ # 语音互动直播
│       │       │   └── ScreenShare/   # 录屏直播
│       │       └── Advanced/          # 进阶功能（15 个）
│       │           ├── StringRoomId/      # 字符串房间号
│       │           ├── SetVideoQuality/   # 画质设定
│       │           ├── SetAudioQuality/   # 音质设定
│       │           ├── SetRenderParams/   # 渲染控制
│       │           ├── SpeedTest/         # 网络测速
│       │           ├── PushCDN/           # CDN 发布
│       │           ├── CustomCamera/      # 自定义视频采集&渲染
│       │           ├── SetAudioEffect/    # 设置音效
│       │           ├── SetBGM/            # 设置背景音乐
│       │           ├── LocalVideoShare/   # 本地视频分享
│       │           ├── LocalRecord/       # 本地媒体录制
│       │           ├── JoinMultipleRoom/  # 加入多个房间
│       │           ├── SEIMessage/        # 收发 SEI 消息
│       │           ├── SwitchRoom/        # 快速切换房间
│       │           └── RoomPK/            # 跨房 PK
│       └── resources/                 # 资源文件
└── oh-package.json5                   # 项目配置
```

## 功能清单

### 基础功能

| 功能 | 说明 |
|------|------|
| 语音通话 | 双人/多人语音通话，包含静音/免提等功能 |
| 视频通话 | 双人/多人视频通话，包含静音/免提/切换摄像头等功能 |
| 视频互动直播 | 支持主播/观众角色，视频互动直播场景 |
| 语音互动直播 | 支持主播/观众角色，语音聊天室场景 |
| 录屏直播 | 屏幕采集推流，适用于在线教育、游戏直播等场景 |

### 进阶功能

| 功能 | 说明 |
|------|------|
| 字符串房间号 | 使用字符串（而非整数）作为房间号 |
| 画质设定 | 设置视频分辨率、帧率、码率 |
| 音质设定 | 设置音频采样率和质量 |
| 渲染控制 | 控制视频画面填充模式、旋转、镜像 |
| 网络测速 | 通话前测试网络质量 |
| CDN 发布 | 将音视频流推送到 CDN |
| 自定义视频采集&渲染 | 使用自定义数据源输入视频 |
| 设置音效 | 添加变声、混响等音效 |
| 设置背景音乐 | 播放和控制背景音乐 |
| 本地视频分享 | 本地视频文件作为视频源分享 |
| 本地媒体录制 | 录制通话音视频到本地 |
| 加入多个房间 | 同时加入多个 TRTC 房间 |
| 收发 SEI 消息 | 通过 SEI 通道收发自定义数据 |
| 快速切换房间 | 无缝切换到另一个房间 |
| 跨房 PK | 不同房间主播跨房连麦 |

## 快速开始

1. 在 `entry/src/main/ets/debug/gen-test-user-sig.ets` 中填入您的 `SDKAPPID` 和 `SECRETKEY`
2. 使用 DevEco Studio 打开工程
3. 编译运行即可体验所有功能

## 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK 5.0.0(12)+
- 设备：HarmonyOS 手机/平板

## 联系我们

- [常见问题](https://cloud.tencent.com/document/product/647/43018)
- [API 文档](https://cloud.tencent.com/document/product/647/129075)
