import SwiftUI

struct ChartsView: View {
    @ObservedObject var monitor = SystemMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var isHoveringClose = false
    
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    IconBadge(systemName: "chart.xyaxis.line", color: .accentColor)
                    Text(L10n.chartsTitle)
                        .font(.system(size: 15, weight: .bold))
                }
                
                Spacer()
                
                Text(L10n.chartIntervalBadge(settings.chartsSampleInterval))
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                
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
            
            let samples = monitor.metricsHistory
            if samples.count < 2 {
                Spacer()
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text(L10n.chartsCollecting)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ChartMetricCard(
                            title: L10n.chartCpuTemp,
                            icon: "thermometer",
                            color: ThermalScale.color(for: samples.last?.cpuTemp ?? 0),
                            values: samples.map { $0.cpuTemp },
                            minFloor: 30,
                            formatter: { String(format: "%.0f°C", $0) }
                        )
                        
                        ChartMetricCard(
                            title: L10n.chartCpuFreq,
                            icon: "cpu",
                            color: .blue,
                            values: samples.map { $0.cpuFreqGHz },
                            minFloor: 0.5,
                            formatter: { String(format: "%.2f GHz", $0) }
                        )
                        
                        ChartMetricCard(
                            title: L10n.chartFanRPM,
                            icon: "fanblades.fill",
                            color: FanScale.cyanColor,
                            values: samples.map { $0.fanRPM },
                            minFloor: 0,
                            formatter: { String(format: "%.0f RPM", $0) }
                        )
                        
                        ChartMetricCard(
                            title: L10n.chartPowerW,
                            icon: "bolt.circle.fill",
                            color: ThermalScale.moderateColor,
                            values: samples.map { $0.systemPowerW },
                            minFloor: 0,
                            formatter: { String(format: "%.1f W", $0) }
                        )
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ChartMetricCard: View {
    let title: String
    let icon: String
    let color: Color
    let values: [Double]
    let minFloor: Double
    let formatter: (Double) -> String
    
    var body: some View {
        let current = values.last ?? 0
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("\(L10n.chartNow): \(formatter(current))")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(color.opacity(0.14)))
            }
            
            SparklineGraph(values: values, color: color, minFloor: minFloor)
                .frame(height: 44)
            
            HStack {
                Text("\(L10n.chartMin): \(formatter(minVal))")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(L10n.chartMax): \(formatter(maxVal))")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .glassCard(cornerRadius: 11)
    }
}

private struct SparklineGraph: View {
    let values: [Double]
    let color: Color
    let minFloor: Double
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let rawMin = values.min() ?? 0
            let rawMax = values.max() ?? 0
            let span = max(rawMax - rawMin, max(1.0, rawMax * 0.12))
            let low = max(minFloor, rawMin - span * 0.15)
            let high = max(low + 0.1, rawMax + span * 0.15)
            
            let points: [CGPoint] = values.enumerated().map { idx, val in
                let x = values.count > 1
                    ? w * CGFloat(idx) / CGFloat(values.count - 1)
                    : w * 0.5
                let norm = (val - low) / (high - low)
                let clamped = max(0.0, min(1.0, norm))
                let y = h - CGFloat(clamped) * (h - 4) - 2
                return CGPoint(x: x, y: y)
            }
            
            ZStack {
                // Subtle mid-line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.5))
                    path.addLine(to: CGPoint(x: w, y: h * 0.5))
                }
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                
                if points.count >= 2 {
                    // Area gradient
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: h))
                        for pt in points {
                            path.addLine(to: pt)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.28), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Line stroke
                    Path { path in
                        path.move(to: points[0])
                        for pt in points.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    
                    // Latest point dot
                    if let last = points.last {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .position(last)
                    }
                }
            }
        }
    }
}
