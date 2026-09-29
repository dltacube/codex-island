import Foundation

@main
struct IslandLayoutTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ label: String) {
        if condition {
            print("PASS \(label)")
        } else {
            print("FAIL \(label)")
            failures += 1
        }
    }

    @MainActor
    static func main() {
        let suite = "CodexIsland.IslandLayoutTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("Cannot create test defaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["codex"], forKey: ProviderVisibilityStore.selectionKey)
        let visibility = ProviderVisibilityStore(defaults: defaults)
        let notch = NotchInfo(width: 200, height: 38, hasNotch: true)
        let model = IslandModel(notch: notch, visibility: visibility)
        let bounds = CGRect(x: 0, y: 0, width: 900, height: 360)
        let notchRight = bounds.midX + notch.width / 2
        let freedMenuPoint = CGPoint(x: notchRight + 20, y: bounds.maxY - 12)
        let compact = model.layout.rect(in: bounds)

        expect(model.size.width == 238, "single provider cold start removes the 38pt empty tab")
        expect(compact.maxX == notchRight, "compact right edge ends at the physical notch")
        expect(!compact.contains(freedMenuPoint), "compact empty-side menu space passes clicks through")

        model.setState(.peek)
        let singlePeek = model.layout.rect(in: bounds)
        expect(model.size.width == 334, "single provider peek removes the whole 134pt empty wing")
        expect(singlePeek.maxX == notchRight, "peek right edge stays at the physical notch")
        expect(singlePeek.minX + 105 == compact.minX + 9, "hover keeps the provider logo pinned beside the notch")
        expect(singlePeek.contains(CGPoint(x: 250, y: 340)), "remaining usage pill stays interactive")
        expect(!singlePeek.contains(freedMenuPoint), "always-show peek leaves right-side menu space clickable")

        visibility.set(.claude, at: 1)
        let dualPeek = model.layout.rect(in: bounds)
        expect(model.size.width == 468 && dualPeek.midX == bounds.midX, "adding a provider restores the centered two-sided peek live")
        expect(dualPeek.minX == singlePeek.minX, "adding a provider does not move the existing left wing")
        expect(dualPeek.contains(freedMenuPoint), "new right provider receives clicks in its own wing")
        visibility.swap()
        expect(model.layout.rect(in: bounds) == dualPeek, "swapping providers preserves the two-sided geometry")
        visibility.set(nil, at: 1)
        expect(model.layout.rect(in: bounds) == singlePeek, "removing a provider shrinks immediately using the new selection")

        model.updateExpandedHeight(300)
        model.setState(.expanded)
        let expanded = model.layout.rect(in: bounds)
        expect(expanded == CGRect(x: 50, y: 60, width: 800, height: 300), "expanded panel stays centered and uses measured content height")
        visibility.set(.codex, at: 1)
        expect(model.layout.rect(in: bounds) == expanded, "selection changes do not shift the expanded panel")
        visibility.set(nil, at: 1)
        model.setState(.peek)
        expect(model.layout.rect(in: bounds) == singlePeek, "closing expanded panel restores the single-provider footprint")
        model.setState(.compact)
        expect(model.layout.rect(in: bounds) == compact, "disabling always-show recovers the compact single-provider footprint")

        model.updateNotch(NotchInfo(width: 100, height: 24, hasNotch: false))
        model.setState(.peek)
        let external = model.layout.rect(in: bounds)
        expect(external.midX == bounds.midX, "single provider stays centered on a non-notched display")
        expect(model.size.width == model.notch.width + 134 && external.height == 24,
               "non-notched display keeps configured spacing and removes only the unused wing")

        model.updateNotch(NotchInfo(width: 160, height: 32, hasNotch: true))
        let moved = model.layout.rect(in: bounds)
        expect(moved.maxX == 530 && moved.height == 32, "display changes re-anchor to the new physical notch")
        let translated = model.layout.rect(in: bounds.offsetBy(dx: 100, dy: 50))
        expect(translated == moved.offsetBy(dx: 100, dy: 50), "shared hit geometry respects the hosting view bounds origin")

        let relaunched = IslandModel(notch: notch, visibility: ProviderVisibilityStore(defaults: defaults))
        relaunched.setState(.peek)
        expect(relaunched.layout.rect(in: bounds) == singlePeek, "persisted single-provider selection restores the smaller footprint")

        if failures > 0 { exit(1) }
        print("all IslandLayoutTests passed")
    }
}
