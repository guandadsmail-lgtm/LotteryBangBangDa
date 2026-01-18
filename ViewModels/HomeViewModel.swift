import SwiftUI
import Combine

class HomeViewModel: ObservableObject {
    enum GameStatus {
        case idle
        case runningRed
        case waitingForBlue
        case runningBlue
        case finished
    }
    
    // 用来打包保存每个彩种的“现场”
    struct LotteryState {
        var status: GameStatus = .idle
        var balls: [BallResult] = []
        var isSpinning: Bool = false
    }
    
    // MARK: - Published Properties
    
    @Published var currentLottery: LotteryType = .ssq {
        didSet {
            if oldValue != currentLottery {
                switchLottery(from: oldValue, to: currentLottery)
            }
        }
    }
    
    @Published var status: GameStatus = .idle
    @Published var selectedBalls: [BallResult] = []
    @Published var showHistory: Bool = false
    
    // 老虎机状态
    @Published var isSpinning: Bool = false
    @Published var isStoppingAnimation: Bool = false
    
    // 💾 状态仓库
    private var stateCache: [LotteryType: LotteryState] = [:]
    
    struct BallResult: Identifiable, Equatable {
        let id = UUID()
        let number: Int
        let color: String
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    // MARK: - 切换逻辑
    private func switchLottery(from oldType: LotteryType, to newType: LotteryType) {
        let safeStatus: GameStatus = (status == .runningRed || status == .runningBlue) ? .idle : status
        let safeSpinning = false
        stateCache[oldType] = LotteryState(status: safeStatus, balls: selectedBalls, isSpinning: safeSpinning)
        
        if let savedState = stateCache[newType] {
            self.status = savedState.status
            self.selectedBalls = savedState.balls
            self.isSpinning = savedState.isSpinning
        } else {
            self.status = .idle
            self.selectedBalls = []
            self.isSpinning = false
        }
        self.isStoppingAnimation = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .resetScene, object: nil)
        }
    }
    
    // MARK: - 用户操作
    
    func onButtonTap() {
        if isStoppingAnimation { return }
        
        // ==========================
        // 模式 A: 物理搅拌机 (双色球/大乐透)
        // ==========================
        if currentLottery.style == .bigMixer {
            switch status {
            case .idle:
                startRedPhase()
            case .finished:
                // 强制重置
                resetGame()
            case .waitingForBlue:
                startBluePhase()
            default: break
            }
        }
        // ==========================
        // 模式 B: 老虎机 (3D/排三/排五)
        // ==========================
        else {
            if isSpinning {
                isSpinning = false
                isStoppingAnimation = true
                NotificationCenter.default.post(name: .stopSlotMachine, object: currentLottery)
            } else {
                resetGameData()
                isSpinning = true
                status = .runningRed
                NotificationCenter.default.post(name: .startSlotMachine, object: currentLottery)
            }
        }
    }
    
    func handleSlotMachineResult(numbers: [Int]) {
        self.selectedBalls = numbers.map { BallResult(number: $0, color: "red") }
        self.status = .finished
        self.isSpinning = false
        self.isStoppingAnimation = false
        self.saveCurrentResult()
        updateCurrentCache()
    }
    
    // MARK: - 内部逻辑
    
    private func startRedPhase() {
        status = .runningRed
        selectedBalls.removeAll()
        NotificationCenter.default.post(name: .startRedPhase, object: currentLottery)
    }
    
    private func startBluePhase() {
        status = .runningBlue
        NotificationCenter.default.post(name: .startBluePhase, object: currentLottery)
    }
    
    func addBall(number: Int, color: String) {
        if !self.selectedBalls.contains(where: { $0.number == number && $0.color == color }) {
            self.selectedBalls.append(BallResult(number: number, color: color))
        }
    }
    
    func resetGame() {
        resetGameData()
        isSpinning = false
        isStoppingAnimation = false
        NotificationCenter.default.post(name: .resetScene, object: nil)
        updateCurrentCache()
    }
    
    private func resetGameData() {
        selectedBalls.removeAll()
        status = .idle
    }
    
    private func updateCurrentCache() {
        stateCache[currentLottery] = LotteryState(status: status, balls: selectedBalls, isSpinning: isSpinning)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .redPhaseFinished)
            .sink { [weak self] _ in
                self?.status = .waitingForBlue
                self?.updateCurrentCache()
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .allFinished)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.status = .finished
                self.saveCurrentResult()
                self.updateCurrentCache()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 保存结果 (核心修改：排序逻辑)
    private func saveCurrentResult() {
        
        var finalReds: [BallResult]
        var finalBlues: [BallResult]
        
        // 1. 分组
        let rawReds = selectedBalls.filter { $0.color == "red" }
        let rawBlues = selectedBalls.filter { $0.color == "blue" }
        
        // 2. 排序逻辑
        if currentLottery.style == .bigMixer {
            // 🔥 双色球/大乐透：红球蓝球分别按数字从小到大排序
            finalReds = rawReds.sorted { $0.number < $1.number }
            finalBlues = rawBlues.sorted { $0.number < $1.number }
            
            // 为了让界面上的“复制”功能也生效，同时更新 selectedBalls 的显示顺序
            // 重新组合 selectedBalls (红排好 + 蓝排好)
            DispatchQueue.main.async {
                self.selectedBalls = finalReds + finalBlues
            }
        } else {
            // 🔥 老虎机：保持原样 (按位置顺序)
            finalReds = rawReds
            finalBlues = rawBlues
        }
        
        // 3. 转换并保存
        let savedReds = finalReds.map { LotteryBall(number: $0.number, color: "red") }
        let savedBlues = finalBlues.map { LotteryBall(number: $0.number, color: "blue") }
        
        let result = LotteryResult(type: currentLottery, date: Date(), primaryBalls: savedReds, secondaryBalls: savedBlues)
        HistoryManager.shared.save(result: result)
    }
    
    // MARK: - UI 文本与状态
    
    var buttonText: String {
        if currentLottery.style == .bigMixer {
            switch status {
            case .idle: return "开始摇号"
            case .runningRed: return "红球摇号中..."
            case .waitingForBlue: return "开始摇蓝球"
            case .runningBlue: return "蓝球摇号中..."
            case .finished: return "请点击重置"
            }
        } else {
            if isStoppingAnimation { return "正在停止..." }
            return isSpinning ? "停止" : "开始摇号"
        }
    }
    
    var isButtonDisabled: Bool {
        if currentLottery.style == .bigMixer {
            return status == .runningRed || status == .runningBlue
        } else {
            return isStoppingAnimation
        }
    }
}
