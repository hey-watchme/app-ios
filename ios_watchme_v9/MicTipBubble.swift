import SwiftUI

struct MicTipBubble: View {
    let text: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.darkBase)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.darkBase.opacity(0.8))
                        .padding(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.accentTeal)
            .cornerRadius(12)
            .overlay(
                TrianglePointer()
                    .fill(Color.accentTeal)
                    .frame(width: 16, height: 8)
                    .offset(x: -18, y: 8),
                alignment: .bottomTrailing
            )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MicTipBubble(text: "まずは音声の\n分析を始めてみましょう。", onClose: {})
}
