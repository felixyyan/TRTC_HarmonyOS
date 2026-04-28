import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent from '@ohos.app.ability.wantAgent';
import bundleManager from '@ohos.bundle.bundleManager';

/**
 * 后台运行 Helper：TRTC 进房后必须调用此工具，否则切后台会 crash。
 *
 * 使用方式（每个调用 enterRoom 的页面都要接入）：
 *   - 进房成功后：BackgroundRunningHelper.start()
 *   - 退房/析构：  BackgroundRunningHelper.stop()
 *
 * 支持引用计数：多个页面/子房间场景嵌套 start 时，只有最后一次 stop 才真正停止。
 *
 * 前提条件（module.json5）：
 *   - abilities[0].backgroundModes 声明包含 audioRecording / audioPlayback
 *   - requestPermissions 包含 ohos.permission.KEEP_BACKGROUND_RUNNING
 */
export class BackgroundRunningHelper {
  private static refCount: number = 0;
  private static started: boolean = false;

  public static async start(modes: string[] = ['audioPlayback', 'audioRecording']): Promise<void> {
    BackgroundRunningHelper.refCount++;
    if (BackgroundRunningHelper.started) {
      return;
    }
    try {
      const ctx = getContext();
      const bundleName = await BackgroundRunningHelper.getBundleName();
      const abilityName = 'EntryAbility';

      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: bundleName,
            abilityName: abilityName
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const want = await wantAgent.getWantAgent(wantAgentInfo);
      await backgroundTaskManager.startBackgroundRunning(ctx, modes, want);

      BackgroundRunningHelper.started = true;
      console.info('[BackgroundRunning] start ok, modes=' + JSON.stringify(modes) + ', ref=' + BackgroundRunningHelper.refCount);
    } catch (err) {
      console.error('[BackgroundRunning] start failed: ' + JSON.stringify(err));
    }
  }

  public static async stop(): Promise<void> {
    if (BackgroundRunningHelper.refCount > 0) {
      BackgroundRunningHelper.refCount--;
    }
    if (BackgroundRunningHelper.refCount > 0) {
      // 还有其他页面在用，不真正停止
      return;
    }
    if (!BackgroundRunningHelper.started) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(getContext());
      BackgroundRunningHelper.started = false;
      console.info('[BackgroundRunning] stop ok');
    } catch (err) {
      console.error('[BackgroundRunning] stop failed: ' + JSON.stringify(err));
      BackgroundRunningHelper.started = false;
    }
  }

  public static isRunning(): boolean {
    return BackgroundRunningHelper.started;
  }

  /**
   * 强制重置（异常回退场景用）。正常业务不需调用。
   */
  public static async forceReset(): Promise<void> {
    BackgroundRunningHelper.refCount = 0;
    if (BackgroundRunningHelper.started) {
      try {
        await backgroundTaskManager.stopBackgroundRunning(getContext());
      } catch (err) { }
      BackgroundRunningHelper.started = false;
    }
  }

  private static async getBundleName(): Promise<string> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      return info.name;
    } catch (e) {
      return 'com.tencent.liteav.demo';
    }
  }
}
