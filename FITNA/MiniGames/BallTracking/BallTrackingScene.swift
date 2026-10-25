import SpriteKit
import UIKit

/// SpriteKit scene for تتبّع الكرة. Balls sit in slots on a circle; swaps move
/// two balls along mirrored arcs so paths never cross through each other.
/// The scene only animates — which slot is correct is decided by FitnaKit.
final class BallTrackingScene: SKScene {
    var onTapSlot: ((Int) -> Void)?

    private var ballAtSlot: [SKShapeNode] = []
    private var ballCount = 0
    private var ballRadius: CGFloat = 28
    private let ballColor = UIColor(red: 0x35 / 255, green: 0xC9 / 255, blue: 0xB8 / 255, alpha: 1)
    private let targetColor = UIColor(red: 0xFF / 255, green: 0xB5 / 255, blue: 0x47 / 255, alpha: 1)
    private var isAnimating = false

    override init(size: CGSize) {
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Layout

    private func position(of slot: Int) -> CGPoint {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if ballCount <= 1 { return center }
        let radius = min(size.width, size.height) * 0.36
        // Start at the top and go clockwise.
        let angle = CGFloat.pi / 2 - CGFloat(slot) * 2 * .pi / CGFloat(ballCount)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard !isAnimating else { return }
        ballRadius = max(20, min(size.width, size.height) * (ballCount > 5 ? 0.075 : 0.09))
        for (slot, node) in ballAtSlot.enumerated() {
            node.position = position(of: slot)
            node.path = CGPath(ellipseIn: CGRect(x: -ballRadius, y: -ballRadius, width: ballRadius * 2, height: ballRadius * 2), transform: nil)
        }
    }

    // MARK: Round lifecycle

    func setUp(ballCount: Int) {
        removeAllActions()
        removeAllChildren()
        self.ballCount = ballCount
        isAnimating = false
        ballRadius = max(20, min(size.width, size.height) * (ballCount > 5 ? 0.075 : 0.09))
        ballAtSlot = (0..<ballCount).map { slot in
            let node = SKShapeNode(circleOfRadius: ballRadius)
            node.fillColor = ballColor
            node.strokeColor = UIColor.white.withAlphaComponent(0.9)
            node.lineWidth = 3
            node.position = position(of: slot)
            node.zPosition = 1
            // Soft highlight for depth.
            let shine = SKShapeNode(circleOfRadius: ballRadius * 0.28)
            shine.fillColor = UIColor.white.withAlphaComponent(0.45)
            shine.strokeColor = .clear
            shine.position = CGPoint(x: -ballRadius * 0.3, y: ballRadius * 0.3)
            shine.name = "shine"
            node.addChild(shine)
            addChild(node)
            return node
        }
    }

    /// Marks the target with color, a ring and a pulse (not color alone).
    func showTarget(slot: Int) {
        guard ballAtSlot.indices.contains(slot) else { return }
        let node = ballAtSlot[slot]
        node.fillColor = targetColor
        let ring = SKShapeNode(circleOfRadius: ballRadius + 8)
        ring.strokeColor = targetColor
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.name = "ring"
        node.addChild(ring)
        let pulse = SKAction.sequence([.scale(to: 1.15, duration: 0.25), .scale(to: 1.0, duration: 0.25)])
        node.run(.repeat(pulse, count: 2))
    }

    func hideTarget() {
        for node in ballAtSlot {
            node.fillColor = ballColor
            node.childNode(withName: "ring")?.removeFromParent()
        }
    }

    /// Runs swaps back to back, each taking `duration` seconds.
    func runSwaps(_ swaps: [(Int, Int)], duration: TimeInterval) {
        isAnimating = true
        var actions: [SKAction] = []
        for (a, b) in swaps {
            actions.append(.run { [weak self] in self?.performSwap(a, b, duration: duration * 0.92) })
            actions.append(.wait(forDuration: duration))
        }
        actions.append(.run { [weak self] in self?.isAnimating = false })
        run(.sequence(actions), withKey: "swaps")
    }

    private func performSwap(_ a: Int, _ b: Int, duration: TimeInterval) {
        guard ballAtSlot.indices.contains(a), ballAtSlot.indices.contains(b) else { return }
        let nodeA = ballAtSlot[a], nodeB = ballAtSlot[b]
        let pa = position(of: a), pb = position(of: b)
        nodeA.run(arc(from: pa, to: pb, bulge: 1, duration: duration))
        nodeB.run(arc(from: pb, to: pa, bulge: 1, duration: duration))
        ballAtSlot.swapAt(a, b)
    }

    private func arc(from p1: CGPoint, to p2: CGPoint, bulge: CGFloat, duration: TimeInterval) -> SKAction {
        let mid = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
        let dx = p2.x - p1.x, dy = p2.y - p1.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        // Perpendicular offset; since the two balls travel in opposite directions,
        // the same sign sends them along opposite sides.
        let offset = min(70, length * 0.35) * bulge
        let control = CGPoint(x: mid.x - dy / length * offset, y: mid.y + dx / length * offset)
        let path = UIBezierPath()
        path.move(to: p1)
        path.addQuadCurve(to: p2, controlPoint: control)
        let follow = SKAction.follow(path.cgPath, asOffset: false, orientToPath: false, duration: duration)
        follow.timingMode = .easeInEaseOut
        return follow
    }

    /// Feedback after the player picks: correct slot gets a check ring, wrong pick a red ring.
    func reveal(correctSlot: Int, tappedSlot: Int?) {
        if ballAtSlot.indices.contains(correctSlot) {
            let node = ballAtSlot[correctSlot]
            node.fillColor = targetColor
            let ring = SKShapeNode(circleOfRadius: ballRadius + 8)
            ring.strokeColor = UIColor(red: 0x32 / 255, green: 0xC4 / 255, blue: 0x8D / 255, alpha: 1)
            ring.lineWidth = 5
            ring.name = "ring"
            node.addChild(ring)
            node.run(.sequence([.scale(to: 1.2, duration: 0.15), .scale(to: 1, duration: 0.15)]))
        }
        if let t = tappedSlot, t != correctSlot, ballAtSlot.indices.contains(t) {
            let node = ballAtSlot[t]
            let ring = SKShapeNode(circleOfRadius: ballRadius + 8)
            ring.strokeColor = UIColor(red: 0xFF / 255, green: 0x6B / 255, blue: 0x75 / 255, alpha: 1)
            ring.lineWidth = 5
            ring.name = "ring"
            node.addChild(ring)
            let shake = SKAction.sequence([.moveBy(x: -8, y: 0, duration: 0.05), .moveBy(x: 16, y: 0, duration: 0.1), .moveBy(x: -8, y: 0, duration: 0.05)])
            node.run(shake)
        }
    }

    // MARK: Input

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, !isAnimating else { return }
        let p = touch.location(in: self)
        var best: (slot: Int, dist: CGFloat)?
        for slot in 0..<ballCount {
            let c = position(of: slot)
            let d = hypot(c.x - p.x, c.y - p.y)
            if d < ballRadius * 1.8, best == nil || d < best!.dist { best = (slot, d) }
        }
        if let b = best { onTapSlot?(b.slot) }
    }

    /// Screen-space center of a slot, for accessibility elements.
    func slotCenterInView(_ slot: Int) -> CGPoint {
        let p = position(of: slot)
        return CGPoint(x: p.x, y: size.height - p.y)
    }
}
