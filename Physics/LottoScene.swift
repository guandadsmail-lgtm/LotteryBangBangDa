import SwiftUI
import SpriteKit
import Foundation

// 阶段控制
enum LotteryPhase {
    case red  // 红球阶段
    case blue // 蓝球阶段
    case idle // 空闲
}

class LottoScene: SKScene {
    private var hasContentCreated = false
    var lotteryType: LotteryType
    
    // MARK: - 节点引用
    private var turbulenceField: SKFieldNode?
    private var vortexField: SKFieldNode?
    private var doorNode: SKShapeNode?
    
    // 容器参数
    private var containerRadius: CGFloat = 190.0
    private let centerOffsetY: CGFloat = 40.0
    private let doorArcAngle: CGFloat = 0.32
    
    let MAX_SPEED: CGFloat = 350.0
    
    // 🚦 状态机
    private var isExtracting = false
    private var extractedCount = 0
    private var targetCount = 0
    private var isBluePhase = false
    
    var onBallSelected: ((Int, String) -> Void)?
    
    init(size: CGSize, type: LotteryType) {
        self.lotteryType = type
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        self.scaleMode = .aspectFit
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        if !hasContentCreated {
            createStaticContainer()
            fillBalls(isRed: true)
            hasContentCreated = true
        }
        setupObservers()
    }
    
    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupObservers() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(startRedPhase(_:)), name: .startRedPhase, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startBluePhase(_:)), name: .startBluePhase, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetScene), name: .resetScene, object: nil)
    }
    
    // MARK: - 构建静态容器
    func createStaticContainer() {
        self.backgroundColor = .clear
        
        let maxRadius: CGFloat = 200.0
        let calculatedRadius = (self.size.width / 2) - 20.0
        self.containerRadius = min(calculatedRadius, maxRadius)
        
        let startAngle = -CGFloat.pi / 2 + doorArcAngle / 2
        let endAngle = -CGFloat.pi / 2 - doorArcAngle / 2 + CGFloat.pi * 2
        let wallPath = UIBezierPath(arcCenter: .zero, radius: containerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        let wallNode = SKShapeNode(path: wallPath.cgPath)
        wallNode.name = "wall"
        wallNode.strokeColor = .white.withAlphaComponent(0.3)
        wallNode.lineWidth = 5
        wallNode.position = CGPoint(x: 0, y: centerOffsetY)
        
        let wallBody = SKPhysicsBody(edgeChainFrom: wallPath.cgPath)
        wallBody.friction = 0.0
        wallBody.categoryBitMask = GameEngineConfig.categoryWall
        wallNode.physicsBody = wallBody
        addChild(wallNode)
        
        let bgCircle = SKShapeNode(circleOfRadius: containerRadius)
        bgCircle.fillColor = .black.withAlphaComponent(0.2)
        bgCircle.strokeColor = .clear
        bgCircle.zPosition = -1
        bgCircle.position = CGPoint(x: 0, y: centerOffsetY)
        addChild(bgCircle)
        
        let doorStart = -CGFloat.pi / 2 - doorArcAngle / 2
        let doorEnd = -CGFloat.pi / 2 + doorArcAngle / 2
        let doorPath = UIBezierPath(arcCenter: .zero, radius: containerRadius, startAngle: doorStart, endAngle: doorEnd, clockwise: true)
        
        doorNode = SKShapeNode(path: doorPath.cgPath)
        doorNode?.strokeColor = .white.withAlphaComponent(0.5)
        doorNode?.lineWidth = 5
        doorNode?.position = CGPoint(x: 0, y: centerOffsetY)
        if let door = doorNode {
            addChild(door)
            closeDoor()
        }
        
        let turb = SKFieldNode.turbulenceField(withSmoothness: 0.4, animationSpeed: 0.5)
        turb.strength = 0
        wallNode.addChild(turb)
        turbulenceField = turb
        
        let vor = SKFieldNode.vortexField()
        vor.strength = 0
        wallNode.addChild(vor)
        vortexField = vor
    }
    
    // MARK: - 阶段控制
    
    @objc func startRedPhase(_ notification: Notification) {
        guard let type = notification.object as? LotteryType, type == self.lotteryType else { return }
        
        // 🎵 开始循环播放背景音
        AudioManager.shared.playLoop("mixer_loop")
        
        forceReset()
        isBluePhase = false
        targetCount = lotteryType.redConfig.count
        fillBalls(isRed: true)
        startPhysicsSequence(duration: GameEngineConfig.Timing.turbulenceDuration)
    }
    
    private func forceReset() {
        self.removeAllActions()
        self.children.forEach { $0.removeAllActions() }
        extractedCount = 0
        isExtracting = false
        removeBalls()
        closeDoor()
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
    }
    
    @objc func startBluePhase(_ notification: Notification) {
        guard let type = notification.object as? LotteryType, type == self.lotteryType else { return }
        
        // 🎵 开始循环播放背景音
        AudioManager.shared.playLoop("mixer_loop")
        
        self.removeAllActions()
        isBluePhase = true
        extractedCount = 0
        isExtracting = false
        targetCount = lotteryType.blueConfig.count
        closeDoor()
        startPhysicsSequence(duration: GameEngineConfig.Timing.turbulenceDuration)
    }
    
    @objc func resetScene() {
        // 重置时强制停止声音
        AudioManager.shared.stopLoop("mixer_loop")
        forceReset()
        fillBalls(isRed: true)
    }
    
    private func finishCurrentPhase() {
        if !isBluePhase {
            isExtracting = false
            let wait = SKAction.wait(forDuration: 1.0)
            let prepare = SKAction.run { [weak self] in self?.prepareBlueBallsStatic() }
            run(SKAction.sequence([wait, prepare]))
        } else {
            isExtracting = false
            NotificationCenter.default.post(name: .allFinished, object: nil)
        }
    }
    
    private func prepareBlueBallsStatic() {
        removeBalls()
        closeDoor()
        fillBalls(isRed: false)
        NotificationCenter.default.post(name: .redPhaseFinished, object: nil)
    }
    
    // MARK: - 球体管理
    func fillBalls(isRed: Bool) {
        removeBalls()
        let range = isRed ? lotteryType.redConfig.range : lotteryType.blueConfig.range
        let colorHex = isRed ? GameEngineConfig.redBallColor : GameEngineConfig.blueBallColor
        
        for i in range {
            let r = GameEngineConfig.ballRadius * 1.1
            let ball = SKShapeNode(circleOfRadius: r)
            ball.name = "ball"
            let safe = containerRadius * 0.6
            ball.position = CGPoint(x: CGFloat.random(in: -safe...safe), y: CGFloat.random(in: -safe...safe) + centerOffsetY)
            ball.fillColor = hexColor(colorHex)
            ball.strokeColor = .clear
            
            let label = SKLabelNode(text: "\(i)")
            label.fontSize = 14
            label.fontName = "Menlo-Bold"
            label.verticalAlignmentMode = .center
            label.fontColor = .white
            ball.addChild(label)
            
            let body = SKPhysicsBody(circleOfRadius: r)
            body.mass = 0.05
            body.restitution = 0.5
            body.friction = 0.0
            body.linearDamping = 0.2
            body.categoryBitMask = GameEngineConfig.categoryBall
            body.collisionBitMask = GameEngineConfig.categoryWall | GameEngineConfig.categoryBall
            ball.physicsBody = body
            addChild(ball)
        }
    }
    
    func removeBalls() {
        enumerateChildNodes(withName: "ball") { node, _ in
            node.removeFromParent()
        }
    }
    
    func hexColor(_ hex: String) -> SKColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return SKColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    override func update(_ currentTime: TimeInterval) {
        let ballRadius = GameEngineConfig.ballRadius * 1.1
        let maxDist = containerRadius - ballRadius
        
        for node in children {
            if node.name != "ball" { continue }
            guard let body = node.physicsBody else { continue }
            if node.userData?["isProcessed"] as? Bool == true { continue }
            
            if body.velocity.dx != 0 || body.velocity.dy != 0 {
                let speed = sqrt(body.velocity.dx*body.velocity.dx + body.velocity.dy*body.velocity.dy)
                if speed > MAX_SPEED {
                    let ratio = MAX_SPEED / speed
                    body.velocity = CGVector(dx: body.velocity.dx * ratio, dy: body.velocity.dy * ratio)
                }
            }
            
            let dx = node.position.x
            let dy = node.position.y - centerOffsetY
            let distSq = dx*dx + dy*dy
            let dist = sqrt(distSq)
            
            if dist > maxDist {
                let angle = atan2(dy, dx)
                let angleDiff = abs(angle - (-CGFloat.pi / 2))
                let isAtDoor = angleDiff < (doorArcAngle / 1.1)
                let isDoorOpen = (doorNode?.physicsBody == nil)
                let hasQuota = extractedCount < targetCount
                
                if isAtDoor && isDoorOpen && hasQuota && isExtracting {
                    body.applyForce(CGVector(dx: 0, dy: -15.0))
                    if dist > containerRadius + 30 { handleBallEscape(node) }
                } else {
                    if dist > maxDist + 10 {
                        node.position.x = cos(angle) * (maxDist - 2)
                        node.position.y = sin(angle) * (maxDist - 2) + centerOffsetY
                        body.velocity.dx = -body.velocity.dx * 0.8
                        body.velocity.dy = -body.velocity.dy * 0.8
                    }
                }
            }
        }
        
        if extractedCount >= targetCount && targetCount > 0 {
            if doorNode?.physicsBody == nil { closeDoor() }
        }
    }
    
    private func handleBallEscape(_ ballNode: SKNode) {
        guard ballNode.physicsBody != nil, ballNode.userData?["isProcessed"] == nil else { return }
        ballNode.userData = ["isProcessed": true]
        extractedCount += 1
        ballNode.physicsBody = nil
        
        // 🎵 播放单个球掉落声
        AudioManager.shared.play("ball_drop")
        
        // 🔥🔥 核心修改：检测是否所有球都抓完了 🔥🔥
        if self.extractedCount >= self.targetCount {
            // 🛑 任务完成，停止背景轰鸣声
            AudioManager.shared.stopLoop("mixer_loop")
        }
        
        let dropTarget = CGPoint(x: 0, y: -self.size.height/2 + 20)
        ballNode.run(SKAction.sequence([
            SKAction.move(to: dropTarget, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                if let label = ballNode.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode,
                   let text = label.text, let number = Int(text) {
                    let color = self.isBluePhase ? "blue" : "red"
                    self.onBallSelected?(number, color)
                }
                if self.extractedCount >= self.targetCount {
                    self.finishCurrentPhase()
                }
            }
        ]))
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        closeDoor()
    }

    private func startPhysicsSequence(duration: TimeInterval) {
        vortexField?.strength = 0.2
        turbulenceField?.strength = 30.0
        turbulenceField?.animationSpeed = 3.0
        physicsWorld.gravity = CGVector(dx: 0, dy: 10.0)
        
        enumerateChildNodes(withName: "ball") { node, _ in
            node.physicsBody?.applyImpulse(CGVector(dx: CGFloat.random(in: -5...5), dy: CGFloat.random(in: -5...10)))
        }
        
        let waitTurbulence = SKAction.wait(forDuration: duration)
        let calmDown = SKAction.run { [weak self] in self?.stopStirring() }
        let waitSettle = SKAction.wait(forDuration: 1.5)
        let startExtract = SKAction.run { [weak self] in self?.startExtractingLoop() }
        run(SKAction.sequence([waitTurbulence, calmDown, waitSettle, startExtract]))
    }
    
    private func startExtractingLoop() {
        isExtracting = true
        let releaseOne = SKAction.run { [weak self] in
            if let self = self, self.extractedCount < self.targetCount {
                self.openDoor()
                self.shakeContainer()
            }
        }
        let interval = SKAction.wait(forDuration: 1.2)
        let seq = SKAction.sequence([releaseOne, interval])
        let loop = SKAction.repeat(seq, count: targetCount + 4)
        let finish = SKAction.run { [weak self] in
            self?.isExtracting = false
            self?.closeDoor()
        }
        run(SKAction.sequence([loop, finish]))
    }

    func stopStirring() {
        // 🔥 这里不再停止声音，让声音延续到吸球结束
        // AudioManager.shared.stopLoop("mixer_loop")
        
        vortexField?.strength = 0
        turbulenceField?.strength = 0
        physicsWorld.gravity = CGVector(dx: 0, dy: -6.0)
        enumerateChildNodes(withName: "ball") { node, _ in
            node.physicsBody?.angularVelocity *= 0.5
        }
    }
    
    func shakeContainer() {
        enumerateChildNodes(withName: "ball") { node, _ in
            node.physicsBody?.applyImpulse(CGVector(dx: CGFloat.random(in: -2...2), dy: 0))
        }
    }
    
    private func openDoor() {
        doorNode?.physicsBody = nil
        doorNode?.strokeColor = .gray.withAlphaComponent(0.1)
    }
    
    private func closeDoor() {
        guard let door = doorNode else { return }
        door.physicsBody = nil
        
        let startAngle = -CGFloat.pi / 2 - doorArcAngle / 2
        let endAngle = -CGFloat.pi / 2 + doorArcAngle / 2
        let doorPath = UIBezierPath(arcCenter: .zero, radius: containerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        let body = SKPhysicsBody(edgeChainFrom: doorPath.cgPath)
        body.categoryBitMask = GameEngineConfig.categoryWall
        body.friction = 0.0
        
        door.physicsBody = body
        door.strokeColor = .white.withAlphaComponent(0.5)
    }
}
