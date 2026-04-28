import abilityAccessCtrl from '@ohos.abilityAccessCtrl';
import { BusinessError } from '@ohos.base';
import { Permissions } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';

/**
 * 权限请求工具函数
 */
export async function requestPermissions(permissions: Permissions[]): Promise<boolean> {
  let atManager = abilityAccessCtrl.createAtManager();
  try {
    let result = await atManager.requestPermissionsFromUser(getContext(), permissions);
    let allGranted = true;
    for (let i = 0; i < result.authResults.length; i++) {
      if (result.authResults[i] !== 0) {
        allGranted = false;
        break;
      }
    }
    return allGranted;
  } catch (err) {
    let error = err as BusinessError;
    console.error(`requestPermissions failed: ${error.code} - ${error.message}`);
    return false;
  }
}

/**
 * 显示 Toast 提示
 */
export function showToast(message: string) {
  try {
    promptAction.showToast({ message: message, duration: 2000 });
  } catch (error) { }
}

/**
 * 生成随机用户ID
 */
export function generateUserId(): string {
  let time = Date.now().toString();
  return time.substring(time.length - 8);
}

/**
 * 生成随机房间号
 */
export function generateRoomId(): string {
  return (Math.floor(Math.random() * 900000) + 100000).toString();
}
