import SwiftUI

struct SaveFailureView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("기록 저장").font(HGFont.bold(20, relativeTo: .title2)).padding(.top, 18)
            VStack(spacing: 0) {
                ZStack { Circle().fill(Color.red.opacity(0.1)).frame(width: 84, height: 84); Image("Warning").resizable().scaledToFit().frame(width: 59, height: 59) }
                Text("기록이 저장하지 못했어요").font(HGFont.bold(20, relativeTo: .title2)).padding(.top, 34)
                Text("네트워크 연결을 확인한 후 다시시도 해주세요").font(HGFont.semiBold(15)).foregroundStyle(HGColor.secondaryText).padding(.top, 15)
            }.frame(maxWidth: .infinity, minHeight: 218).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 25)).overlay { RoundedRectangle(cornerRadius: 25).stroke(HGColor.inputBorder, lineWidth: 1) }.padding(.horizontal, 25).padding(.top, 52)
            VStack(alignment: .leading, spacing: 12) { Text("오류 내용").font(HGFont.bold(15)); Text("서버와 연결할 수 없습니다\n잠시 후 다시 시도해주세요").font(HGFont.medium(15)).foregroundStyle(HGColor.secondaryText).lineSpacing(8) }.frame(maxWidth: .infinity, minHeight: 123, alignment: .leading).padding(.horizontal, 28).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 25)).overlay { RoundedRectangle(cornerRadius: 25).stroke(HGColor.inputBorder, lineWidth: 1) }.padding(.horizontal, 25).padding(.top, 26)
            Spacer()
            HGPrimaryButton(title: "다시 시도하기", height: 48) {}.padding(.horizontal, 28)
            Button("임시저장 후 나가기") {}.font(HGFont.medium(16)).frame(maxWidth: .infinity, minHeight: 48).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(HGColor.inputBorder, lineWidth: 1) }.padding(.horizontal, 28).padding(.top, 14).padding(.bottom, 20)
        }.background(Color(red: 249/255, green: 251/255, blue: 252/255)).presentationBackground(Color(red: 249/255, green: 251/255, blue: 252/255)).presentationDetents([.height(683)]).presentationCornerRadius(40).presentationDragIndicator(.hidden)
    }
}
