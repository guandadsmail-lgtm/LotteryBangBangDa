import SwiftUI
import Combine

// MARK: - 单个滚轮组件
struct SlotColumnView: View {
    let index: Int
    @Binding var targetNumber: Int?
    let columnWidth: CGFloat
    
    @State private var currentSymbol: Int = 0
    @State private var nextSymbol: Int = 1
    @State private var scrollOffset: CGFloat = 0
    @State private var isAnimating = false
    @State private var blurAmount: CGFloat = 0
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.black, Color(white: 0.15), .black], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Text("\(currentSymbol)")
                        .font(.system(size: columnWidth * 0.8, weight: .bold, design: .rounded))
                        .foregroundColor(targetNumber == nil ? .red.opacity(0.7) : .red)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: blurAmount)
                    
                    Text("\(nextSymbol)")
                        .font(.system(size: columnWidth * 0.8, weight: .bold, design: .rounded))
                        .foregroundColor(.red.opacity(0.7))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: blurAmount)
                }
                .offset(y: scrollOffset)
            }
            .clipped()
        }
        .frame(width: columnWidth, height: columnWidth * 1.6)
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
            scrollOffset = columnWidth * 1.6
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            scrollOffset = 0
            currentSymbol = nextSymbol
            nextSymbol = (currentSymbol + 1) % 10
            startRollingLoop(interval: interval, stoppingStartTime: startTime)
        }
    }
}

// MARK: - 老虎机主视图
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
    
    let colWidth: CGFloat = 75
    
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 20) {
                VStack(spacing: 15) {
                    if type.slotColumns == 5 {
                        HStack(spacing: 8) { ForEach(0..<3, id: \.self) { i in slotItem(i) } }
                            .padding(10).background(slotBackground)
                        HStack(spacing: 8) { ForEach(3..<5, id: \.self) { i in slotItem(i) } }
                            .padding(10).background(slotBackground)
                    } else {
                        HStack(spacing: 8) { ForEach(0..<type.slotColumns, id: \.self) { i in slotItem(i) } }
                            .padding(10).background(slotBackground)
                    }
                }
                
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Color.gray).frame(width: 8, height: 50)
                        VStack(spacing: 0) {
                            Circle()
                                .fill(RadialGradient(colors: [.red, .red.opacity(0.8)], center: .center, startRadius: 2, endRadius: 15))
                                .frame(width: 26, height: 26).shadow(radius: 2)
                            Rectangle()
                                .fill(LinearGradient(colors: [.gray, .black], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 4, height: 60)
                        }
                        .offset(y: 8)
                        .rotationEffect(.degrees(leverAngle), anchor: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    func slotItem(_ i: Int) -> some View {
        SlotColumnView(
            index: i,
            targetNumber: $targetNumbers[i],
            columnWidth: colWidth
        )
    }
    
    var slotBackground: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color(white: 0.05))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.red.opacity(0.6), lineWidth: 3))
            .shadow(color: .red.opacity(0.2), radius: 10)
    }
    
    func startSpin() {
        AudioManager.shared.playLoop("slot_roll")
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { leverAngle = 45 }
        
        // 🔥 替换为管理器调用
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
                // 🔥 替换为管理器调用
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
