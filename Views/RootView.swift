import SwiftUI
import SpriteKit

struct RootView: View {
    @StateObject private var viewModel = HomeViewModel()
    @AppStorage("hasAgreedCompliance") var hasAgreedCompliance: Bool = false
    
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showSettings = false
    @State private var showPaywall = false
    
    let paywallNotification = NotificationCenter.default.publisher(for: .showPaywall)
    
    var body: some View {
        Group {
            if hasAgreedCompliance {
                MainContent
            } else {
                ComplianceView(hasAgreed: $hasAgreedCompliance)
            }
        }
    }
    
    var MainContent: some View {
        ZStack(alignment: .top) {
            Color(hex: "050505").ignoresSafeArea()
            
            // 1. 氛围光
            Group {
                RadialGradient(gradient: Gradient(colors: [topLightColor.opacity(0.3), .clear]), center: .top, startRadius: 0, endRadius: 600)
                RadialGradient(gradient: Gradient(colors: [bottomLightColor.opacity(0.2), .clear]), center: .bottom, startRadius: 0, endRadius: 500)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: viewModel.currentLottery)
            
            // 2. 机器容器
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
            
            // 3. 顶部灵动岛
            TopFloatingIsland(viewModel: viewModel)
                .padding(.top, 10)
                .zIndex(10)
            
            // 提示文字
            if !UsageManager.shared.isVip {
                Text(UsageManager.shared.remainingText)
                    .font(.caption2.monospaced())
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                    .padding(.top, 110)
                    .transition(.opacity)
            }
            
            // 4. 底部面板
            VStack {
                Spacer()
                ControlPanelView(
                    viewModel: viewModel,
                    showToast: $showToast,
                    toastMessage: $toastMessage,
                    showSettings: $showSettings
                )
                .padding(.bottom, 10)
            }
            
            // 5. Toast
            if showToast {
                ToastView(message: toastMessage)
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $viewModel.showHistory) { HistoryListView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onReceive(paywallNotification) { _ in showPaywall = true }
    }
    
    var topLightColor: Color { viewModel.currentLottery.style == .slotMachine ? .lotteryRed : .lotteryBlue }
    var bottomLightColor: Color { viewModel.currentLottery.style == .slotMachine ? .lotteryBlue : .lotteryRed }
}

struct ToastView: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                Text(message)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(Color(hex: "1C1C1E").opacity(0.9))
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
            )
            .padding(.bottom, 130)
            .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
        }
        .zIndex(100)
    }
}

// 灵动岛
struct TopFloatingIsland: View {
    @ObservedObject var viewModel: HomeViewModel
    var body: some View {
        HStack {
            Button(action: { switchLottery(offset: -1) }) {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundColor(.white.opacity(0.4)).frame(width: 40, height: 40).contentShape(Rectangle())
            }
            Spacer()
            VStack(spacing: 6) {
                Text(viewModel.currentLottery.rawValue).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundColor(.white).shadow(color: themeColor.opacity(0.5), radius: 8)
                HStack(spacing: 6) {
                    ForEach(LotteryType.allCases.indices, id: \.self) { index in
                        Capsule().fill(viewModel.currentLottery == LotteryType.allCases[index] ? .white : .white.opacity(0.2)).frame(width: viewModel.currentLottery == LotteryType.allCases[index] ? 16 : 6, height: 4).animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.currentLottery)
                    }
                }
            }
            Spacer()
            Button(action: { switchLottery(offset: 1) }) {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).foregroundColor(.white.opacity(0.4)).frame(width: 40, height: 40).contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 8).frame(height: 64)
        .background(Capsule().fill(.ultraThinMaterial).overlay(Capsule().stroke(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)).shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 5))
        .padding(.horizontal, 20)
    }
    var themeColor: Color { viewModel.currentLottery.style == .slotMachine ? .lotteryRed : .lotteryBlue }
    func switchLottery(offset: Int) {
        HapticManager.shared.impact(style: .light)
        guard let currentIndex = LotteryType.allCases.firstIndex(of: viewModel.currentLottery) else { return }
        let nextIndex = currentIndex + offset
        if nextIndex >= 0 && nextIndex < LotteryType.allCases.count {
            withAnimation(.spring()) { viewModel.currentLottery = LotteryType.allCases[nextIndex] }
        }
    }
}

struct MachineContainerView: View {
    let type: LotteryType
    let size: CGSize
    @ObservedObject var viewModel: HomeViewModel
    @State private var sceneCache: SKScene?
    var body: some View {
        VStack {
            if type.style == .bigMixer {
                let mixerHeight = size.height * 0.65
                let actualSize = CGSize(width: size.width, height: mixerHeight)
                SpriteView(scene: getOrCreateScene(size: actualSize), options: [.allowsTransparency]).frame(width: actualSize.width, height: actualSize.height).offset(y: 20)
            } else {
                Spacer()
                SlotMachineView(type: type) { numbers in viewModel.handleSlotMachineResult(numbers: numbers) }
                    .frame(width: size.width)
                    .offset(y: -20)
                    .id(viewModel.resetTrigger) // 🔥🔥🔥 核心修复：绑定 resetTrigger，强制重置视图
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// ✅ 核心控制面板
struct ControlPanelView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var showToast: Bool
    @Binding var toastMessage: String
    @Binding var showSettings: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            
            // 1. 数字展示槽
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
                
                if !viewModel.selectedBalls.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.selectedBalls.enumerated()), id: \.offset) { index, ball in
                            BallView(
                                text: "\(ball.number)",
                                color: ball.color == "blue" ? .lotteryBlue : .lotteryRed
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .onTapGesture { copyResult() }
                } else {
                    HStack(spacing: 8) {
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 6, height: 6)
                        Text(viewModel.status == .idle ? "READY" : "PROCESSING...")
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundColor(.gray.opacity(0.5))
                            .tracking(2)
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
            }
            .frame(height: 56)
            .padding(.horizontal, 24)
            
            // 2. 操作区
            HStack(spacing: 16) {
                GlassButton(icon: "clock.arrow.circlepath") { viewModel.showHistory = true }
                MainButtonView(viewModel: viewModel)
                GlassButton(icon: "gearshape.fill") { showSettings = true }
            }
            .padding(.horizontal, 30)
            
            // 3. 重置按钮
            Button(action: {
                HapticManager.shared.notification(type: .warning)
                viewModel.resetGame()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 10, weight: .bold))
                    Text("RESET").font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.3))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .padding(.top, 0)
        }
        .offset(y: 30)
        .padding(.vertical, 10)
        .background(GlassBackgroundView().offset(y: 30))
    }
    
    struct GlassBackgroundView: View {
        var body: some View {
            ZStack {
                Color.red.opacity(0.2).blendMode(.overlay)
                Color.black.opacity(0.5)
                Rectangle().foregroundStyle(.ultraThinMaterial)
            }
            .cornerRadius(40, corners: [.topLeft, .topRight])
            .ignoresSafeArea()
            .overlay(RoundedRectangle(cornerRadius: 40).stroke(LinearGradient(colors: [.white.opacity(0.2), .red.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1).mask(VStack { Rectangle().frame(height: 100); Spacer() }))
            .shadow(color: .black, radius: 20, y: -10)
        }
    }
    
    func GlassButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.white.opacity(0.05)).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)).frame(width: 50, height: 50)
                Image(systemName: icon).font(.system(size: 20)).foregroundColor(.white.opacity(0.9))
            }
        }
    }
    
    func copyResult() {
        let balls = viewModel.selectedBalls
        if balls.isEmpty { return }
        var copyString = ""
        if viewModel.currentLottery.style == .slotMachine {
            copyString = balls.map { "\($0.number)" }.joined(separator: " ")
        } else {
            let reds = balls.filter { $0.color == "red" }.map { String(format: "%02d", $0.number) }
            let blues = balls.filter { $0.color == "blue" }.map { String(format: "%02d", $0.number) }
            copyString = reds.joined(separator: " ")
            if !blues.isEmpty { copyString += " + \(blues.joined(separator: " "))" }
        }
        UIPasteboard.general.string = copyString
        HapticManager.shared.notification(type: .success)
        toastMessage = "已复制：\(copyString)"
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { withAnimation { showToast = false } }
    }
}

struct MainButtonView: View {
    @ObservedObject var viewModel: HomeViewModel
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            withAnimation { viewModel.onButtonTap() }
        }) {
            ZStack {
                if !viewModel.isButtonDisabled {
                    RoundedRectangle(cornerRadius: 35).fill(LinearGradient(colors: [.orange, .lotteryRed], startPoint: .topLeading, endPoint: .bottomTrailing)).blur(radius: 12).opacity(0.4).frame(width: 140, height: 40).offset(y: 8)
                }
                RoundedRectangle(cornerRadius: 35)
                    .fill(LinearGradient(colors: viewModel.isButtonDisabled ? [Color(white: 0.2)] : [Color(hex: "FF512F"), Color(hex: "DD2476")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 35).stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                
                HStack(spacing: 8) {
                    if viewModel.isSpinning || viewModel.status == .runningRed || viewModel.status == .runningBlue {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.buttonText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.isButtonDisabled ? .white.opacity(0.3) : .white)
                }
            }
            .frame(height: 72)
            .scaleEffect(viewModel.isButtonDisabled ? 0.98 : 1.0)
        }
        .disabled(viewModel.isButtonDisabled)
        .frame(maxWidth: .infinity)
    }
}

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
