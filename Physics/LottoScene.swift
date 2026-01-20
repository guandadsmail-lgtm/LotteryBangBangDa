import SwiftUI
import SpriteKit
import Foundation

enum LotteryPhase {
    case red, blue, idle
}

class LottoScene: SKScene {
    // MARK: - 1. 物理配置参数
    private let MAX_SPEED: CGFloat = 400.0
    private let CONTAINER_RADIUS: CGFloat = 190.0
    private let DOOR_ARC_ANGLE: CGFloat = 0.28
    private let centerOffsetY: CGFloat = 40.0
    
    var lotteryType: LotteryType
    private var hasContentCreated = false
    
    // 节点
    private var doorNode: SKShapeNode?
    private var containerVisuals: SKNode? // 🔥 视觉容器，用于摇晃动画
    
    // 物理场
    private var turbulenceField: SKFieldNode?
    private var vortexField: SKFieldNode?
    private var stirringField: SKFieldNode?
    
    // 状态控制
    private var isExtracting = false
    private var extractedCount = 0
    private var targetCount = 0
    private var isBluePhase = false
    
    // 核心锁
    private var isDoorOpen = false
    private var lastProcessTime: TimeInterval = 0
    
    var onBallSelected: ((Int, String) -> Void)?
    
    init(size: CGSize, type: LotteryType) {
        self.lotteryType = type
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func didMove(to view: SKView) {
        self.scaleMode = .aspectFill
        self.backgroundColor = .clear
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        
        if !hasContentCreated {
            createStaticContainer()
            fillBalls(isRed: true)
            hasContentCreated = true
        }
        setupObservers()
    }
    
    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
        AudioManager.shared.stopLoop("mixer_loop")
    }
    
    func setupObservers() {
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(startRedPhase(_:)), name: .startRedPhase, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startBluePhase(_:)), name: .startBluePhase, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetScene), name: .resetScene, object: nil)
    }
    
    // MARK: - 2. 容器构建 (视觉与物理分离)
    func createStaticContainer() {
        let startAngle = -CGFloat.pi / 2 + DOOR_ARC_ANGLE / 2
        let endAngle = -CGFloat.pi / 2 - DOOR_ARC_ANGLE / 2 + CGFloat.pi * 2
        let wallPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        // 1. 物理墙体 (保持静止，确保不漏球)
        let physicsNode = SKShapeNode(path: wallPath.cgPath)
        physicsNode.strokeColor = .clear
        physicsNode.lineWidth = 1
        physicsNode.position = CGPoint(x: 0, y: centerOffsetY)
        let wallBody = SKPhysicsBody(edgeChainFrom: wallPath.cgPath)
        wallBody.friction = 0.1
        wallBody.restitution = 0.1
        wallBody.categoryBitMask = GameEngineConfig.categoryWall
        physicsNode.physicsBody = wallBody
        addChild(physicsNode)
        
        // 2. 视觉容器 (用于摇晃)
        let visuals = SKNode()
        visuals.position = CGPoint(x: 0, y: centerOffsetY)
        addChild(visuals)
        self.containerVisuals = visuals
        
        // 后玻璃
        let backGlass = SKShapeNode(circleOfRadius: CONTAINER_RADIUS)
        backGlass.fillColor = SKColor(white: 0.0, alpha: 0.2)
        backGlass.strokeColor = SKColor(white: 1.0, alpha: 0.1)
        backGlass.lineWidth = 10
        backGlass.zPosition = -10
        visuals.addChild(backGlass)
        
        // 前玻璃
        let frontGlass = SKShapeNode(circleOfRadius: CONTAINER_RADIUS)
        frontGlass.fillColor = SKColor(white: 1.0, alpha: 0.05)
        frontGlass.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        frontGlass.lineWidth = 2
        frontGlass.zPosition = 100
        visuals.addChild(frontGlass)
        
        // 🔥 主高光
        let mainRadius = CONTAINER_RADIUS - 10
        let h1Start = CGFloat.pi * 0.60
        let h1End = CGFloat.pi * 0.85
        let mainPath = createCrescentPath(radius: mainRadius, startAngle: h1Start, endAngle: h1End, maxThickness: 10.0)
        let mainNode = SKShapeNode(path: mainPath)
        mainNode.fillColor = SKColor(white: 1.0, alpha: 0.6)
        mainNode.strokeColor = .clear
        mainNode.zPosition = 101
        visuals.addChild(mainNode)
        
        // 🔥 恢复：短弧线高光
        let subRadius = mainRadius - 30
        let subStart = h1Start + 0.1
        let subEnd = subStart + (h1End - h1Start) * 0.4
        let subPath = createCrescentPath(radius: subRadius, startAngle: subStart, endAngle: subEnd, maxThickness: 8.0)
        let subNode = SKShapeNode(path: subPath)
        subNode.fillColor = SKColor(white: 1.0, alpha: 0.3)
        subNode.strokeColor = .clear
        subNode.zPosition = 101
        visuals.addChild(subNode)
        
        // 边缘
        let rimPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS - 5, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
        let rimNode = SKShapeNode(path: rimPath.cgPath)
        rimNode.strokeColor = SKColor(white: 1.0, alpha: 0.2)
        rimNode.lineWidth = 4
        rimNode.lineCap = .round
        rimNode.zPosition = 101
        visuals.addChild(rimNode)

        createDoor()
        setupPhysicsFields()
    }
    
    func createCrescentPath(radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, maxThickness: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let steps = 30
        let angleSpan = endAngle - startAngle
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let currentAngle = startAngle + angleSpan * t
            let thicknessFactor = sin(t * CGFloat.pi)
            let r = radius + maxThickness * thicknessFactor / 2.0
            let x = r * cos(currentAngle)
            let y = r * sin(currentAngle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        for i in (0...steps).reversed() {
            let t = CGFloat(i) / CGFloat(steps)
            let currentAngle = startAngle + angleSpan * t
            let thicknessFactor = sin(t * CGFloat.pi)
            let r = radius - maxThickness * thicknessFactor / 2.0
            let x = r * cos(currentAngle)
            let y = r * sin(currentAngle)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.close()
        return path.cgPath
    }
    
    func setupPhysicsFields() {
        let turb = SKFieldNode.turbulenceField(withSmoothness: 0.3, animationSpeed: 0.5)
        turb.strength = 0
        turb.position = CGPoint(x: 0, y: centerOffsetY)
        addChild(turb)
        turbulenceField = turb
        
        let vor = SKFieldNode.vortexField()
        vor.strength = 0
        vor.position = CGPoint(x: 0, y: centerOffsetY)
        addChild(vor)
        vortexField = vor
        
        let stir = SKFieldNode.linearGravityField(withVector: vector_float3(1, 0, 0))
        stir.strength = 0
        stir.position = CGPoint(x: 0, y: centerOffsetY)
        stir.falloff = 0
        addChild(stir)
        stirringField = stir
    }
    
    // 🔥 门控修正：初始化即焊死
    func createDoor() {
        doorNode?.removeFromParent()
        let startAngle = -CGFloat.pi / 2 - DOOR_ARC_ANGLE / 2
        let endAngle = -CGFloat.pi / 2 + DOOR_ARC_ANGLE / 2
        let doorPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        let node = SKShapeNode(path: doorPath.cgPath)
        node.strokeColor = .white.withAlphaComponent(0.4)
        node.lineWidth = 4
        node.position = CGPoint(x: 0, y: centerOffsetY)
        
        // 直接赋予物理体，防止开局漏球
        let body = SKPhysicsBody(edgeChainFrom: doorPath.cgPath)
        body.categoryBitMask = GameEngineConfig.categoryWall
        body.friction = 0.0
        body.restitution = 0.0
        node.physicsBody = body
        
        addChild(node)
        doorNode = node
        isDoorOpen = false
    }
    
    @objc func startRedPhase(_ notification: Notification) {
        guard let type = notification.object as? LotteryType, type == self.lotteryType else { return }
        AudioManager.shared.playLoop("mixer_loop")
        
        forceReset()
        isBluePhase = false
        targetCount = lotteryType.redConfig.count
        fillBalls(isRed: true)
        startMixingPhase()
    }
    
    @objc func startBluePhase(_ notification: Notification) {
        guard let type = notification.object as? LotteryType, type == self.lotteryType else { return }
        AudioManager.shared.playLoop("mixer_loop")
        
        forceReset()
        isBluePhase = true
        targetCount = lotteryType.blueConfig.count
        fillBalls(isRed: false)
        startMixingPhase()
    }
    
    @objc func resetScene() {
        AudioManager.shared.stopLoop("mixer_loop")
        forceReset()
        fillBalls(isRed: true)
    }
    
    private func forceReset() {
        self.removeAllActions()
        self.children.forEach { if $0.name == "ball" { $0.removeAllActions() } }
        containerVisuals?.removeAllActions()
        containerVisuals?.zRotation = 0 // 视觉回正
        
        extractedCount = 0
        isExtracting = false
        lastProcessTime = 0
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        closeDoor()
        
        turbulenceField?.strength = 0
        vortexField?.strength = 0
        stirringField?.strength = 0
        stirringField?.removeAllActions()
    }
    
    func fillBalls(isRed: Bool) {
        removeBalls()
        let config = isRed ? lotteryType.redConfig : lotteryType.blueConfig
        let ballColor: SKColor = isRed ? SKColor(Color.lotteryRed) : SKColor(Color.lotteryBlue)
        let rangeArray = Array(config.range)
        for i in rangeArray { createOneBall(number: i, color: ballColor) }
    }
    
    func createOneBall(number: Int, color: SKColor) {
        let r = GameEngineConfig.ballRadius * 0.9
        let ball = SKShapeNode(circleOfRadius: r)
        ball.name = "ball"
        let safe = CONTAINER_RADIUS * 0.5
        ball.position = CGPoint(x: CGFloat.random(in: -safe...safe), y: CGFloat.random(in: -safe...safe) + centerOffsetY)
        ball.fillColor = color
        ball.strokeColor = .clear
        
        let label = SKLabelNode(text: "\(number)")
        label.fontSize = 14
        label.fontName = "Arial-BoldMT"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.fontColor = .white
        ball.addChild(label)
        
        let body = SKPhysicsBody(circleOfRadius: r)
        body.mass = 0.04
        body.restitution = 0.6
        body.friction = 0.2
        body.linearDamping = 0.2
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = GameEngineConfig.categoryBall
        body.collisionBitMask = GameEngineConfig.categoryWall | GameEngineConfig.categoryBall
        ball.physicsBody = body
        addChild(ball)
    }
    
    func removeBalls() { self.children.filter { $0.name == "ball" }.forEach { $0.removeFromParent() } }
    
    // MARK: - 3. 搅拌逻辑 (定制参数版)
    private func startMixingPhase() {
        // 🔥 要求2：力量 0.2，不要 turbulence
        vortexField?.strength = 0.01
        turbulenceField?.strength = 2
        stirringField?.strength = 0.1 // 也不用 stirring，全靠 impulse
        
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        
        // 🔥 要求4：容器 15度 (0.26弧度) 摇晃
        let rockLeft = SKAction.rotate(toAngle: 0.26, duration: 0.8)
        let rockRight = SKAction.rotate(toAngle: -0.26, duration: 0.8)
        containerVisuals?.run(SKAction.repeatForever(SKAction.sequence([rockLeft, rockRight])))
        
        // 🔥 您指定的暴力搅拌循环
        let mixAction = SKAction.run { [weak self] in
            self?.enumerateChildNodes(withName: "ball") { node, _ in
                let randomDx = CGFloat.random(in: -15...15)
                let randomDy = CGFloat.random(in: -15...15)
                node.physicsBody?.applyImpulse(CGVector(dx: randomDx, dy: randomDy))
            }
        }
        let mixWait = SKAction.wait(forDuration: 0.15)
        let mixSequence = SKAction.sequence([mixAction, mixWait])
        
        // 搅拌 2 秒后停止
        let mixingDuration = SKAction.repeat(mixSequence, count: 40)
        
        let stopMixing = SKAction.run { [weak self] in
            self?.stopStirringAndStartExtracting()
        }
        
        run(SKAction.sequence([mixingDuration, stopMixing]))
    }
    
    private func stopStirringAndStartExtracting() {
        // 视觉容器回正
        containerVisuals?.removeAllActions()
        containerVisuals?.run(SKAction.rotate(toAngle: 0, duration: 0.5))
        
        turbulenceField?.strength = 0
        vortexField?.strength = 0
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -15.0)
        
        enumerateChildNodes(withName: "ball") { node, _ in
            node.physicsBody?.angularVelocity *= 0.2
            node.physicsBody?.velocity = CGVector(dx: 0, dy: -100)
        }
        
        let waitSettle = SKAction.wait(forDuration: 1.0)
        let startExtract = SKAction.run { [weak self] in
            self?.isExtracting = true
            self?.openDoorStep()
        }
        run(SKAction.sequence([waitSettle, startExtract]))
    }
    
    // MARK: - 4. 脉冲出球逻辑
    private func openDoorStep() {
        if extractedCount >= targetCount { return }
        
        openDoor()
        
        enumerateChildNodes(withName: "ball") { node, _ in
            if node.position.y < self.centerOffsetY - self.CONTAINER_RADIUS + 60 {
                node.physicsBody?.applyImpulse(CGVector(dx: CGFloat.random(in: -8...8), dy: CGFloat.random(in: 10...30)))
            }
        }
        
        let timeout = SKAction.wait(forDuration: 3.0)
        let retry = SKAction.run { [weak self] in
            if self?.isDoorOpen == true { self?.openDoorStep() }
        }
        removeAction(forKey: "RetryKick")
        run(SKAction.sequence([timeout, retry]), withKey: "RetryKick")
    }
    
    private func scheduleNextBall() {
        removeAction(forKey: "RetryKick")
        closeDoor()
        
        if extractedCount < targetCount {
            let wait = SKAction.wait(forDuration: 1.2)
            let nextStep = SKAction.run { [weak self] in self?.openDoorStep() }
            run(SKAction.sequence([wait, nextStep]))
        } else {
            finishCurrentPhase()
        }
    }
    
    private func openDoor() {
        if isDoorOpen { return }
        doorNode?.physicsBody = nil
        doorNode?.strokeColor = .white.withAlphaComponent(0.1)
        isDoorOpen = true
    }
    
    private func closeDoor() {
        guard let door = doorNode else { return }
        
        if door.physicsBody == nil {
            let startAngle = -CGFloat.pi / 2 - DOOR_ARC_ANGLE / 2
            let endAngle = -CGFloat.pi / 2 + DOOR_ARC_ANGLE / 2
            let doorPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            
            let body = SKPhysicsBody(edgeChainFrom: doorPath.cgPath)
            body.categoryBitMask = GameEngineConfig.categoryWall
            body.friction = 0.0
            body.restitution = 0.0
            door.physicsBody = body
        }
        door.strokeColor = .white.withAlphaComponent(0.4)
        isDoorOpen = false
    }
    
    // MARK: - 实时检测 (去除了 3D 缩放逻辑)
    override func update(_ currentTime: TimeInterval) {
        if !isExtracting || !isDoorOpen { return }
        if currentTime - lastProcessTime < 0.5 { return }
        
        let maxDist = CONTAINER_RADIUS - (GameEngineConfig.ballRadius * 0.9)
        
        for node in children {
            guard node.name == "ball", let body = node.physicsBody else { continue }
            if node.userData?["isProcessed"] as? Bool == true { continue }
            
            if body.velocity.dy < -600 { body.velocity.dy = -600 }
            
            let dx = node.position.x
            let dy = node.position.y - centerOffsetY
            let dist = sqrt(dx*dx + dy*dy)
            
            if dist > CONTAINER_RADIUS {
                let angle = atan2(dy, dx)
                let angleDiff = abs(angle - (-CGFloat.pi / 2))
                let isAtDoor = angleDiff < (DOOR_ARC_ANGLE / 0.8)
                
                if isAtDoor {
                    handleBallEscape(node, currentTime: currentTime)
                    break
                } else {
                    if dist > maxDist + 10 {
                        node.position = CGPoint(x: 0, y: centerOffsetY)
                        body.velocity = .zero
                    }
                }
            }
        }
    }
    
    private func handleBallEscape(_ ballNode: SKNode, currentTime: TimeInterval) {
        lastProcessTime = currentTime
        extractedCount += 1
        
        ballNode.userData = ["isProcessed": true]
        ballNode.physicsBody = nil
        
        scheduleNextBall()
        
        let capturedColor = self.isBluePhase ? "blue" : "red"
        AudioManager.shared.play("ball_drop")
        
        if extractedCount >= targetCount { AudioManager.shared.stopLoop("mixer_loop") }
        
        let dropTarget = CGPoint(x: 0, y: -self.size.height/2 + 60)
        
        ballNode.run(SKAction.sequence([
            SKAction.move(to: dropTarget, duration: 0.3),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                if let label = ballNode.children.first(where: { $0 is SKLabelNode }) as? SKLabelNode,
                   let text = label.text, let number = Int(text) {
                    self.onBallSelected?(number, capturedColor)
                }
            }
        ]))
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    private func finishCurrentPhase() {
        if !isBluePhase {
            isExtracting = false
            let wait = SKAction.wait(forDuration: 0.5)
            let prepare = SKAction.run { [weak self] in
                self?.removeBalls()
                self?.fillBalls(isRed: false)
                NotificationCenter.default.post(name: .redPhaseFinished, object: nil)
            }
            run(SKAction.sequence([wait, prepare]))
        } else {
            isExtracting = false
            let wait = SKAction.wait(forDuration: 0.5)
            let finish = SKAction.run {
                AudioManager.shared.play("win")
                NotificationCenter.default.post(name: .allFinished, object: nil)
            }
            run(SKAction.sequence([wait, finish]))
        }
    }
}

