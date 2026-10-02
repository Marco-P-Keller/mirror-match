import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ReplayShareButton: View {
    @Environment(GameStore.self) private var game
    let records: [RoundRecord]
    let names: [String]
    let headline: String
    let subline: String
    let text: String
    @State private var rendering = false
    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        Button {
            guard !rendering else { return }
            rendering = true
            Haptics.medium()
            Task {
                do {
                    url = try await ReplayRenderer.render(records: records, names: names, skin: game.skin, headline: headline, subline: subline)
                } catch { failed = true }
                rendering = false
            }
        } label: {
            if rendering {
                HStack(spacing: 10) { ProgressView().tint(.black); Text("Rendering replay…") }
            } else {
                Label("Share Replay Video", systemImage: "play.rectangle.fill")
            }
        }
        .buttonStyle(PrimaryButtonStyle(colors: [Theme.magenta, Color.orange]))
        .sheet(isPresented: Binding(get: { url != nil }, set: { if !$0 { url = nil } })) {
            if let url { ShareSheet(items: [url, text]).presentationDetents([.medium, .large]) }
        }
        .alert("Couldn't render the replay", isPresented: $failed) { Button("OK", role: .cancel) {} }
    }
}
