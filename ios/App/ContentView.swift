import SwiftUI
import RhombusCore

extension FeatureStatus {
    var color: Color {
        switch self {
        case .idea: return Color(red: 0.55, green: 0.60, blue: 0.72)
        case .planned: return Color(red: 0.30, green: 0.52, blue: 0.98)
        case .inProgress: return Color(red: 0.98, green: 0.62, blue: 0.15)
        case .blocked: return Color(red: 0.95, green: 0.30, blue: 0.38)
        case .done: return Color(red: 0.12, green: 0.75, blue: 0.52)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @StateObject private var speech = SpeechRecognizer()
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color(red: 0.93, green: 0.95, blue: 1.0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if store.state.products.isEmpty { emptyState }
                    ForEach(store.state.products) { product in
                        ProductCard(product: product,
                                    features: store.state.features.filter { $0.productId == product.id })
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(20)
                .padding(.bottom, 200)
            }
            .refreshable { await store.refresh() }
            micPanel
        }
        .task { await store.refresh() }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Rhombus").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("\(store.state.products.count) products · \(store.state.features.count) features")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3).foregroundColor(.secondary)
            }.accessibilityLabel("Settings")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.circle.fill").font(.system(size: 56)).foregroundColor(.blue.opacity(0.7))
            Text("Say “Add product Orbit”").font(.headline)
            Text("Then “Add feature voice login to Orbit” and “Mark voice login as in progress”.")
                .font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var micPanel: some View {
        VStack(spacing: 12) {
            Text(speech.isListening || !speech.transcript.isEmpty ? (speech.transcript.isEmpty ? "Listening…" : speech.transcript) : store.message)
                .font(.callout.weight(.medium))
                .foregroundColor(store.isError && !speech.isListening ? .red : .primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .animation(.easeOut(duration: 0.15), value: speech.transcript)
            Button {
                speech.toggle { text in Task { await store.handle(transcript: text) } }
            } label: {
                ZStack {
                    Circle().fill(Color.blue.opacity(0.15))
                        .frame(width: 96 + CGFloat(speech.level) * 50, height: 96 + CGFloat(speech.level) * 50)
                        .animation(.easeOut(duration: 0.1), value: speech.level)
                    Circle().fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 78, height: 78).shadow(color: .blue.opacity(0.35), radius: 14, y: 6)
                    Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28)).foregroundColor(.white)
                }
            }
            .accessibilityLabel(speech.isListening ? "Stop listening" : "Start listening")
        }
        .padding(.vertical, 16).frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

struct ProductCard: View {
    let product: Product
    let features: [Feature]

    private var progress: Double {
        features.isEmpty ? 0 : Double(features.filter { $0.status == .done }.count) / Double(features.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(product.name).font(.title2.bold())
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 6)
                    Circle().trim(from: 0, to: progress)
                        .stroke(FeatureStatus.done.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(), value: progress)
                    Text("\(Int(progress * 100))%").font(.caption2.bold())
                }.frame(width: 44, height: 44)
            }
            if features.isEmpty {
                Text("No features yet").font(.footnote).foregroundColor(.secondary)
            }
            ForEach(features) { f in
                HStack {
                    Circle().fill(f.status.color).frame(width: 10, height: 10)
                    Text(f.title).font(.body)
                    Spacer()
                    Text(f.status.label).font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(f.status.color.opacity(0.15)).foregroundColor(f.status.color)
                        .clipShape(Capsule())
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage("apiURL") private var apiURL = ""
    @AppStorage("apiToken") private var apiToken = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Cloudflare Worker") {
                    TextField("https://rhombus-api.you.workers.dev", text: $apiURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    SecureField("API token", text: $apiToken)
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss(); Task { await store.refresh() } } }
        }
    }
}
