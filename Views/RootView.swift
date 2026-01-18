import SwiftUI
import SpriteKit

struct RootView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showSettings = false // ✨ 新增设置页状态
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 背景光效
            VStack {
                Spacer()
                Ellipse()
                    .fill(viewModel.currentLottery.style == .slotMachine ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                    .frame(width: 300, height: 120)
                    .blur(radius: 30)
            }
            
            GeometryReader { geo in
                TabView(selection: $viewModel.currentLottery) {
                    ForEach(LotteryType.allCases) { type in
                        MachineContainerView(type: type, size: geo.size, viewModel: viewModel)
                            .tag(type)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .ignoresSafeArea()
            
            VStack {
                // 顶部标题
                Text(viewModel.currentLottery.rawValue)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    .shadow(color: viewModel.currentLottery.style == .slotMachine ? .red : .blue, radius: 10)
                
                Spacer()
                
                // 底部控制区 (传入 Toast 和 Settings 控制权)
                ControlPanelView(
                    viewModel: viewModel,
                    showToast: $showToast,
                    toastMessage: $toastMessage,
                    showSettings: $showSettings
                )
                .padding(.bottom, 30)
            }
            
            // Toast
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(white: 0.2))
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        )
                        .padding(.bottom, 130)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(100)
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $viewModel.showHistory) {
            HistoryListView()
        }
        // ✨ 设置页 Sheet
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - 智能容器
struct MachineContainerView: View {
    let type: LotteryType
    let size: CGSize
    @ObservedObject var viewModel: HomeViewModel
    
    @State private var sceneCache: SKScene?
    
    var body: some View {
        VStack {
            Spacer().frame(height: 80)
            
            if type.style == .bigMixer {
                let mixerHeight = size.height * 0.75
                let actualSize = CGSize(width: size.width, height: mixerHeight)
                SpriteView(scene: getOrCreateScene(size: actualSize), options: [.allowsTransparency])
                    .frame(width: actualSize.width, height: actualSize.height)
            } else {
                Spacer()
                SlotMachineView(type: type) { numbers in
                    viewModel.handleSlotMachineResult(numbers: numbers)
                }
                .frame(width: size.width)
                .offset(y: -20)
                Spacer()
            }
            Spacer().frame(height: 100)
        }
        .onChange(of: type) { _, _ in sceneCache = nil }
    }
    
    func getOrCreateScene(size: CGSize) -> SKScene {
        if let scene = sceneCache, abs(scene.size.width - size.width) < 1.0 { return scene }
        let newScene = LottoScene(size: size, type: type)
        newScene.onBallSelected = { n, c in viewModel.addBall(number: n, color: c) }
        DispatchQueue.main.async { if self.sceneCache == nil { self.sceneCache = newScene } }
        return newScene
    }
}

// MARK: - 控制面板 (新增设置按钮)
struct ControlPanelView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var showToast: Bool
    @Binding var toastMessage: String
    @Binding var showSettings: Bool // ✨ 绑定设置页开关
    
    var body: some View {
        VStack(spacing: 20) {
            
            // 1. 结果区
            Group {
                if !viewModel.selectedBalls.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(viewModel.selectedBalls) { ball in
                            BallView(text: "\(ball.number)", color: ball.color == "red" ? .red : .blue)
                                .transition(.scale)
                        }
                    }
                    .onTapGesture { copyResult() }
                } else {
                    Text(viewModel.status == .idle ? "准备就绪" : "正在开奖...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .frame(height: 50)
            .animation(.spring(), value: viewModel.selectedBalls)
            
            // 2. 主按钮 (使用 HapticManager)
            Button(action: {
                // 🔥 替换为管理器调用
                HapticManager.shared.impact(style: .medium)
                withAnimation { viewModel.onButtonTap() }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(LinearGradient(
                            colors: viewModel.isButtonDisabled ? [.gray] : [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                    
                    Text(viewModel.buttonText)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                .frame(width: 220, height: 60)
                .shadow(color: .red.opacity(0.4), radius: 10, y: 5)
                .scaleEffect(viewModel.isButtonDisabled ? 0.95 : 1.0)
            }
            .disabled(viewModel.isButtonDisabled)
            
            // 3. 辅助按钮区
            HStack(spacing: 30) {
                Button(action: { viewModel.showHistory = true }) {
                    VStack(spacing: 4) { Image(systemName: "clock.arrow.circlepath"); Text("历史") }
                }
                
                Button(action: { viewModel.resetGame() }) {
                    VStack(spacing: 4) { Image(systemName: "arrow.counterclockwise"); Text("重置") }
                }
                
                // ✨ 设置按钮
                Button(action: { showSettings = true }) {
                    VStack(spacing: 4) { Image(systemName: "gearshape.fill"); Text("设置") }
                }
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
    
    func copyResult() {
        let balls = viewModel.selectedBalls
        if balls.isEmpty { return }
        
        var copyString = ""
        if viewModel.currentLottery.style == .slotMachine {
            let nums = balls.map { "\($0.number)" }
            copyString = nums.joined(separator: " ")
        } else {
            let reds = balls.filter { $0.color == "red" }.map { String(format: "%02d", $0.number) }
            let blues = balls.filter { $0.color == "blue" }.map { String(format: "%02d", $0.number) }
            copyString = reds.joined(separator: " ")
            if !blues.isEmpty { copyString += " + \(blues.joined(separator: " "))" }
        }
        
        UIPasteboard.general.string = copyString
        
        // 🔥 替换为管理器调用
        HapticManager.shared.notification(type: .success)
        
        toastMessage = "已复制：\(copyString)"
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showToast = false }
        }
    }
}

// 小球视图保持不变
struct BallView: View {
    let text: String
    let color: Color
    var body: some View {
        ZStack {
            Circle().fill(color)
            Text(text).font(.body.bold()).foregroundColor(.white)
        }
        .frame(width: 40, height: 40)
        .shadow(radius: 2)
    }
}
