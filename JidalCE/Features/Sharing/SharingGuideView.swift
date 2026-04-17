import SwiftUI
import UIKit

struct SharingGuideView: View {
    let groupName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("가족이나 파트너와 가계부를 함께 사용하려면 캘린더를 공유하세요.")
                    .font(.headline)

                step("1️⃣", "iPhone 설정 앱 열기")
                step("2️⃣", "캘린더 탭")
                step("3️⃣", "계정 → iCloud → \"\(groupName)\" 캘린더 선택")
                step("4️⃣", "사람 추가 → 상대방 Apple ID 입력")
                step("5️⃣", "상대방이 초대 수락하면 자동으로 가계부 공유")

                Button("설정 앱 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)

                Text("상대방도 이 앱을 설치하면 같은 캘린더를 선택하여 함께 사용할 수 있습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("캘린더 공유하기")
    }

    private func step(_ marker: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(marker)
            Text(text)
        }
    }
}
