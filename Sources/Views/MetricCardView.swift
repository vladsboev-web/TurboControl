import SwiftUI

enum ThermalScale {
    static let minTemp: Double = 30.0  // Минимальная рабочая температура (с запасом 10° от нормы 40°)
    static let maxTemp: Double = 105.0 // Максимальный предел TjMax Intel Core i5 = 100°C (+5-10° запас)
    
    static func progress(for temp: Double) -> Double {
        let clamped = max(minTemp, min(maxTemp, temp))
        return (clamped - minTemp) / (maxTemp - minTemp)
    }
    
    // Насыщенные контрастные цвета с отличной читаемостью как на светлом, так и на темном фоне
    static let coolColor = Color(NSColor(name: nil) { app in
        app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.15, green: 0.65, blue: 1.0, alpha: 1.0)
            : NSColor(srgbRed: 0.0, green: 0.42, blue: 0.88, alpha: 1.0)
    })
    
    static let optimalColor = Color(NSColor(name: nil) { app in
        app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.20, green: 0.86, blue: 0.42, alpha: 1.0)
            : NSColor(srgbRed: 0.06, green: 0.56, blue: 0.22, alpha: 1.0)
    })
    
    static let moderateColor = Color(NSColor(name: nil) { app in
        app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.0, green: 0.72, blue: 0.08, alpha: 1.0)
            : NSColor(srgbRed: 0.78, green: 0.44, blue: 0.0, alpha: 1.0)
    })
    
    static let warmColor = Color(NSColor(name: nil) { app in
        app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.0, green: 0.45, blue: 0.08, alpha: 1.0)
            : NSColor(srgbRed: 0.86, green: 0.30, blue: 0.0, alpha: 1.0)
    })
    
    static let hotColor = Color(NSColor(name: nil) { app in
        app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.0, green: 0.26, blue: 0.26, alpha: 1.0)
            : NSColor(srgbRed: 0.82, green: 0.10, blue: 0.14, alpha: 1.0)
    })
    
    static func color(for temp: Double) -> Color {
        switch temp {
        case ..<48.0:
            return coolColor      // Холодный / в покое (до 48°C)
        case 48.0..<62.0:
            return optimalColor   // Оптимальная рабочая температура (48-62°C)
        case 62.0..<78.0:
            return moderateColor  // Умеренный нагрев под нагрузкой (62-78°C)
        case 78.0..<90.0:
            return warmColor      // Высокая температура (78-90°C)
        default:
            return hotColor       // Горячо / близко к пределу (>90°C)
        }
    }
}

enum FanScale {
    static let maxRPM: Double = 7200.0
    
    static let cyanColor = Color(NSColor(name: nil) { app in
        app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.18, green: 0.78, blue: 0.98, alpha: 1.0)
            : NSColor(srgbRed: 0.0, green: 0.48, blue: 0.76, alpha: 1.0)
    })
    
    static func progress(for rpm: Double) -> Double {
        return max(0.0, min(1.0, rpm / maxRPM))
    }
    
    static func color(for rpm: Double) -> Color {
        if rpm <= 0 {
            return Color.secondary.opacity(0.6)
        } else if rpm < 2800 {
            return cyanColor
        } else if rpm < 5000 {
            return ThermalScale.warmColor
        } else {
            return ThermalScale.hotColor
        }
    }
}

struct MetricCardView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let temperature: Double?
    let loadPercentage: Double?
    let loadTitle: String? // "Нагрузка CPU:" / "Нагрузка GPU:"
    let customValue: String?
    let customSubtitle: String?
    let progress: Double // 0.0 to 1.0
    let progressColor: Color
    
    var body: some View {
        VStack(spacing: 7) {
            // Header row
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                        .frame(width: 16, height: 16)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if let temp = temperature {
                    Text(String(format: "%.0f°C", temp))
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundColor(ThermalScale.color(for: temp))
                        .animation(nil, value: temp)
                } else if let val = customValue {
                    Text(val)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            .frame(height: 16)
            
            // Horizontal Progress Bar with dynamic calibrated fill
            HorizontalProgressBar(progress: progress, color: progressColor)
                .frame(height: 6)
            
            // Subtitle row with load or status
            HStack(alignment: .center) {
                if let load = loadPercentage {
                    Text(loadTitle ?? L10n.defaultLoadTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%5.1f%%", load))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(load > 80 ? ThermalScale.hotColor : .secondary)
                        .animation(nil, value: load)
                } else if let sub = customSubtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(height: 14)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 68)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct HorizontalProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        let clamped = CGFloat(max(0.0, min(1.0, progress)))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: geo.size.width, height: 6)
                
                // Foreground Fill
                Capsule()
                    .fill(color)
                    .frame(width: max(6, geo.size.width * clamped), height: 6)
                    .opacity(clamped > 0.005 ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.25), value: clamped)
            }
            .frame(width: geo.size.width, height: 6, alignment: .leading)
            .clipped()
        }
        .frame(height: 6)
        .drawingGroup()
    }
}
