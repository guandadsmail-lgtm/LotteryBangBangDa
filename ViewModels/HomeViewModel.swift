import SwiftUI
import Combine

// 确保通知名称存在
extension Notification.Name {
    static let requestStopMixing = Notification.Name("requestStopMixing")
}

class HomeViewModel: ObservableObject {
    @Published var currentLottery: LotteryType = .doubleColor {
        didSet { resetGame() }
    }
    
    // 🔥 改名了！强制刷新 Xcode 缓存
    @Published var status: LotteryGameStatus = .idle
    
    @Published var selectedBalls: [(number: Int, color: String)] = []
    @Published var isSpinning: Bool = false
    @Published var isStoppingAnimation: Bool = false
    @Published var showHistory = false
    @Published var resetTrigger = UUID()
    
    var buttonText: String {
        if isStoppingAnimation { return "..." }
        switch currentLottery.style {
        case .bigMixer:
            switch status {
            case .idle:
                return String(localized: "开始摇号")
            case .mixingRed:
                return String(localized: "红球搅拌中...") // 按钮禁用
            case .extractingRed:
                return String(localized: "红球出号中...") // 按钮禁用
            case .waitingForBlue:
                return String(localized: "开始蓝球") // ✅ 只有这里按钮可点
            case .mixingBlue:
                return String(localized: "蓝球搅拌中...") // 按钮禁用
            case .extractingBlue:
                return String(localized: "蓝球出号中...") // 按钮禁用
            case .finished:
                return String(localized: "再来一次")
            }
        case .slotMachine:
            return isSpinning ? String(localized: "停止") : String(localized: "开始")
        }
    }
    
    var isButtonDisabled: Bool {
        if isStoppingAnimation { return true }
        switch currentLottery.style {
        case .bigMixer:
            // 🔥 只有闲置、等待蓝球、或结束时，按钮才能点
            // 其他时候（搅拌、出号）全部禁用
            return !(status == .idle || status == .waitingForBlue || status == .finished)
        case .slotMachine:
            return false
        }
    }
    
    init() { setupObservers() }
    
    func setupObservers() {
        NotificationCenter.default.addObserver(forName: .redPhaseFinished, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.currentLottery == .superLotto || self.currentLottery == .doubleColor {
                    self.status = .waitingForBlue
                } else {
                    self.status = .finished
                    self.saveRecord()
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: .allFinished, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.async {
                self?.status = .finished
                self?.saveRecord()
            }
        }
    }
    
    func onButtonTap() {
        if isButtonDisabled { return }
        
        let canStart = (currentLottery.style == .bigMixer && (status == .idle || status == .waitingForBlue)) ||
                       (currentLottery.style == .slotMachine && !isSpinning)
        
        if canStart {
            if !UsageManager.shared.canPlay {
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
            status = .mixingRed
            NotificationCenter.default.post(name: .startRedPhase, object: currentLottery)
            
        case .waitingForBlue:
            status = .mixingBlue
            NotificationCenter.default.post(name: .startBluePhase, object: currentLottery)
            
        case .finished:
            resetGame()
            
        default:
            break
        }
    }
    
    private func handleSlotMachineTap() {
        AudioManager.shared.play("btn_click")
        if isSpinning {
            NotificationCenter.default.post(name: .stopSlotMachine, object: currentLottery)
            isStoppingAnimation = true
        } else {
            AudioManager.shared.playLoop("slot_roll")
            resetData()
            isSpinning = true
            NotificationCenter.default.post(name: .startSlotMachine, object: currentLottery)
        }
    }
    
    func addBall(number: Int, color: String) {
        DispatchQueue.main.async {
            self.selectedBalls.append((number, color))
        }
    }
    
    func handleSlotMachineResult(numbers: [Int]) {
        AudioManager.shared.stopLoop("slot_roll")
        self.selectedBalls = numbers.map { ($0, "red") }
        self.isSpinning = false
        self.isStoppingAnimation = false
        self.status = .finished
        saveRecord()
    }
    
    func resetGame() {
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
        if currentLottery.style == .slotMachine { AudioManager.shared.play("win") }
    }
}

// 🔥 全新枚举名：LotteryGameStatus
enum LotteryGameStatus {
    case idle
    case mixingRed
    case extractingRed
    case waitingForBlue
    case mixingBlue
    case extractingBlue
    case finished
}
