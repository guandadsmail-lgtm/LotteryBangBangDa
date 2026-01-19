import SwiftUI
import SpriteKit
import Foundation

enum LotteryPhase {
    case red, blue, idle
}

class LottoScene: SKScene {
    // MARK: - 1. 物理配置参数
    private let TURBULENCE_DURATION: TimeInterval = 5.5
    private let MAX_SPEED: CGFloat = 450.0
    private let CONTAINER_RADIUS: CGFloat = 190.0
    private let DOOR_ARC_ANGLE: CGFloat = 0.35
    private let centerOffsetY: CGFloat = 40.0
    
    var lotteryType: LotteryType
    private var hasContentCreated = false
    private var turbulenceField: SKFieldNode?
    private var vortexField: SKFieldNode?
    private var doorNode: SKShapeNode?
    
    private var isExtracting = false
    private var extractedCount = 0
    private var targetCount = 0
    private var isBluePhase = false
    
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
    
    // MARK: - 2. 3D 玻璃容器构建
    func createStaticContainer() {
        // --- A. 物理层 (看不见) ---
        let startAngle = -CGFloat.pi / 2 + DOOR_ARC_ANGLE / 2
        let endAngle = -CGFloat.pi / 2 - DOOR_ARC_ANGLE / 2 + CGFloat.pi * 2
        let wallPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        
        let physicsNode = SKShapeNode(path: wallPath.cgPath)
        physicsNode.strokeColor = .clear
        physicsNode.lineWidth = 1
        physicsNode.position = CGPoint(x: 0, y: centerOffsetY)
        
        let wallBody = SKPhysicsBody(edgeChainFrom: wallPath.cgPath)
        wallBody.friction = 0.1
        wallBody.restitution = 0.2
        wallBody.categoryBitMask = GameEngineConfig.categoryWall
        physicsNode.physicsBody = wallBody
        addChild(physicsNode)
        
        // --- B. 视觉后壁 (Back Layer) ---
        let backGlass = SKShapeNode(circleOfRadius: CONTAINER_RADIUS)
        backGlass.position = CGPoint(x: 0, y: centerOffsetY)
        backGlass.fillColor = SKColor(white: 0.0, alpha: 0.2)
        backGlass.strokeColor = SKColor(white: 1.0, alpha: 0.1)
        backGlass.lineWidth = 10
        backGlass.zPosition = -10
        addChild(backGlass)
        
        // --- C. 视觉前壁 (Front Layer) ---
        // 1. 玻璃整体罩
        let frontGlass = SKShapeNode(circleOfRadius: CONTAINER_RADIUS)
        frontGlass.position = CGPoint(x: 0, y: centerOffsetY)
        frontGlass.fillColor = SKColor(white: 1.0, alpha: 0.05)
        frontGlass.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        frontGlass.lineWidth = 2
        frontGlass.zPosition = 100
        addChild(frontGlass)
        
        // 🔥 2. 主高光 (两头尖中间粗)
        let mainRadius = CONTAINER_RADIUS - 10
        let h1Start = CGFloat.pi * 0.60
        let h1End = CGFloat.pi * 0.85
        let mainSpan = h1End - h1Start
        
        let mainPath = createCrescentPath(
            radius: mainRadius,
            startAngle: h1Start,
            endAngle: h1End,
            maxThickness: 10.0
        )
        
        let mainNode = SKShapeNode(path: mainPath)
        mainNode.position = CGPoint(x: 0, y: centerOffsetY)
        mainNode.fillColor = SKColor(white: 1.0, alpha: 0.6)
        mainNode.strokeColor = .clear
        mainNode.zPosition = 101
        addChild(mainNode)
        
        // 🔥 3. 副高光 (偏移40，长度1/3，两头尖)
        let subRadius = mainRadius - 40 // 向内缩40
        let subSpan = mainSpan / 3.0    // 长度1/3
        
        let centerAngle = h1Start + mainSpan / 2.0
        let subStart = centerAngle - subSpan / 2.0
        let subEnd = centerAngle + subSpan / 2.0
        
        let subPath = createCrescentPath(
            radius: subRadius,
            startAngle: subStart,
            endAngle: subEnd,
            maxThickness: 8.0
        )
        
        let subNode = SKShapeNode(path: subPath)
        subNode.position = CGPoint(x: 0, y: centerOffsetY)
        subNode.fillColor = SKColor(white: 1.0, alpha: 0.4)
        subNode.strokeColor = .clear
        subNode.zPosition = 101
        addChild(subNode)
        
        // 4. 底部边缘光
        let rimPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS - 5, startAngle: -CGFloat.pi * 0.8, endAngle: -CGFloat.pi * 0.2, clockwise: true)
        let rimNode = SKShapeNode(path: rimPath.cgPath)
        rimNode.position = CGPoint(x: 0, y: centerOffsetY)
        rimNode.strokeColor = SKColor(white: 1.0, alpha: 0.2)
        rimNode.lineWidth = 4
        rimNode.lineCap = .round
        rimNode.zPosition = 101
        addChild(rimNode)

        // --- D. 门和力场 ---
        createDoor()
        setupPhysicsFields()
    }
    
    // ✨ 核心算法：生成两头尖、中间粗的月牙路径
    func createCrescentPath(radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, maxThickness: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let steps = 30
        let angleSpan = endAngle - startAngle
        
        // 外弧线
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let currentAngle = startAngle + angleSpan * t
            let thicknessFactor = sin(t * CGFloat.pi)
            let currentThickness = maxThickness * thicknessFactor
            
            let r = radius + currentThickness / 2.0
            let x = r * cos(currentAngle)
            let y = r * sin(currentAngle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // 内弧线
        for i in (0...steps).reversed() {
            let t = CGFloat(i) / CGFloat(steps)
            let currentAngle = startAngle + angleSpan * t
            let thicknessFactor = sin(t * CGFloat.pi)
            let currentThickness = maxThickness * thicknessFactor
            
            let r = radius - currentThickness / 2.0
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
    }
    
    func createDoor() {
        doorNode?.removeFromParent()
        let doorStart = -CGFloat.pi / 2 - DOOR_ARC_ANGLE / 2
        let doorEnd = -CGFloat.pi / 2 + DOOR_ARC_ANGLE / 2
        let doorPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS, startAngle: doorStart, endAngle: doorEnd, clockwise: true)
        let node = SKShapeNode(path: doorPath.cgPath)
        node.strokeColor = .white.withAlphaComponent(0.4)
        node.lineWidth = 4
        node.position = CGPoint(x: 0, y: centerOffsetY)
        addChild(node)
        doorNode = node
        closeDoor()
    }
    
    @objc func startRedPhase(_ notification: Notification) {
        guard let type = notification.object as? LotteryType, type == self.lotteryType else { return }
        AudioManager.shared.playLoop("mixer_loop")
        
        forceReset()
        isBluePhase = false
        targetCount = lotteryType.redConfig.count
        fillBalls(isRed: true)
        startPhysicsSequence()
    }
    
    @objc func startBluePhase(_ notification: Notification) {
        guard let type = notification.object as? LotteryType, type == self.lotteryType else { return }
        AudioManager.shared.playLoop("mixer_loop")
        
        self.removeAllActions()
        isBluePhase = true
        extractedCount = 0
        isExtracting = false
        targetCount = lotteryType.blueConfig.count
        closeDoor()
        startPhysicsSequence()
    }
    
    @objc func resetScene() {
        AudioManager.shared.stopLoop("mixer_loop")
        forceReset()
        fillBalls(isRed: true)
    }
    
    private func forceReset() {
        self.removeAllActions()
        self.children.forEach { if $0.name == "ball" { $0.removeAllActions() } }
        extractedCount = 0
        isExtracting = false
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        closeDoor()
        turbulenceField?.strength = 0
        vortexField?.strength = 0
    }
    
    func fillBalls(isRed: Bool) {
        removeBalls()
        let config = isRed ? lotteryType.redConfig : lotteryType.blueConfig
        let ballColor: SKColor = isRed ? SKColor(Color.lotteryRed) : SKColor(Color.lotteryBlue)
        let rangeArray = Array(config.range)
        for i in rangeArray { createOneBall(number: i, color: ballColor) }
    }
    
    func createOneBall(number: Int, color: SKColor) {
        let r = GameEngineConfig.ballRadius
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
        body.linearDamping = 0.1
        body.categoryBitMask = GameEngineConfig.categoryBall
        body.collisionBitMask = GameEngineConfig.categoryWall | GameEngineConfig.categoryBall
        ball.physicsBody = body
        addChild(ball)
    }
    
    func removeBalls() { self.children.filter { $0.name == "ball" }.forEach { $0.removeFromParent() } }
    
    private func startPhysicsSequence() {
        vortexField?.strength = 0.5
        turbulenceField?.strength = 25.0
        
        turbulenceField?.animationSpeed = 4.0
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        enumerateChildNodes(withName: "ball") { node, _ in
            node.physicsBody?.applyImpulse(CGVector(dx: CGFloat.random(in: -10...10), dy: CGFloat.random(in: -10...10)))
        }
        
        let waitTurbulence = SKAction.wait(forDuration: TURBULENCE_DURATION)
        let calmDown = SKAction.run { [weak self] in self?.stopStirring() }
        let waitSettle = SKAction.wait(forDuration: 1.0)
        let startExtract = SKAction.run { [weak self] in self?.startExtractingLoop() }
        run(SKAction.sequence([waitTurbulence, calmDown, waitSettle, startExtract]))
    }
    
    private func stopStirring() {
        turbulenceField?.strength = 0
        vortexField?.strength = 0
        physicsWorld.gravity = CGVector(dx: 0, dy: -15.0)
        enumerateChildNodes(withName: "ball") { node, _ in
            node.physicsBody?.angularVelocity *= 0.2
            node.physicsBody?.velocity = CGVector(dx: 0, dy: -100)
        }
    }
    
    private func startExtractingLoop() {
        isExtracting = true
        let releaseAction = SKAction.run { [weak self] in
            guard let self = self else { return }
            if self.extractedCount < self.targetCount {
                self.openDoor()
                self.shakeContainer()
            }
        }
        let interval = SKAction.wait(forDuration: 1.2)
        let seq = SKAction.sequence([releaseAction, interval])
        let loop = SKAction.repeat(seq, count: targetCount + 5)
        let finish = SKAction.run { [weak self] in
            self?.isExtracting = false
            self?.closeDoor()
        }
        run(SKAction.sequence([loop, finish]))
    }
    
    func shakeContainer() {
        enumerateChildNodes(withName: "ball") { node, _ in
            if node.position.y < self.centerOffsetY - self.CONTAINER_RADIUS + 50 {
                node.physicsBody?.applyImpulse(CGVector(dx: CGFloat.random(in: -3...3), dy: 15))
            }
        }
    }
    
    private func openDoor() {
        doorNode?.physicsBody = nil
        doorNode?.strokeColor = .white.withAlphaComponent(0.1)
    }
    
    private func closeDoor() {
        guard let door = doorNode else { return }
        if door.physicsBody != nil { return }
        let startAngle = -CGFloat.pi / 2 - DOOR_ARC_ANGLE / 2
        let endAngle = -CGFloat.pi / 2 + DOOR_ARC_ANGLE / 2
        let doorPath = UIBezierPath(arcCenter: .zero, radius: CONTAINER_RADIUS, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        let body = SKPhysicsBody(edgeChainFrom: doorPath.cgPath)
        body.categoryBitMask = GameEngineConfig.categoryWall
        body.friction = 0.0
        body.restitution = 0.0
        door.physicsBody = body
        door.strokeColor = .white.withAlphaComponent(0.4)
    }
    
    override func update(_ currentTime: TimeInterval) {
        let ballRadius = GameEngineConfig.ballRadius
        let maxDist = CONTAINER_RADIUS - ballRadius
        for node in children {
            guard node.name == "ball", let body = node.physicsBody else { continue }
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
            let dist = sqrt(dx*dx + dy*dy)
            if dist > maxDist {
                let angle = atan2(dy, dx)
                let angleDiff = abs(angle - (-CGFloat.pi / 2))
                let isAtDoor = angleDiff < (DOOR_ARC_ANGLE / 1.1)
                let isDoorOpen = (doorNode?.physicsBody == nil)
                if isAtDoor && isDoorOpen && isExtracting {
                    body.applyForce(CGVector(dx: 0, dy: -20.0))
                    if dist > CONTAINER_RADIUS + 30 { handleBallEscape(node) }
                } else {
                    if dist > maxDist + 5 {
                        node.position.x = cos(angle) * (maxDist - 2)
                        node.position.y = sin(angle) * (maxDist - 2) + centerOffsetY
                        body.velocity = CGVector(dx: -body.velocity.dx * 0.5, dy: -body.velocity.dy * 0.5)
                    }
                }
            }
        }
        if extractedCount >= targetCount && targetCount > 0 { closeDoor() }
    }
    
    private func handleBallEscape(_ ballNode: SKNode) {
        guard ballNode.userData?["isProcessed"] == nil else { return }
        ballNode.userData = ["isProcessed": true]
        ballNode.physicsBody = nil
        extractedCount += 1
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
                    let colorName = self.isBluePhase ? "blue" : "red"
                    self.onBallSelected?(number, colorName)
                }
                if self.extractedCount >= self.targetCount { self.finishCurrentPhase() }
            }
        ]))
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        closeDoor()
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
