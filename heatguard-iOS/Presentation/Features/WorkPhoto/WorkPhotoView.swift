//
//  WorkPhotoView.swift
//  heatguard-iOS
//

import SwiftUI

struct WorkPhotoView: View {
    @State private var memo = ""

    let onSave: () -> Void

    init(onSave: @escaping () -> Void = {}) {
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 0) {
                Text("작업 전 · 중 사진")
                    .font(HGFont.bold(20, relativeTo: .title2))
                    .foregroundStyle(.black)

                Text("작업 현장과 보호조치를 확인 할 수 있는\n사진을 촬영해 주세요")
                    .font(HGFont.regular(14, relativeTo: .subheadline))
                    .foregroundStyle(.black)
                    .padding(.top, 10)

                HGPhotoCaptureSection()
                    .padding(.top, 15)

                memoSection
                    .padding(.top, 25)
            }
            .padding(.top, 45)

            Spacer(minLength: 0)

            HGPrimaryButton(title: "기록 저장", height: 48, action: onSave)
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 25)
        .padding(.top, 24)
        .background(HGColor.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HGScreenHeader()
    }

    private var memoSection: some View {
        HGOptionalMemoSection(
            placeholder: "작업 전 · 중 특이사항이 있다면 입력해주세요",
            height: 114,
            text: $memo
        )
        .padding(.horizontal, 7)
    }

}

#Preview {
    NavigationStack {
        WorkPhotoView()
    }
}
