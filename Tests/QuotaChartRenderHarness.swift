import AppKit
import SwiftUI

@main
@MainActor
struct QuotaChartRenderHarness {
    static func main() throws {
        precondition(AppEnvironment.isDemo, "Chart QA requires isolated demo mode")
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "notes/chart-integration-20260929/renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        ProviderVisibilityStore.shared.set(.codex, at: 0)
        ProviderVisibilityStore.shared.set(.claude, at: 1)
        StylePref.shared.hasCycledStyle = true
        ScreenPref.shared.screen = .usage
        ScreenPref.shared.hasSwipedScreen = true
        let model = IslandModel(notch: NotchInfo(width: 180, height: 32, hasNotch: true))
        model.setState(.expanded)
        for scenario in ChartQAScenario.allCases {
            scenario.apply()
            for style in ChartStyle.allCases {
                StylePref.shared.style = style
                let renderer = ImageRenderer(content: ChartQAPanel(model: model)
                    .transaction { $0.disablesAnimations = true })
                renderer.scale = 2
                _ = renderer.cgImage
                RunLoop.main.run(until: Date().addingTimeInterval(0.8))
                guard let image = renderer.cgImage,
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                else { fatalError("Could not render \(style.rawValue), \(scenario.rawValue)") }
                try png.write(to: output.appendingPathComponent("\(style.rawValue)-\(scenario.rawValue).png"))
            }
        }
        ChartQAScenario.mixed.apply()
        StylePref.shared.style = .ring
        for style in CostStyle.allCases {
            ScreenPref.shared.screen = .cost
            CostStylePref.shared.style = style
            try render(ChartQAPage(model: model, page: .cost), to: output.appendingPathComponent("cost-\(style.rawValue).png"))
        }
        ScreenPref.shared.screen = .overview
        try render(ChartQAPage(model: model, page: .overview), to: output.appendingPathComponent("overview.png"))
        ScreenPref.shared.screen = .usage
        print("PASS: 40 native chart renders across availability, missing readings, zero, remaining and 5h-only states")
        if ProcessInfo.processInfo.environment["CHART_QA_PREVIEW"] == "1" {
            let window = NSWindow(contentRect: NSRect(x: 100, y: 200, width: 840, height: 380),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "CodexIsland Chart QA"
            window.contentView = NSHostingView(rootView: ChartQAControls(model: model))
            window.center()
            window.makeKeyAndOrderFront(nil)
            app.activate(ignoringOtherApps: true)
            app.run()
        }
    }

    private static func render<V: View>(_ content: V, to output: URL) throws {
        let renderer = ImageRenderer(content: content.transaction { $0.disablesAnimations = true })
        renderer.scale = 2
        _ = renderer.cgImage
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { fatalError("Could not render \(output.lastPathComponent)") }
        try png.write(to: output)
    }
}

struct ChartQAPage: View {
    let model: IslandModel
    let page: ScreenPref.Screen

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(notch: model.notch)
            if page == .cost {
                CostView().padding(.vertical, IslandPanelLayout.dataVerticalInset)
            } else {
                OverviewView()
            }
            PanelFooter(model: model)
        }
        .frame(width: 800)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

enum ChartQAScenario: String, CaseIterable {
    case weekly, mixed, codex, both, unknown, zero, remaining, fiveHourOnly

    @MainActor
    func apply() {
        UsageDisplayModeStore.shared.mode = self == .remaining ? .remaining : .used
        let now = Date()
        func reading(_ value: Double, _ reset: TimeInterval) -> WindowUsage {
            WindowUsage(usedPercent: value / 100, resetAt: now.addingTimeInterval(reset), error: nil)
        }
        let short: WindowUsage = self == .unknown
            ? WindowUsage(usedPercent: 0, resetAt: nil, error: "Unable to fetch usage. Check connection.")
            : reading(self == .zero ? 0 : 19, 7200)
        let codexWeek = reading(self == .zero ? 100 : 32, 3 * 86400 + 20 * 3600)
        let claudeShort = reading(self == .zero ? 0 : 14, 4 * 3600)
        let claudeWeek = reading(self == .zero ? 0 : 28, 5 * 86400 + 11 * 3600)
        let codexWindows: [UsageWindow] = self == .fiveHourOnly ? [.fiveHour]
            : [.codex, .both, .unknown, .remaining, .zero].contains(self) ? [.fiveHour, .weekly] : [.weekly]
        let claudeWindows: [UsageWindow] = self == .fiveHourOnly ? [.fiveHour]
            : [.weekly, .codex].contains(self) ? [.weekly] : [.fiveHour, .weekly]
        UsageStore.shared.codex = AppUsage(fiveHour: codexWindows.contains(.fiveHour) ? short : .unknown,
                                          weekly: codexWindows.contains(.weekly) ? codexWeek : .unknown,
                                          plan: "Pro", reportedWindows: codexWindows)
        UsageStore.shared.claude = AppUsage(fiveHour: claudeWindows.contains(.fiveHour) ? claudeShort : .unknown,
                                           weekly: claudeWindows.contains(.weekly) ? claudeWeek : .unknown,
                                           plan: "Max", reportedWindows: claudeWindows)
        UsageStore.shared.lastUpdated = now
    }
}

struct ChartQAPanel: View {
    let model: IslandModel
    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(notch: model.notch)
            UsageView().padding(.vertical, IslandPanelLayout.dataVerticalInset)
            PanelFooter(model: model)
        }
        .frame(width: 800)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct ChartQAControls: View {
    let model: IslandModel
    @State private var scenario: ChartQAScenario = .mixed
    @ObservedObject private var pref = StylePref.shared

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Native chart QA - synthetic data").font(.headline)
                Spacer()
                Picker("Quota configuration", selection: $scenario) {
                    ForEach(ChartQAScenario.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 230)
                .onChange(of: scenario) { $0.apply() }
            }
            ChartQAPanel(model: model)
            HStack(spacing: 8) {
                ForEach(ChartStyle.allCases, id: \.self) { style in
                    Button(style.label) { pref.style = style }
                        .buttonStyle(.bordered)
                        .tint(pref.style == style ? .blue : .gray)
                }
                Button("Cycle") { pref.cycle() }
            }
        }
        .padding(20)
        .preferredColorScheme(.dark)
    }
}
