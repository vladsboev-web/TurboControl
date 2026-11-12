import SwiftUI

struct HeavyProcessesView: View {
    @ObservedObject var monitor = ProcessMonitorService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var isHoveringClose = false
    
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    IconBadge(systemName: "flame.fill", color: ThermalScale.warmColor)
                    Text(L10n.heavyProcessesTitle)
                        .font(.system(size: 15, weight: .bold))
                }
                
                Spacer()
                
                Button(action: onClose) {
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
            
            // Sort Segmented Control
            HStack(spacing: 4) {
                ForEach(ProcessSortOption.allCases, id: \.self) { option in
                    let isSelected = monitor.sortBy == option
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            monitor.sortBy = option
                        }
                    }) {
                        Text(sortTitle(option))
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSelected ? Color(NSColor.controlBackgroundColor).opacity(0.75) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(isSelected ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SpringButtonStyle(pressedScale: 0.95))
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            
            // Top-5 Processes List
            if monitor.isLoading && monitor.processes.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(0.85)
                Spacer()
            } else if monitor.processes.isEmpty {
                Spacer()
                Text(L10n.noHeavyProcesses)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                VStack(spacing: 7) {
                    ForEach(monitor.processes) { item in
                        processRow(item)
                    }
                }
                Spacer(minLength: 0)
            }
            
            // Footer Hint
            Text(L10n.heavyProcessesHint)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
        }
    }
    
    private func processRow(_ item: HeavyProcessItem) -> some View {
        let currentRule = settings.appTurboRules[item.ruleKey] ?? .auto
        
        return HStack(spacing: 10) {
            if let nsImg = item.icon {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            } else {
                IconBadge(systemName: "app.fill", color: .secondary, size: 28, iconSize: 14)
            }
            
            VStack(alignment: .leading, spacing: 2.5) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(metricText(for: item))
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 4)
            
            // Turbo Rule Toggle Pill
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    let nextRule = currentRule.next
                    if nextRule == .auto {
                        settings.appTurboRules.removeValue(forKey: item.ruleKey)
                    } else {
                        settings.appTurboRules[item.ruleKey] = nextRule
                    }
                    AutomationService.shared.evaluateRulesOnDemand()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: currentRule == .disable ? "leaf.fill" : "bolt.fill")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(L10n.appRuleBadge(currentRule))
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(ruleForeground(currentRule))
                .padding(.horizontal, 9)
                .padding(.vertical, 5.5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ruleBackground(currentRule))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ruleBorder(currentRule), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(SpringButtonStyle(pressedScale: 0.92))
            .help(L10n.turboRuleTooltip)
            
            // Terminate Button
            Button(action: {
                withAnimation(.easeOut(duration: 0.15)) {
                    monitor.terminateProcess(item)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ThermalScale.hotColor)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ThermalScale.hotColor.opacity(0.14))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(SpringButtonStyle(pressedScale: 0.90))
            .help(L10n.killProcessTooltip)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 11)
    }
    
    private func sortTitle(_ option: ProcessSortOption) -> String {
        switch option {
        case .cpu: return L10n.sortCPU
        case .gpu: return L10n.sortGPU
        case .energy: return L10n.sortEnergy
        }
    }
    
    private func metricText(for item: HeavyProcessItem) -> String {
        switch monitor.sortBy {
        case .cpu:
            return String(format: "%.1f%% CPU", item.cpuPercent)
        case .gpu:
            return String(format: "%.1f%% GPU", item.gpuPercent)
        case .energy:
            return String(format: "%.1f Energy", item.energyImpact)
        }
    }
    
    private func ruleForeground(_ rule: AppTurboRule) -> Color {
        switch rule {
        case .auto: return .secondary
        case .disable: return ThermalScale.optimalColor
        case .enable: return ThermalScale.warmColor
        }
    }
    
    private func ruleBackground(_ rule: AppTurboRule) -> Color {
        switch rule {
        case .auto: return Color.primary.opacity(0.06)
        case .disable: return ThermalScale.optimalColor.opacity(0.16)
        case .enable: return ThermalScale.warmColor.opacity(0.16)
        }
    }
    
    private func ruleBorder(_ rule: AppTurboRule) -> Color {
        switch rule {
        case .auto: return Color.clear
        case .disable: return ThermalScale.optimalColor.opacity(0.45)
        case .enable: return ThermalScale.warmColor.opacity(0.45)
        }
    }
}
