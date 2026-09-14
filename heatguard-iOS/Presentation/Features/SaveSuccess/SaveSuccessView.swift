import SwiftUI

struct SaveSuccessView: View {
    let records = [("온도계 기록", "47.5 ℃  ( 습도 55% 체감 40.7℃ )"), ("작업 사진", "2장"), ("휴식 사진", "2장"), ("저장 시간", "2026.07.18 10 : 30")]

    var body: some View {
        VStack(spacing: 0) {
            Text("기록 저장").font(HGFont.bold(20, relativeTo: .title2)).padding(.top, 18)
            successCard.padding(.top, 52)
            summaryCard.padding(.top, 26)
            HGPrimaryButton(title: "확인", height: 48) {}.padding(.horizontal, 28).padding(.top, 16).padding(.bottom, 20)
        }
        .background(Color(red: 249/255, green: 251/255, blue: 252/255), in: UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40))
    }

    private var successCard: some View {
        VStack(spacing: 0) {
            ZStack { Circle().fill(Color(red: 226/255, green: 246/255, blue: 235/255)).frame(width: 84, height: 84); Image("SaveSuccessCheck").resizable().scaledToFit().frame(width: 53, height: 53) }
            Text("기록이 저장됐어요").font(HGFont.bold(20, relativeTo: .title2)).padding(.top, 34)
            Text("현장관리자에게 실시간으로 전송됩니다.").font(HGFont.semiBold(15)).foregroundStyle(HGColor.secondaryText).padding(.top, 15)
        }.frame(maxWidth: .infinity, minHeight: 218).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 25)).overlay { RoundedRectangle(cornerRadius: 25).stroke(HGColor.inputBorder, lineWidth: 1) }.padding(.horizontal, 25)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("저장한 기록 요약").font(HGFont.bold(15)).padding(.bottom, 12)
            ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                HStack { VStack(alignment: .leading, spacing: 4) { Text(record.0).font(HGFont.bold(14)); Text(record.1).font(HGFont.semiBold(12)).foregroundStyle(HGColor.secondaryText) }; Spacer(); if index < 3 { Image("ChevronRight").resizable().scaledToFit().frame(width: 24, height: 24) } }.padding(.vertical, 10)
                if index < records.count - 1 { Divider() }
            }
        }.padding(20).background(HGColor.surface, in: RoundedRectangle(cornerRadius: 25)).overlay { RoundedRectangle(cornerRadius: 25).stroke(HGColor.inputBorder, lineWidth: 1) }.padding(.horizontal, 25)
    }
}

#Preview { SaveSuccessView() }
