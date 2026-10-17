import AVFoundation
import os
import QuartzCore

/// Mixes short sound effects inside an audio render callback.
///
/// Using one source node (instead of AVAudioPlayerNodes) means there is nothing to
/// start or stop per sound, so playback can never raise an Objective-C exception.
final class EffectMixer: @unchecked Sendable {
    private struct Voice {
        let samples: [Float]
        var position: Int
        let gain: Float
    }

    private static let maxVoices = 16
    private let voices = OSAllocatedUnfairLock(initialState: [Voice]())

    func play(_ samples: [Float], gain: Float) {
        voices.withLockUnchecked { voices in
            if voices.count >= Self.maxVoices { voices.removeFirst() }
            voices.append(Voice(samples: samples, position: 0, gain: gain))
        }
    }

    /// Called on the audio thread.
    func render(into out: UnsafeMutablePointer<Float>, frames: Int) {
        out.update(repeating: 0, count: frames)
        voices.withLockUnchecked { voices in
            for index in voices.indices {
                let voice = voices[index]
                let count = min(frames, voice.samples.count - voice.position)
                guard count > 0 else { continue }
                voice.samples.withUnsafeBufferPointer { source in
                    for frame in 0..<count {
                        out[frame] += source[voice.position + frame] * voice.gain
                    }
                }
                voices[index].position += count
            }
            voices.removeAll { $0.position >= $0.samples.count }
        }
        for frame in 0..<frames {
            out[frame] = max(-1, min(1, out[frame]))
        }
    }
}

/// Plays the synthesized sound effects. Sounds are rendered on a background
/// thread at launch; anything requested before then is simply skipped.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let mixer = EffectMixer()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
    private var samples: [SoundEffect: [Float]] = [:]
    private var lastPlayed: [SoundEffect: CFTimeInterval] = [:]
    private var isPrepared = false
    private var observers: [NSObjectProtocol] = []

    private init() {}

    /// Sets up the audio graph and renders all sounds in the background. Safe to call repeatedly.
    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let mixer = self.mixer
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            if let data = buffers.first?.mData {
                mixer.render(into: data.assumingMemoryBound(to: Float.self), frames: Int(frameCount))
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
        startEngine()

        Task.detached(priority: .utility) {
            let rendered = Dictionary(uniqueKeysWithValues: SoundEffect.allCases.map { ($0, $0.samples) })
            await MainActor.run { SoundEngine.shared.samples = rendered }
        }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in SoundEngine.shared.startEngine() }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { _ in
            Task { @MainActor in SoundEngine.shared.startEngine() }
        })
    }

    func play(_ effect: SoundEffect) {
        guard PlayerProgress.soundEnabled else { return }
        if !isPrepared { prepare() }
        guard let buffer = samples[effect] else { return }
        let now = CACurrentMediaTime()
        if let last = lastPlayed[effect], now - last < effect.minimumInterval { return }
        lastPlayed[effect] = now
        if !engine.isRunning { startEngine() }
        mixer.play(buffer, gain: effect.volume)
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            // Audio is optional; the game keeps running silently.
        }
    }
}
