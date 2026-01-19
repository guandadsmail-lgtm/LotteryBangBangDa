
import CoreGraphics

struct GameEngineConfig {
    // 1. 物理分类掩码 (用于区分谁撞了谁)
    // 0x1 << 0 等于 1, 0x1 << 1 等于 2, 依此类推
    static let categoryBall: UInt32      = 0x1 << 0
    static let categoryWall: UInt32      = 0x1 << 1
    static let categoryContainer: UInt32 = 0x1 << 2
    static let categorySucker: UInt32    = 0x1 << 3 // 吸球口

    // 2. 物理参数配置
    static let ballRadius: CGFloat = 16.0   // 球的半径
    static let restitution: CGFloat = 0.8   // 弹性 (0~1，越大越弹)
    static let friction: CGFloat = 0.3      // 摩擦力
    static let linearDamping: CGFloat = 0.2 // 空气阻力
    
    // 3. 视觉参数
    static let strokeWidth: CGFloat = 2.0
}
