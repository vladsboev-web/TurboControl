import SwiftUI

struct MainPopoverView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var turbo = TurboBoostService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var showingSettings: Bool = false
    
    private static let cachedAppIcon: NSImage? = {
        guard let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") else { return nil }
        return NSImage(contentsOfFile: iconPath)
    }()
    
    var body: some View {
        ZStack {
            if showingSettings {
                SettingsView()
            } else {
                mainContent
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 14)
        .frame(width: 334, height: 456)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .onReceive(NotificationCenter.default.publisher(for: .closeSettingsView)) { _ in
            showingSettings = false
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 9) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    if let iconImage = Self.cachedAppIcon {
                        Image(nsImage: iconImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "cpu")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                    Text("TurboControl")
                        .font(.system(size: 14, weight: .bold))
                }
                
                Spacer()
                
                // Quick RU / EN Language Switcher Pill
                Button(action: {
                    settings.language = (settings.language == .ru) ? .en : .ru
                }) {
                    Text(settings.language.shortBadge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.languageLabel)
                
                Button(action: {
                    showingSettings.toggle()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.settingsTooltip)
            }
            .frame(height: 24)
            
            // Big Turbo Boost Control Widget
            turboBoostWidget
            
            // Metric Cards
            VStack(spacing: 8) {
                // CPU Card
                MetricCardView(
                    title: L10n.cpuTitle,
                    icon: "cpu",
                    iconColor: .blue,
                    temperature: monitor.cpuTemp,
                    loadPercentage: monitor.cpuLoad,
                    loadTitle: L10n.cpuLoadTitle,
                    customValue: nil,
                    customSubtitle: nil,
                    progress: ThermalScale.progress(for: monitor.cpuTemp),
                    progressColor: ThermalScale.color(for: monitor.cpuTemp)
                )
                
                // GPU Card
                MetricCardView(
                    title: L10n.gpuTitle,
                    icon: "display",
                    iconColor: .purple,
                    temperature: monitor.gpuTemp,
                    loadPercentage: monitor.gpuLoad,
                    loadTitle: L10n.gpuLoadTitle,
                    customValue: nil,
                    customSubtitle: nil,
                    progress: ThermalScale.progress(for: monitor.gpuTemp),
                    progressColor: ThermalScale.color(for: monitor.gpuTemp)
                )
                
                // Interactive Fan Control Card
                FanControlCardView()
            }
            
            Spacer(minLength: 0)
            
            // Footer
            HStack {
                Text(L10n.pollingEvery(settings.updateInterval))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text(L10n.quit)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: 20)
        }
    }
    
    private var turboBoostWidget: some View {
        let isOff = turbo.isTurboDisabled
        let accentColor = isOff ? ThermalScale.optimalColor : ThermalScale.warmColor
        let badgeBgColor = isOff
            ? Color(NSColor(srgbRed: 0.08, green: 0.62, blue: 0.25, alpha: 1.0))
            : Color(NSColor(srgbRed: 0.90, green: 0.36, blue: 0.02, alpha: 1.0))
        
        return Button(action: {
            turbo.setTurboDisabled(!turbo.isTurboDisabled)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.22))
                        .frame(width: 36, height: 36)
                    
                    if turbo.isWorking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isOff ? "leaf.fill" : "bolt.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Intel Turbo Boost")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(isOff ? L10n.turboDisabledBadge : L10n.turboEnabledBadge)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(badgeBgColor)
                            .cornerRadius(5)
                    }
                    
                    if let errMsg = turbo.statusMessage {
                        Text(errMsg)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ThermalScale.hotColor)
                    } else {
                        Text(isOff ? L10n.turboDisabledSubtitle : L10n.turboEnabledSubtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accentColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(accentColor.opacity(0.55), lineWidth: 1.2)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(turbo.isWorking)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
