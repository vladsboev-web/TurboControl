import SwiftUI

private enum PopoverTab {
    case main
    case processes
    case charts
    case settings
}

struct MainPopoverView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var turbo = TurboBoostService.shared
    @ObservedObject var powerMgmt = PowerManagementService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var activeTab: PopoverTab = .main
    @State private var isHoveringTurbo: Bool = false
    @State private var isHoveringTop5: Bool = false
    @State private var isHoveringCharts: Bool = false
    @State private var isHoveringTheme: Bool = false
    @State private var isHoveringLang: Bool = false
    @State private var isHoveringSettings: Bool = false
    @State private var isHoveringQuit: Bool = false
    
    private static let cachedAppIcon: NSImage? = {
        guard let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns") else { return nil }
        return NSImage(contentsOfFile: iconPath)
    }()
    
    var body: some View {
        ZStack {
            switch activeTab {
            case .main:
                mainContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            case .processes:
                HeavyProcessesView(onClose: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        activeTab = .main
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            case .charts:
                ChartsView(onClose: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        activeTab = .main
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            case .settings:
                SettingsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .padding(.top, 14)
        .frame(width: 388, height: 548)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.primary.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .onReceive(NotificationCenter.default.publisher(for: .closeSettingsView)) { _ in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                activeTab = .main
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetToMainTab)) { _ in
            activeTab = .main
        }
        .onChange(of: settings.chartsEnabled) { enabled in
            if !enabled && activeTab == .charts {
                activeTab = .main
            }
        }
        .preferredColorScheme(settings.theme.colorScheme)
    }
    
    private var mainContent: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    if let iconImage = Self.cachedAppIcon {
                        Image(nsImage: iconImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    } else {
                        IconBadge(systemName: "cpu", color: .accentColor, size: 24, iconSize: 13)
                    }
                    Text("TurboControl")
                        .font(.system(size: 15.5, weight: .bold))
                }
                
                Spacer()
                
                if settings.chartsEnabled {
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            activeTab = .charts
                        }
                    }) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isHoveringCharts ? .accentColor : .secondary)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(isHoveringCharts ? 0.16 : 0.08))
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SpringButtonStyle(pressedScale: 0.90))
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.12)) {
                            isHoveringCharts = hovering
                        }
                    }
                    .help(L10n.chartsBtnTooltip)
                }
                
                // Processes & Sleep Blockers Tab Button
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        activeTab = .processes
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(ThermalScale.warmColor)
                        Text(L10n.top5BtnTitle)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ThermalScale.warmColor.opacity(isHoveringTop5 ? 0.20 : 0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ThermalScale.warmColor.opacity(0.32), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(SpringButtonStyle(pressedScale: 0.92))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHoveringTop5 = hovering
                    }
                }
                .help(L10n.top5Tooltip)
                
                // Quick Theme Switcher (Auto -> Light -> Dark)
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                        settings.theme = settings.theme.next
                    }
                }) {
                    Image(systemName: settings.theme.iconName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(isHoveringTheme ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(isHoveringTheme ? 0.14 : 0.08))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(SpringButtonStyle(pressedScale: 0.90))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHoveringTheme = hovering
                    }
                }
                .help("\(L10n.themeTooltip): \(L10n.themeTitle(settings.theme))")
                
                // Quick RU / EN Language Switcher Pill
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        settings.language = (settings.language == .ru) ? .en : .ru
                    }
                }) {
                    Text(settings.language.shortBadge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.88))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5.5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(isHoveringLang ? 0.14 : 0.08))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(SpringButtonStyle(pressedScale: 0.92))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHoveringLang = hovering
                    }
                }
                .help(L10n.languageLabel)
                
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        activeTab = .settings
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13.5))
                        .foregroundColor(isHoveringSettings ? .primary : .secondary)
                        .rotationEffect(.degrees(isHoveringSettings ? 25 : 0))
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(isHoveringSettings ? 0.14 : 0.07))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(SpringButtonStyle(pressedScale: 0.90))
                .onHover { hovering in
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                        isHoveringSettings = hovering
                    }
                }
                .help(L10n.settingsTooltip)
            }
            .frame(height: 30)
            
            // Big Turbo Boost Control Widget (Intel Macs only)
            if SystemCapabilities.isIntelMac {
                turboBoostWidget
                
                if turbo.isHelperOutdated {
                    helperOutdatedBanner
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            // Metric Cards
            VStack(spacing: 8) {
                // CPU Card
                MetricCardView(
                    title: L10n.cpuTitle,
                    icon: "cpu",
                    iconColor: .blue,
                    temperature: monitor.cpuTemp > 0 ? monitor.cpuTemp : nil,
                    frequencyGHz: monitor.cpuFrequencyGHz > 0 ? monitor.cpuFrequencyGHz : nil,
                    powerWatts: monitor.cpuPowerWatts > 0 ? monitor.cpuPowerWatts : nil,
                    loadPercentage: monitor.cpuLoad,
                    loadTitle: L10n.cpuLoadTitle,
                    customValue: monitor.cpuTemp > 0 ? nil : "--°C",
                    customSubtitle: nil,
                    progress: ThermalScale.progress(for: monitor.cpuTemp),
                    progressColor: ThermalScale.color(for: monitor.cpuTemp)
                )
                
                // GPU Card
                MetricCardView(
                    title: L10n.gpuTitle,
                    icon: "display",
                    iconColor: .purple,
                    temperature: monitor.gpuTemp > 0 ? monitor.gpuTemp : nil,
                    loadPercentage: monitor.gpuLoad,
                    loadTitle: L10n.gpuLoadTitle,
                    customValue: monitor.gpuTemp > 0 ? nil : "--°C",
                    customSubtitle: nil,
                    progress: ThermalScale.progress(for: monitor.gpuTemp),
                    progressColor: ThermalScale.color(for: monitor.gpuTemp)
                )
                
                // Interactive Fan Control Card
                FanControlCardView()
                
                // System Power (W) & Low Power Mode Strip
                powerStatusCard
            }
            
            Spacer(minLength: 0)
            
            // Footer
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(ThermalScale.optimalColor)
                        .frame(width: 5, height: 5)
                    Text(L10n.pollingEvery(settings.updateInterval))
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text(L10n.quit)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isHoveringQuit ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(isHoveringQuit ? 0.12 : 0.06))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(SpringButtonStyle(pressedScale: 0.93))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHoveringQuit = hovering
                    }
                }
            }
            .frame(height: 26)
        }
    }
    
    private var helperOutdatedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
            
            Text(L10n.helperOutdatedTitle)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer(minLength: 4)
            
            Button(action: {
                turbo.installHelperWithPrompt { success in
                    if success {
                        SystemMonitor.shared.updateMetrics()
                    }
                }
            }) {
                Text(L10n.helperUpdateBtn)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(SpringButtonStyle(pressedScale: 0.92))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                )
        )
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
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.28), accentColor.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(0.35), lineWidth: 1)
                        )
                    
                    if turbo.isWorking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isOff ? "leaf.fill" : "bolt.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Intel Turbo Boost")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(isOff ? L10n.turboDisabledBadge : L10n.turboEnabledBadge)
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(badgeBgColor))
                            .shadow(color: badgeBgColor.opacity(0.35), radius: 3, x: 0, y: 1)
                    }
                    
                    if let errMsg = turbo.statusMessage {
                        Text(errMsg)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(ThermalScale.hotColor)
                    } else {
                        Text(isOff ? L10n.turboDisabledSubtitle : L10n.turboEnabledSubtitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(.primary.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(isHoveringTurbo ? 0.22 : 0.16),
                                accentColor.opacity(isHoveringTurbo ? 0.10 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(accentColor.opacity(isHoveringTurbo ? 0.65 : 0.42), lineWidth: 1.1)
                    )
            )
            .scaleEffect(isHoveringTurbo ? 1.01 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHoveringTurbo)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOff)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringButtonStyle(pressedScale: 0.97))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHoveringTurbo = hovering
            }
        }
        .disabled(turbo.isWorking)
    }
    
    private var powerStatusCard: some View {
        HStack(spacing: 8) {
            IconBadge(systemName: "bolt.circle.fill", color: ThermalScale.moderateColor, size: 24, iconSize: 12)
            
            Text(L10n.totalPowerLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(monitor.systemPowerWatts > 0 ? String(format: "%.1f W", monitor.systemPowerWatts) : "-- W")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(ThermalScale.moderateColor.opacity(0.14))
                )
                .animation(nil, value: monitor.systemPowerWatts)
            
            Spacer(minLength: 4)
            
            if powerMgmt.isLowPowerModeSupported {
                let isActive = powerMgmt.isLowPowerEnabledForScope
                Button(action: {
                    powerMgmt.setLowPowerMode(enabled: !isActive)
                }) {
                    HStack(spacing: 4) {
                        if powerMgmt.isTogglingLowPower {
                            ProgressView()
                                .scaleEffect(0.55)
                        } else {
                            Image(systemName: isActive ? "battery.100.bolt" : "leaf")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        Text(L10n.lowPowerTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(isActive ? .white : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isActive ? ThermalScale.moderateColor : Color.primary.opacity(0.07))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(SpringButtonStyle(pressedScale: 0.94))
                .disabled(powerMgmt.isTogglingLowPower)
                .help("\(L10n.lowPowerScopeLabel) \(L10n.lowPowerScopeTitle(settings.lowPowerScope))")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCard(cornerRadius: 12)
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
