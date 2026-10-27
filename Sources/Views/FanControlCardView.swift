import SwiftUI

struct FanControlCardView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var fanService = FanControlService.shared
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Fan Header & RPM Metric
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "fanblades.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FanScale.cyanColor)
                        .frame(width: 16, height: 16)
                    
                    Text(L10n.fanTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(monitor.fanRPM > 0 ? String(format: "%.0f RPM", monitor.fanRPM) : L10n.fanZeroQuiet)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(FanScale.color(for: monitor.fanRPM))
                    .animation(nil, value: monitor.fanRPM)
            }
            .frame(height: 16)
            
            // Progress Bar
            let fanProgress = FanScale.progress(for: monitor.fanRPM)
            HorizontalProgressBar(progress: fanProgress, color: FanScale.color(for: monitor.fanRPM))
                .frame(height: 6)
            
            // Mode Selector Pills
            HStack(spacing: 4) {
                ForEach(FanMode.allCases, id: \.self) { mode in
                    let isSelected = fanService.currentMode == mode
                    Button(action: {
                        fanService.currentMode = mode
                    }) {
                        Text(L10n.fanModeTitle(mode))
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? FanScale.cyanColor.opacity(0.24) : Color.primary.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? FanScale.cyanColor : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(height: 22)
            
            // Mode Details / Slider
            if fanService.currentMode == .manual {
                VStack(spacing: 3) {
                    HStack {
                        Text(L10n.fanManualTarget)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f RPM", fanService.targetManualRPM))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(FanScale.cyanColor)
                    }
                    
                    Slider(
                        value: $fanService.targetManualRPM,
                        in: 1200...7200,
                        step: 100
                    )
                }
                .padding(.top, 2)
            } else {
                HStack {
                    Image(systemName: modeDescriptionIcon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(L10n.fanModeDesc(fanService.currentMode))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private var modeDescriptionIcon: String {
        switch fanService.currentMode {
        case .auto: return "applelogo"
        case .smart: return "bolt.shield.fill"
        case .max: return "flame.fill"
        case .manual: return "slider.horizontal.3"
        }
    }
}
