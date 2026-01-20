import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    @Published var currentLottery: LotteryType = .doubleColor { didSet { resetGame() } }
    @Published var status: LotteryGameStatus = .idle
    @Published var selectedBalls: [(number: Int, color: String)] = []
    @Published var isSpinning: Bool = false
    @Published var isStoppingAnimation: Bool = false
    @Published var showHistory = false
    @Published var resetTrigger = UUID()
    
    // 弹窗控制
    @Published var showLimitAlert = false
    @Published var showPaywall = false
    
    var buttonText: String {
        if isStoppingAnimation { return "..." }
        switch currentLottery.style {
        case .bigMixer:
            switch status {
            case .idle: return String(localized: "开始摇号")
            case .waitingForBlue: return String(localized: "开始蓝球")
            case .finished: return String(localized: "再来一次")
            default: return "..."
            }
        case .slotMachine:
            return isSpinning ? String(localized: "停止") : String(localized: "开始")
        }
    }
    
    var isButtonDisabled: Bool {
        if isStoppingAnimation { return true }
        if currentLottery.style == .bigMixer {
            return !(status == .idle || status == .waitingForBlue || status == .finished)
        }
        return false
    }
    
    init() { setupObservers() }
    
    func setupObservers() {
        NotificationCenter.default.addObserver(forName: .redPhaseFinished, object: nil, queue: .main) { [weak self] _ in
            if self?.currentLottery.style == .bigMixer {
                if self?.currentLottery == .superLotto || self?.currentLottery == .doubleColor {
                    self?.status = .waitingForBlue
                } else {
                    self?.status = .finished
                    self?.saveRecord()
                }
            }
        }
        NotificationCenter.default.addObserver(forName: .allFinished, object: nil, queue: .main) { [weak self] _ in
            self?.status = .finished
            self?.saveRecord()
        }
    }
    
    func onButtonTap() {
        if isButtonDisabled { return }
        
        let isStarting = (currentLottery.style == .bigMixer && status == .idle) ||
                         (currentLottery.style == .slotMachine && !isSpinning)
        
        if isStarting && !UsageManager.shared.canPlay {
            showLimitAlert = true
            return
        }
        
        if currentLottery.style == .bigMixer {
            handleBigMixerTap()
        } else {
            handleSlotMachineTap()
        }
    }
    
    private func handleBigMixerTap() {
        if status == .idle {
            selectedBalls.removeAll()
            status = .mixingRed
            NotificationCenter.default.post(name: .startRedPhase, object: currentLottery)
        } else if status == .waitingForBlue {
            status = .mixingBlue
            NotificationCenter.default.post(name: .startBluePhase, object: currentLottery)
        } else if status == .finished {
            resetGame()
        }
    }
    
    private func handleSlotMachineTap() {
        if isSpinning {
            NotificationCenter.default.post(name: .stopSlotMachine, object: currentLottery)
            isStoppingAnimation = true
        } else {
            selectedBalls.removeAll()
            isSpinning = true
            NotificationCenter.default.post(name: .startSlotMachine, object: currentLottery)
        }
    }
    
    func saveRecord() {
        let reds = selectedBalls.filter { $0.color == "red" }.map { $0.number }.sorted()
        let blues = selectedBalls.filter { $0.color == "blue" }.map { $0.number }.sorted()
        HistoryManager.shared.add(type: currentLottery, reds: reds, blues: blues)
        
        // 🔥 计次点：保存记录代表完成一次使用
        UsageManager.shared.incrementUsage()
    }
    
    func resetGame() {
        status = .idle
        selectedBalls.removeAll()
        isSpinning = false
        isStoppingAnimation = false
        resetTrigger = UUID()
        NotificationCenter.default.post(name: .resetScene, object: nil)
    }
    
    func addBall(number: Int, color: String) {
        DispatchQueue.main.async { self.selectedBalls.append((number, color)) }
    }
    
    func handleSlotMachineResult(numbers: [Int]) {
        self.selectedBalls = numbers.map { ($0, "red") }
        self.isSpinning = false
        self.isStoppingAnimation = false
        self.status = .finished
        saveRecord()
    }
}

// 🔥 解决编译错误的关键：在此定义状态枚举
enum LotteryGameStatus {
    case idle, mixingRed, extractingRed, waitingForBlue, mixingBlue, extractingBlue, finished
}
