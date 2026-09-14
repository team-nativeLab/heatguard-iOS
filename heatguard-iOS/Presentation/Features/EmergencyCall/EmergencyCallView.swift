import SwiftUI

struct EmergencyCallView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("긴급 호출").font(HGFont.bold(20, relativeTo: .title2)).padding(.top, 18)
            VStack(alignment: .leading, spacing: 8) { Text("긴급 상황이에요").font(HGFont.bold(16)).foregroundStyle(.red); Text("현장관리자에게 즉시 도움을 요청합니다").font(HGFont.semiBold(12)).foregroundStyle(.red) }.frame(maxWidth: .infinity, minHeight: 73, alignment: .leading).padding(.horizontal, 19).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 25)).padding(.horizontal, 25).padding(.top, 48)
            ZStack { Circle().fill(Color.orange.opacity(0.18)).frame(width: 138, height: 138); Circle().fill(Color.orange.opacity(0.75)).frame(width: 110, height: 110); Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 42)).foregroundStyle(.white) }.padding(.top, 17)
            Text("긴급 호출 중...").font(HGFont.bold(20)).foregroundStyle(.orange).padding(.top, 20)
            Text("버튼을 누르면 즉시\n관리자에게 전화가 연결됩니다").font(HGFont.semiBold(15)).foregroundStyle(HGColor.secondaryText).multilineTextAlignment(.center).padding(.top, 12)
            VStack(alignment: .leading, spacing: 14) { Text("연락 대상").font(HGFont.bold(15)); Text("현장 관리자").font(HGFont.bold(16)); HStack { Text("010 - 1234 - 5678").font(HGFont.bold(16)).foregroundStyle(HGColor.primary); Spacer(); Image("Phone").resizable().scaledToFit().frame(width: 24, height: 24) } }.frame(maxWidth: .infinity, minHeight: 143, alignment: .leading).padding(.horizontal, 30).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 25)).overlay { RoundedRectangle(cornerRadius: 25).stroke(HGColor.inputBorder, lineWidth: 1) }.padding(.horizontal, 25).padding(.top, 28)
            Spacer()
            Button("호출 취소") {}.font(HGFont.medium(16)).frame(maxWidth: .infinity, minHeight: 48).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(HGColor.inputBorder, lineWidth: 1) }.padding(.horizontal, 28).padding(.bottom, 20)
        }.background(Color(red: 249/255, green: 251/255, blue: 252/255)).presentationBackground(Color(red: 249/255, green: 251/255, blue: 252/255)).presentationDetents([.height(683)]).presentationCornerRadius(40).presentationDragIndicator(.hidden)
    }
}
