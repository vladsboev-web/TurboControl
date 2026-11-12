import SwiftUI

struct FanControlCardView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var fanService = FanControlService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var hoveredMode: FanMode? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            // Fan Header & RPM Metric
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    IconBadge(systemName: "fanblades.fill", color: FanScale.cyanColor)
                    
                    Text(L10n.fanTitle)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(monitor.fanRPM > 0 ? String(format: "%.0f RPM", monitor.fanRPM) : L10n.fanZeroQuiet)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(FanScale.color(for: monitor.fanRPM))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .background(
                        Capsule()
                            .fill(FanScale.color(for: monitor.fanRPM).opacity(0.14))
                    )
                    .animation(nil, value: monitor.fanRPM)
            }
            
            // Progress Bar
            let fanProgress = FanScale.progress(for: monitor.fanRPM)
            HorizontalProgressBar(progress: fanProgress, color: FanScale.color(for: monitor.fanRPM))
                .frame(height: 6)
            
            // Segmented Mode Selector
            HStack(spacing: 3) {
                ForEach(FanMode.allCases, id: \.self) { mode in
                    let isSelected = fanService.currentMode == mode
                    let isHovered = hoveredMode == mode
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            fanService.currentMode = mode
                        }
                    }) {
                        Text(L10n.fanModeTitle(mode))
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .primary : (isHovered ? .primary.opacity(0.85) : .secondary))
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 5.5)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? FanScale.cyanColor.opacity(0.22) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(isSelected ? FanScale.cyanColor.opacity(0.55) : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SpringButtonStyle(pressedScale: 0.94))
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.12)) {
                            hoveredMode = hovering ? mode : (hoveredMode == mode ? nil : hoveredMode)
                        }
                    }
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            
            // Mode Details / Slider
            if fanService.currentMode == .manual {
                VStack(spacing: 3) {
                    HStack {
                        Text(L10n.fanManualTarget)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f RPM", fanService.targetManualRPM))
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(FanScale.cyanColor)
                    }
                    
                    Slider(
                        value: $fanService.targetManualRPM,
                        in: 1200...7200,
                        step: 100
                    )
                    .accentColor(FanScale.cyanColor)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack(spacing: 5) {
                    Image(systemName: modeDescriptionIcon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(L10n.fanModeDesc(fanService.currentMode))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Spacer()
                }
                .frame(height: 15)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 12)
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
