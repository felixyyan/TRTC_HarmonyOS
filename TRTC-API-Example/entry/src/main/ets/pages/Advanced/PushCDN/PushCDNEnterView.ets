import router from '@ohos.router';
import { showToast, generateUserId, generateRoomId } from '../../../common/TRTCUtils';

@Entry
@Component
struct PushCDNEnterView {
  @State userId: string = generateUserId();
  @State roomId: string = generateRoomId();
  @State selectedRole: number = 0;

  private roleNames: string[] = ['主播 (Anchor)', '观众 (Audience)'];

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('\u2190')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('Push CDN')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
      }
      .width('100%')

      Column({ space: 15 }) {
        Text('CDN 旁路推流演示')
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

        Text('选择角色:')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .margin({ top: 10 })

        Column({ space: 8 }) {
          ForEach(this.roleNames, (name: string, index: number) => {
            Row() {
              Radio({ value: name, group: 'roleGroup' })
                .checked(this.selectedRole === index)
                .onChange((isChecked: boolean) => {
                  if (isChecked) {
                    this.selectedRole = index;
                  }
                })
              Text(name).fontColor('#FFFFFF').fontSize(14).margin({ left: 8 })
            }
            .width('100%')
          })
        }
        .padding(10)

        Button('进入房间')
          .width('80%')
          .height(44)
          .backgroundColor('#006EFF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            if (!this.userId || !this.roomId) {
              showToast('请填写用户ID和房间号');
              return;
            }
            if (this.selectedRole === 0) {
              router.pushUrl({
                url: 'pages/Advanced/PushCDN/PushCDNAnchorView',
                params: { 'userId': this.userId, 'roomId': this.roomId }
              });
            } else {
              router.pushUrl({
                url: 'pages/Advanced/PushCDN/PushCDNAudienceView',
                params: { 'userId': this.userId, 'roomId': this.roomId }
              });
            }
          })
      }
      .width('100%')
      .padding(10)
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }
}
