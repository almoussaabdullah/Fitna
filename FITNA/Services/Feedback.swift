import AVFoundation
import SwiftUI
import UIKit

/// User preferences stored in UserDefaults (shared keys with @AppStorage).
enum SettingsKey {
    static let sound = "settings.sound"
    static let haptics = "settings.haptics"
    static let onboardingDone = "settings.onboardingDone"
    static let showTutorials = "settings.showTutorials"
}

/// Sound effects are synthesized at runtime (short sine/triangle tones with
/// envelopes) — fully original audio, no bundled files.
final class SoundEngine {
    static let shared = SoundEngine()

    enum Effect: CaseIterable {
        case tap, correct, wrong, tick, start, success, levelUp, flip
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var started = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.55
        for effect in Effect.allCases { buffers[effect] = makeBuffer(for: effect) }
    }

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.sound) as? Bool ?? true
    }

    func play(_ effect: Effect) {
        guard enabled, let buffer = buffers[effect] else { return }
        if !started {
            do {
                // Ambient: respects the silent switch and mixes with the user's music.
                try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
                started = true
            } catch {
                return
            }
        }
        if !engine.isRunning { try? engine.start() }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    /// (frequency Hz, duration s) notes per effect.
    private func notes(for effect: Effect) -> [(Double, Double)] {
        switch effect {
        case .tap: return [(880, 0.035)]
        case .flip: return [(620, 0.04), (780, 0.04)]
        case .tick: return [(1200, 0.03)]
        case .correct: return [(660, 0.07), (990, 0.11)]
        case .wrong: return [(240, 0.09), (190, 0.14)]
        case .start: return [(523, 0.08), (659, 0.08), (784, 0.14)]
        case .success: return [(523, 0.09), (659, 0.09), (784, 0.09), (1047, 0.22)]
        case .levelUp: return [(587, 0.08), (740, 0.08), (880, 0.08), (1175, 0.3)]
        }
    }

    private func makeBuffer(for effect: Effect) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let sequence = notes(for: effect)
        let total = sequence.reduce(0) { $0 + $1.1 }
        let frameCount = AVAudioFrameCount(total * sr)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        var index = 0
        for (freq, dur) in sequence {
            let n = Int(dur * sr)
            for i in 0..<n where index < Int(frameCount) {
                let t = Double(i) / sr
                // Soft attack, exponential release.
                let attack = min(1, t / 0.006)
                let release = exp(-4.0 * t / dur)
                let sine = sin(2 * .pi * freq * t)
                let overtone = 0.25 * sin(4 * .pi * freq * t)
                data[index] = Float((sine + overtone) * attack * release * 0.32)
                index += 1
            }
        }
        return buffer
    }
}

/// Haptic feedback that honors the user's setting.
enum Haptics {
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true
    }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func correct() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func wrong() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func celebrate() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

/// Combined feedback used by every game.
enum Feedback {
    static func tap() { SoundEngine.shared.play(.tap); Haptics.tap() }
    static func flip() { SoundEngine.shared.play(.flip); Haptics.tap() }
    static func correct() { SoundEngine.shared.play(.correct); Haptics.correct() }
    static func wrong() { SoundEngine.shared.play(.wrong); Haptics.wrong() }
    static func tick() { SoundEngine.shared.play(.tick) }
    static func start() { SoundEngine.shared.play(.start); Haptics.tap() }
    static func success() { SoundEngine.shared.play(.success); Haptics.celebrate() }
    static func levelUp() { SoundEngine.shared.play(.levelUp); Haptics.celebrate() }
}
