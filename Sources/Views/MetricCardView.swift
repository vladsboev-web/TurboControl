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

struct SpringButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.24), Color.primary.opacity(0.07)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

struct IconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 28
    var iconSize: CGFloat = 14
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(color.opacity(0.16))
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: size, height: size)
    }
}

struct MetricCardView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let temperature: Double?
    var frequencyGHz: Double? = nil
    let loadPercentage: Double?
    let loadTitle: String? // "Нагрузка CPU:" / "Нагрузка GPU:"
    let customValue: String?
    let customSubtitle: String?
    let progress: Double // 0.0 to 1.0
    let progressColor: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Header row
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    IconBadge(systemName: icon, color: iconColor)
                    
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                if let freq = frequencyGHz {
                    Text(String(format: "%.2f GHz", freq))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(iconColor.opacity(0.12))
                        )
                        .animation(nil, value: freq)
                }
                
                if let temp = temperature {
                    Text(String(format: "%.0f°C", temp))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(ThermalScale.color(for: temp))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(ThermalScale.color(for: temp).opacity(0.14))
                        )
                        .animation(nil, value: temp)
                } else if let val = customValue {
                    Text(val)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            
            // Horizontal Progress Bar with dynamic calibrated fill
            HorizontalProgressBar(progress: progress, color: progressColor)
                .frame(height: 6)
            
            // Subtitle row with load or status
            HStack(alignment: .center) {
                if let load = loadPercentage {
                    Text(loadTitle ?? L10n.defaultLoadTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", load))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(load > 80 ? ThermalScale.hotColor : .secondary)
                        .animation(nil, value: load)
                } else if let sub = customSubtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(height: 15)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 12)
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
                    .fill(Color.primary.opacity(0.09))
                    .frame(width: geo.size.width, height: 6)
                
                // Foreground Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.75), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * clamped), height: 6)
                    .shadow(color: color.opacity(0.30), radius: 3, x: 0, y: 0)
                    .opacity(clamped > 0.005 ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.25), value: clamped)
            }
            .frame(width: geo.size.width, height: 6, alignment: .leading)
        }
        .frame(height: 6)
    }
}
