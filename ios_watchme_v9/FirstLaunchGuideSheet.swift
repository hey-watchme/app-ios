import SwiftUI

struct FirstLaunchGuideSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(white: 0.35))
                            .padding(8)
                            .background(Color(white: 0.92))
                            .clipShape(Circle())
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.94), Color(white: 0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 220)

                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.15))
                            .frame(width: 120, height: 190)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.1))
                            .frame(width: 120, height: 190)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }

                VStack(spacing: 8) {
                    Text("このアプリでできること")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color(white: 0.12))

                    Text("音声から気分・行動・感情を分析し、\n1日の変化をわかりやすく可視化します。")
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.45))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)

                Button(action: onDismiss) {
                    Text("はじめる")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accentTeal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .background(Color.white)
            .cornerRadius(22)
            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: -2)
        }
    }
}

#Preview {
    FirstLaunchGuideSheet(onDismiss: {})
}
