import SwiftUI

struct CleaningProgressView: View {
    let done: Int
    let total: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Cleaning")
                .font(.system(size: 16, weight: .semibold))

            Text("\(done) / \(max(total, 1))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .frame(width: 240)
        }
        .padding(20)
        .frame(minWidth: 300, minHeight: 140)
    }
}
