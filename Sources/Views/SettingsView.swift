import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var isHoveringClose = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    IconBadge(systemName: "gearshape.fill", color: .accentColor)
                    Text(L10n.settingsTitle)
                        .font(.system(size: 15, weight: .bold))
                }
                
                Spacer()
                
                Button(action: {
                    NotificationCenter.default.post(name: .closeSettingsView, object: nil)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isHoveringClose ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(isHoveringClose ? 0.14 : 0.08))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(SpringButtonStyle(pressedScale: 0.90))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHoveringClose = hovering
                    }
                }
            }
            .frame(height: 30)
            
            // Scrollable Settings Body
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    // Appearance, Language & Polling Card
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(L10n.themeLabel)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            HStack(spacing: 3) {
                                ForEach(AppTheme.allCases, id: \.self) { themeOption in
                                    let isSelected = settings.theme == themeOption
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            settings.theme = themeOption
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: themeOption.iconName)
                                                .font(.system(size: 10.5, weight: .semibold))
                                            Text(L10n.themeTitle(themeOption))
                                                .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                                        }
                                        .foregroundColor(isSelected ? .white : .secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5.5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(isSelected ? Color.accentColor : Color.clear)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(SpringButtonStyle(pressedScale: 0.94))
                                }
                            }
                            .padding(2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        
                        Divider().opacity(0.5)
                        
                        HStack {
                            Text(L10n.languageLabel)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            HStack(spacing: 3) {
                                ForEach(AppLanguage.allCases, id: \.self) { lang in
                                    let isSelected = settings.language == lang
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            settings.language = lang
                                        }
                                    }) {
                                        Text(lang.displayName)
                                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                                            .foregroundColor(isSelected ? .white : .secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5.5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(isSelected ? Color.accentColor : Color.clear)
                                            )
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(SpringButtonStyle(pressedScale: 0.94))
                                }
                            }
                            .padding(2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                        
                        Divider().opacity(0.5)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L10n.updateFreqLabel)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text(L10n.secondsBadge(settings.updateInterval))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2.5)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            }
                            
                            HStack(spacing: 6) {
                                Text(L10n.minSecLabel)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Slider(
                                    value: $settings.updateInterval,
                                    in: 4...60,
                                    step: 1
                                )
                                
                                Text(L10n.maxSecLabel)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 12)
                    
                    // Automation Card
                    automationCard
                    
                    // Toggles Card
                    VStack(alignment: .leading, spacing: 10) {
                        settingToggleRow(
                            title: L10n.autoLaunchTitle,
                            subtitle: L10n.autoLaunchSub,
                            isOn: $settings.autoLaunchAtLogin
                        )
                        
                        Divider().opacity(0.5)
                        
                        settingToggleRow(
                            title: L10n.restoreTurboTitle,
                            subtitle: L10n.restoreTurboSub,
                            isOn: $settings.restoreLastTurboState
                        )
                        
                        Divider().opacity(0.5)
                        
                        settingToggleRow(
                            title: L10n.showTempTitle,
                            subtitle: L10n.showTempSub,
                            isOn: $settings.showTempInMenuBar
                        )
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 12)
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.badge.a.fill")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(ThermalScale.warmColor)
                Text(L10n.automationSectionTitle)
                    .font(.system(size: 13.5, weight: .bold))
            }
            
            // 1. Power Source Rules
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.powerRuleTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.secondary)
                
                powerActionRow(
                    label: L10n.onACLabel,
                    options: [.enable, .keep],
                    selection: $settings.onACPowerAction
                )
                
                powerActionRow(
                    label: L10n.onBatteryLabel,
                    options: [.disable, .keep],
                    selection: $settings.onBatteryPowerAction
                )
                
                if settings.isPowerAutomationActive {
                    HStack {
                        Text(L10n.allowTurboLowBattAC)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.9))
                        Spacer()
                        Toggle("", isOn: $settings.allowTurboOnLowBatteryWhenPluggedIn)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .controlSize(.small)
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            Divider().opacity(0.5)
            
            // 2. Temperature Rules
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(L10n.tempRuleTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: $settings.autoTempEnabled.animation(.easeInOut(duration: 0.18)))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: ThermalScale.warmColor))
                        .controlSize(.small)
                }
                
                if settings.autoTempEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.tempDisableAt(settings.autoTempDisableThreshold))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(ThermalScale.warmColor)
                            Spacer()
                            Text(L10n.tempEnableAt(settings.autoTempEnableThreshold))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(ThermalScale.optimalColor)
                        }
                        
                        Slider(value: $settings.autoTempDisableThreshold, in: 85...100, step: 1)
                            .accentColor(ThermalScale.warmColor)
                        
                        if settings.autoTempAdvanced {
                            let maxCool = max(50.0, settings.autoTempDisableThreshold - 10.0)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(L10n.tempEnableAt(settings.autoTempEnableThreshold))
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(L10n.minGap10Deg)
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $settings.autoTempEnableThreshold, in: 50...maxCool, step: 1)
                                    .accentColor(ThermalScale.optimalColor)
                            }
                            .transition(.opacity)
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                settings.autoTempAdvanced.toggle()
                            }
                        }) {
                            Text(settings.autoTempAdvanced ? L10n.simpleSettingsBtn : L10n.advancedSettingsBtn)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(SpringButtonStyle(pressedScale: 0.94))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            
            Divider().opacity(0.5)
            
            // 3. Battery Level Rules
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(L10n.batteryRuleTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                    Spacer()
                    Toggle("", isOn: $settings.autoBatteryEnabled.animation(.easeInOut(duration: 0.18)))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: ThermalScale.optimalColor))
                        .controlSize(.small)
                }
                
                if settings.autoBatteryEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.battDisableAt(settings.autoBatteryDisableThreshold))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(ThermalScale.warmColor)
                            Spacer()
                            Text(L10n.battEnableAt(settings.autoBatteryEnableThreshold))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(ThermalScale.optimalColor)
                        }
                        
                        Slider(value: $settings.autoBatteryDisableThreshold, in: 10...30, step: 1)
                            .accentColor(ThermalScale.warmColor)
                        
                        if settings.autoBatteryAdvanced {
                            let minCharge = min(80.0, settings.autoBatteryDisableThreshold + 10.0)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(L10n.battEnableAt(settings.autoBatteryEnableThreshold))
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(L10n.minGap10Pct)
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                                Slider(value: $settings.autoBatteryEnableThreshold, in: minCharge...80, step: 1)
                                    .accentColor(ThermalScale.optimalColor)
                            }
                            .transition(.opacity)
                        }
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                settings.autoBatteryAdvanced.toggle()
                            }
                        }) {
                            Text(settings.autoBatteryAdvanced ? L10n.simpleSettingsBtn : L10n.advancedSettingsBtn)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.accentColor)
                                .padding(.vertical, 3)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(SpringButtonStyle(pressedScale: 0.94))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }
    
    private func powerActionRow(label: String, options: [PowerTurboAction], selection: Binding<PowerTurboAction>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.9))
            Spacer()
            HStack(spacing: 3) {
                ForEach(options, id: \.self) { opt in
                    let isSelected = selection.wrappedValue == opt
                    Button(action: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                            selection.wrappedValue = opt
                        }
                    }) {
                        Text(L10n.powerActionTitle(opt))
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                    .fill(isSelected ? Color.accentColor : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SpringButtonStyle(pressedScale: 0.94))
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
    }
    
    private func settingToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 4)
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .controlSize(.small)
        }
    }
}

extension Notification.Name {
    static let closeSettingsView = Notification.Name("closeSettingsView")
}
