import router from '@ohos.router';
import { generateUserId, generateRoomId } from '../../../common/TRTCUtils';

@Entry
@Component
struct AudioCallingEnterView {
  @State userId: string = generateUserId();
  @State roomId: string = '20260424';

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('< ')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .onClick(() => {
            router.back();
          })
        Text('语音通话')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Row({ space: 10 }) {
        Text('用户名')
          .fontColor('#FFFFFF')
          .width(60)
        TextInput({ text: this.userId, placeholder: 'userId' })
          .backgroundColor('#FFFFFF')
          .fontColor('#333333')
          .height(40)
          .onChange((value: string) => {
            this.userId = value;
          })
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 10 }) {
        Text('房间号')
          .fontColor('#FFFFFF')
          .width(60)
        TextInput({ text: this.roomId, placeholder: 'roomId' })
          .backgroundColor('#FFFFFF')
          .fontColor('#333333')
          .height(40)
          .onChange((value: string) => {
            this.roomId = value;
          })
          .layoutWeight(1)
      }
      .width('100%')

      Button('进入房间')
        .width('100%')
        .onClick(() => {
          router.pushUrl({
            url: 'pages/Basic/AudioCall/AudioCallingView',
            params: { userId: this.userId, roomId: this.roomId }
          });
        })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#1C1D1F')
  }
}
