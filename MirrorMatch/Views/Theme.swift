import SwiftUI

enum Theme {
    static let bg0 = Color(red: 0.027, green: 0.027, blue: 0.07)
    static let bg1 = Color(red: 0.09, green: 0.06, blue: 0.2)
    static let cyan = Color(red: 0.25, green: 0.9, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.27, blue: 0.75)
    static let lime = Color(red: 0.6, green: 1.0, blue: 0.4)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.3)
    static let card = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.12)
    static let brand = LinearGradient(colors: [cyan, magenta], startPoint: .leading, endPoint: .trailing)
    static let brandDiag = LinearGradient(colors: [cyan, magenta], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bg1, Theme.bg0], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.magenta.opacity(0.22), .clear], center: .topTrailing, startRadius: 10, endRadius: 380)
            RadialGradient(colors: [Theme.cyan.opacity(0.18), .clear], center: .bottomLeading, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var colors: [Color] = [Theme.cyan, Theme.magenta]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(19))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: colors.last!.opacity(0.45), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.09), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

struct Pill: View {
    let text: String
    var icon: String?
    var tint: Color = Theme.cyan
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
            Text(text).font(Theme.font(13))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(tint.opacity(0.15), in: Capsule())
    }
}
