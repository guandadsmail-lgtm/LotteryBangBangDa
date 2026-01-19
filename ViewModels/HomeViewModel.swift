import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    // MARK: - 核心状态
    @Published var currentLottery: LotteryType = .doubleColor {
        didSet { resetGame() }
    }
    
    @Published var status: GameStatus = .idle
    @Published var selectedBalls: [(number: Int, color: String)] = []
    @Published var isSpinning: Bool = false
    @Published var isStoppingAnimation: Bool = false
    @Published var showHistory = false
    
    // 🔥 强制重置信号
    @Published var resetTrigger = UUID()
    
    // 按钮文字逻辑
    var buttonText: String {
        if isStoppingAnimation { return "..." }
        switch currentLottery.style {
        case .bigMixer:
            switch status {
            case .idle: return "开始摇号"
            case .runningRed: return "红球摇号中..."
            case .runningBlue: return "蓝球摇号中..."
            case .finished: return "再来一次"
            }
        case .slotMachine:
            return isSpinning ? "停止" : "开始"
        }
    }
    
    // 按钮禁用逻辑
    var isButtonDisabled: Bool {
        if isStoppingAnimation { return true }
        switch currentLottery.style {
        case .bigMixer:
            // 搅拌机全自动，运行中禁用按钮
            return status == .runningRed || status == .runningBlue
        case .slotMachine:
            return false
        }
    }
    
    // MARK: - 初始化
    init() {
        // ⚠️ 测试代码：开发完请注释掉
        // UsageManager.shared.resetTrial()
        
        setupObservers()
    }
    
    func setupObservers() {
        NotificationCenter.default.addObserver(forName: .redPhaseFinished, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if self.currentLottery == .superLotto || self.currentLottery == .doubleColor {
                self.status = .runningBlue
                NotificationCenter.default.post(name: .startBluePhase, object: self.currentLottery)
            } else {
                self.status = .finished
                self.saveRecord()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .allFinished, object: nil, queue: .main) { [weak self] _ in
            self?.status = .finished
            self?.saveRecord()
        }
    }
    
    // MARK: - 交互逻辑
    func onButtonTap() {
        // 1. 拦截检查
        let isNewGameStart = (currentLottery.style == .bigMixer && status == .idle) ||
                             (currentLottery.style == .slotMachine && !isSpinning)
        
        if isNewGameStart {
            if !UsageManager.shared.canPlay {
                // 没次数了，也播放个点击声反馈一下
                AudioManager.shared.play("btn_click")
                NotificationCenter.default.post(name: .showPaywall, object: nil)
                return
            }
        }
        
        if currentLottery.style == .bigMixer {
            handleBigMixerTap()
        } else {
            handleSlotMachineTap()
        }
    }
    
    private func handleBigMixerTap() {
        AudioManager.shared.play("btn_click")
        switch status {
        case .idle:
            resetData()
            status = .runningRed
            NotificationCenter.default.post(name: .startRedPhase, object: currentLottery)
        case .runningRed, .runningBlue:
            break
        case .finished:
            resetGame()
        }
    }
    
    private func handleSlotMachineTap() {
        // 🔊 无论开始还是停止，都只播放清脆的点击声
        AudioManager.shared.play("btn_click")
        
        if isSpinning {
            // 🛑 停止逻辑
            
            // 🔥🔥🔥 关键修改：点击停止时，只改变状态，不停止背景音效！
            // AudioManager.shared.stopLoop("slot_roll") // <--- 这一行删掉了
            
            isStoppingAnimation = true
            NotificationCenter.default.post(name: .stopSlotMachine, object: currentLottery)
        } else {
            // ▶️ 开始逻辑
            AudioManager.shared.playLoop("slot_roll")
            
            resetData()
            isSpinning = true
            NotificationCenter.default.post(name: .startSlotMachine, object: currentLottery)
        }
    }
    
    // MARK: - 数据回调
    func addBall(number: Int, color: String) {
        DispatchQueue.main.async {
            self.selectedBalls.append((number, color))
        }
    }
    
    func handleSlotMachineResult(numbers: [Int]) {
        // 🔥🔥🔥 关键修改：当数字真正出来时，才停止背景音效
        AudioManager.shared.stopLoop("slot_roll")
        
        self.selectedBalls = numbers.map { ($0, "red") }
        self.isSpinning = false
        self.isStoppingAnimation = false
        self.status = .finished
        saveRecord()
    }
    
    func resetGame() {
        // 重置时如果老虎机还在转，必须强制关掉声音
        AudioManager.shared.stopLoop("slot_roll")
        AudioManager.shared.play("btn_click")
        
        status = .idle
        resetData()
        isSpinning = false
        isStoppingAnimation = false
        
        resetTrigger = UUID()
        
        NotificationCenter.default.post(name: .resetScene, object: nil)
    }
    
    private func resetData() {
        selectedBalls.removeAll()
    }
    
    private func saveRecord() {
        let reds = selectedBalls.filter { $0.color == "red" }.map { $0.number }.sorted()
        let blues = selectedBalls.filter { $0.color == "blue" }.map { $0.number }.sorted()
        
        HistoryManager.shared.add(type: currentLottery, reds: reds, blues: blues)
        UsageManager.shared.incrementUsage()
        
        if currentLottery.style == .slotMachine {
            AudioManager.shared.play("win")
        }
    }
}

enum GameStatus {
    case idle
    case runningRed
    case runningBlue
    case finished
}
