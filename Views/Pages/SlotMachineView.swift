import SwiftUI
import Combine

// MARK: - 单个滚轮组件 (保持不变，只改了宽度传入方式)
struct SlotColumnView: View {
    let index: Int
    @Binding var targetNumber: Int?
    let columnWidth: CGFloat // 宽度由外部决定
    
    @State private var currentSymbol: Int = 0
    @State private var nextSymbol: Int = 1
    @State private var scrollOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var blurAmount: CGFloat = 0
    
    // 字体大小根据宽度动态调整
    var fontSize: CGFloat {
        columnWidth * 0.7
    }
    
    var body: some View {
        ZStack {
            // 背景框
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.black, Color(white: 0.15), .black], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Text("\(currentSymbol)")
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(targetNumber == nil ? .red.opacity(0.7) : .red)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: blurAmount)
                    
                    Text("\(nextSymbol)")
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.red.opacity(0.7))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: blurAmount)
                }
                .offset(y: scrollOffset)
            }
            .clipped()
        }
        .frame(width: columnWidth, height: columnWidth * 1.5) // 高度按比例设定
        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
        .onChange(of: targetNumber) { _, newValue in
            if newValue == nil && !isAnimating {
                isAnimating = true
                startRollingLoop(interval: 0.3)
            }
        }
    }
    
    func startRollingLoop(interval: Double, stoppingStartTime: Date? = nil) {
        if let target = targetNumber {
            let startTime = stoppingStartTime ?? Date()
            let elapsed = Date().timeIntervalSince(startTime)
            
            let duration: TimeInterval = 2.0
            let progress = min(1.0, elapsed / duration)
            let currentDecelInterval = 0.05 + (0.13 * progress)
            
            withAnimation(.linear(duration: 0.1)) {
                blurAmount = max(0, 2.0 * (1.0 - CGFloat(progress)))
            }
            
            if progress >= 0.9 && nextSymbol == target {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scrollOffset = 0
                    currentSymbol = target
                    blurAmount = 0
                }
                
                AudioManager.shared.play("slot_stop")
                HapticManager.shared.impact(style: .light)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = false
                }
                return
            }
            
            performScrollStep(interval: currentDecelInterval, startTime: startTime)
            return
        }
        
        var nextInterval = interval
        if interval > 0.05 {
            nextInterval = max(0.05, interval * 0.85)
            withAnimation { blurAmount = min(2, blurAmount + 0.2) }
        } else {
            nextInterval = Double.random(in: 0.04...0.06)
            blurAmount = 2
        }
        
        performScrollStep(interval: nextInterval, startTime: nil)
    }
    
    func performScrollStep(interval: Double, startTime: Date?) {
        withAnimation(.linear(duration: interval)) {
            scrollOffset = columnWidth * 1.5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            scrollOffset = 0
            currentSymbol = nextSymbol
            nextSymbol = (currentSymbol + 1) % 10
            startRollingLoop(interval: interval, stoppingStartTime: startTime)
        }
    }
}

// MARK: - 老虎机主视图 (核心布局修改)
struct SlotMachineView: View {
    let type: LotteryType
    var onFinished: (([Int]) -> Void)?
    
    @State private var targetNumbers: [Int?]
    @State private var leverAngle: Double = 0
    
    init(type: LotteryType, onFinished: (([Int]) -> Void)? = nil) {
        self.type = type
        self.onFinished = onFinished
        _targetNumbers = State(initialValue: Array(repeating: 0, count: type.slotColumns))
    }
    
    var body: some View {
        GeometryReader { geo in
            let screenW = geo.size.width
            // 🔥 动态计算列宽
            // 逻辑：(屏幕宽 - 左右留白 - 摇杆预留空间) / 列数
            // 但为了居中，我们尽量让数字区占据中间部分，摇杆悬浮
            // 简单算法：限制最大宽度 70，最小 40，保证间距
            let totalSpacing = CGFloat(type.slotColumns - 1) * 8.0
            let availableW = screenW * 0.75 // 给数字区 75% 的宽度，剩下的留给摇杆
            let calculatedW = (availableW - totalSpacing) / CGFloat(type.slotColumns)
            let itemW = min(max(calculatedW, 45), 75) // 限制在 45~75 之间
            
            ZStack {
                // 1. 摇杆 (放在 ZStack 底层或顶层都可以，这里放在右侧绝对位置)
                HStack {
                    Spacer()
                    LeverView(angle: leverAngle)
                        .padding(.trailing, 20) // 距离右边的距离
                }
                .zIndex(1) // 保证摇杆可点击
                
                // 2. 数字显示区 (绝对居中)
                VStack(spacing: 15) {
                    if type.slotColumns == 5 {
                        // 排列五：双层布局 (上3 下2)
                        // 确保上下两排视觉对齐
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                ForEach(0..<3, id: \.self) { i in slotItem(i, width: itemW) }
                            }
                            HStack(spacing: 8) {
                                ForEach(3..<5, id: \.self) { i in slotItem(i, width: itemW) }
                            }
                        }
                        .padding(12)
                        .background(slotBackground)
                        
                    } else {
                        // 3D/排列三：单行布局
                        HStack(spacing: 8) {
                            ForEach(0..<type.slotColumns, id: \.self) { i in
                                slotItem(i, width: itemW)
                            }
                        }
                        .padding(12)
                        .background(slotBackground)
                    }
                }
                // 这一步是关键：让数字区无视摇杆，强制在屏幕中间
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(x: -10) // 视觉微调：稍微往左一点点，平衡右边摇杆的视觉重量
                .zIndex(2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: type.slotColumns == 5 ? 320 : 200)
        .onReceive(NotificationCenter.default.publisher(for: .startSlotMachine)) { note in
            if let triggerType = note.object as? LotteryType, triggerType == type {
                startSpin()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopSlotMachine)) { note in
            if let triggerType = note.object as? LotteryType, triggerType == type {
                stopSpin()
            }
        }
    }
    
    // 抽取摇杆视图，代码更整洁
    struct LeverView: View {
        let angle: Double
        
        var body: some View {
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    // 摇杆底座
                    Capsule()
                        .fill(LinearGradient(colors: [.gray, .white], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 8, height: 50)
                    
                    // 摇杆把手 (随角度旋转)
                    VStack(spacing: 0) {
                        Circle()
                            .fill(RadialGradient(colors: [.red, .red.opacity(0.8)], center: .center, startRadius: 2, endRadius: 15))
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        
                        Rectangle()
                            .fill(LinearGradient(colors: [.gray, .black], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 6, height: 70)
                    }
                    .offset(y: 10)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                }
            }
        }
    }
    
    func slotItem(_ i: Int, width: CGFloat) -> some View {
        SlotColumnView(
            index: i,
            targetNumber: $targetNumbers[i],
            columnWidth: width
        )
    }
    
    var slotBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color(hex: "151515")) // 深色背景
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        LinearGradient(colors: [.red.opacity(0.6), .red.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
            )
            .shadow(color: .red.opacity(0.15), radius: 15)
    }
    
    func startSpin() {
        AudioManager.shared.playLoop("slot_roll")
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { leverAngle = 45 }
        HapticManager.shared.impact(style: .heavy)
        
        for i in 0..<targetNumbers.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                targetNumbers[i] = nil
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring()) { leverAngle = 0 }
        }
    }
    
    func stopSpin() {
        let finalNums = (0..<type.slotColumns).map { _ in Int.random(in: 0...9) }
        
        for i in 0..<type.slotColumns {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.0) {
                targetNumbers[i] = finalNums[i]
                HapticManager.shared.impact(style: .medium)
            }
        }
        
        let totalDelay = Double(type.slotColumns) * 1.0 + 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            AudioManager.shared.stopLoop("slot_roll")
            onFinished?(finalNums)
        }
    }
}
