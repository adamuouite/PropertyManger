import SwiftUI

struct YearPicker: View {
    let label: String
    @Binding var year: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button { year -= 1 } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(String(year))
                .font(.headline)
                .frame(minWidth: 50, alignment: .center)
                .monospacedDigit()

            Button { year += 1 } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
