import SwiftUI

// MARK: - 1. 全局通知名称定义
extension NSNotification.Name {
    // 流程控制
    static let startRedPhase = NSNotification.Name("startRedPhase")
    static let startBluePhase = NSNotification.Name("startBluePhase")
    static let resetScene = NSNotification.Name("resetScene")
    static let redPhaseFinished = NSNotification.Name("redPhaseFinished")
    static let allFinished = NSNotification.Name("allFinished")
    
    // 老虎机
    static let startSlotMachine = NSNotification.Name("startSlotMachine")
    static let stopSlotMachine = NSNotification.Name("stopSlotMachine")
    
    // 支付
    static let showPaywall = NSNotification.Name("showPaywall")
}

// MARK: - 2. 全局统一颜色标准 (解决色差问题的核心)
extension Color {
    // 使用绝对 RGB 值，不随系统主题变化，保证物理球和UI球颜色一致
    static let lotteryRed = Color(red: 1.0, green: 0.23, blue: 0.19) // 鲜艳红
    static let lotteryBlue = Color(red: 0.0, green: 0.48, blue: 1.0) // 鲜艳蓝
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 3. 圆角扩展
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
