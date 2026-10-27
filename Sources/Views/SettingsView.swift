import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(L10n.settingsTitle)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: {
                    NotificationCenter.default.post(name: .closeSettingsView, object: nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(height: 24)
            
            Divider()
            
            // Language selector
            HStack {
                Text(L10n.languageLabel)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        let isSelected = settings.language == lang
                        Button(action: {
                            settings.language = lang
                        }) {
                            Text(lang.displayName)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Divider()
            
            // Polling interval
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.updateFreqLabel)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text(L10n.secondsBadge(settings.updateInterval))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text(L10n.minSecLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: $settings.updateInterval,
                        in: 4...60,
                        step: 1
                    )
                    
                    Text(L10n.maxSecLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Checkboxes
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $settings.autoLaunchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.autoLaunchTitle)
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.autoLaunchSub)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(CheckboxToggleStyle())
                
                Toggle(isOn: $settings.restoreLastTurboState) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.restoreTurboTitle)
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.restoreTurboSub)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(CheckboxToggleStyle())
                
                Toggle(isOn: $settings.showTempInMenuBar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.showTempTitle)
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.showTempSub)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(CheckboxToggleStyle())
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension Notification.Name {
    static let closeSettingsView = Notification.Name("closeSettingsView")
}
