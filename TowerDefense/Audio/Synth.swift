import Foundation

/// A tiny offline synthesizer that renders retro (chiptune-style) sound effects into
/// sample arrays, so the game ships without any audio files.
enum Synth {
    static let sampleRate = 44_100.0

    enum Wave { case square, pulse25, triangle, saw, noise, sine }

    /// One note or sweep. Frequencies slide linearly from `from` to `to`.
    struct Voice {
        var wave: Wave
        var from: Double
        var to: Double
        var duration: Double
        var start: Double = 0
        var gain: Double = 1
        var attack: Double = 0.003
        /// Higher values make the volume fall off faster.
        var decay: Double = 1.5
        /// Square-wave arpeggio/vibrato step in semitones, applied every 1/60 s (NES style).
        var vibrato: Double = 0
    }

    static func render(_ voices: [Voice], volume: Double = 0.8, crush: Int = 1) -> [Float] {
        let length = voices.map { $0.start + $0.duration }.max() ?? 0
        let count = Int(length * sampleRate) + 1
        var out = [Double](repeating: 0, count: count)
        var noiseState: UInt32 = 0xACE1
        var noiseValue = 1.0
        for voice in voices {
            let startIndex = Int(voice.start * sampleRate)
            let samples = Int(voice.duration * sampleRate)
            var phase = 0.0
            var noiseClock = 0.0
            for i in 0..<samples {
                let t = Double(i) / sampleRate
                let progress = t / voice.duration
                var frequency = voice.from + (voice.to - voice.from) * progress
                if voice.vibrato != 0 {
                    let tick = Int(t * 60) % 2
                    frequency *= pow(2, Double(tick) * voice.vibrato / 12)
                }
                phase += frequency / sampleRate
                phase -= floor(phase)
                let value: Double
                switch voice.wave {
                case .square: value = phase < 0.5 ? 1 : -1
                case .pulse25: value = phase < 0.25 ? 1 : -1
                case .triangle: value = 4 * abs(phase - 0.5) - 1
                case .saw: value = 2 * phase - 1
                case .sine: value = sin(2 * .pi * phase)
                case .noise:
                    // LFSR noise clocked at the voice frequency, like 8-bit consoles.
                    noiseClock += frequency / sampleRate
                    while noiseClock >= 1 {
                        noiseClock -= 1
                        let bit = (noiseState ^ (noiseState >> 1)) & 1
                        noiseState = (noiseState >> 1) | (bit << 14)
                        noiseValue = (noiseState & 1) == 1 ? 1 : -1
                    }
                    value = noiseValue
                }
                let attack = min(1, t / max(voice.attack, 0.0001))
                let envelope = attack * pow(max(0, 1 - progress), voice.decay)
                let index = startIndex + i
                if index < count { out[index] += value * envelope * voice.gain }
            }
        }
        let peak = out.map(abs).max() ?? 1
        let scale = peak > 0 ? volume / peak : 0
        return out.enumerated().map { index, sample in
            // Optional sample-and-hold for a crunchier, lo-fi sound.
            let held = crush > 1 ? out[index - index % crush] : sample
            return Float(held * scale)
        }
    }

    /// A short melody of equal-length notes.
    static func notes(_ frequencies: [Double], length: Double, wave: Wave = .square, gain: Double = 1,
                      decay: Double = 0.8, gap: Double = 0) -> [Voice] {
        frequencies.enumerated().map { i, f in
            Voice(wave: wave, from: f, to: f, duration: length, start: Double(i) * (length + gap), gain: gain, decay: decay)
        }
    }
}

enum SoundEffect: CaseIterable {
    case pulse, frost, mortar, explosion, tesla, rail, pop, bossDown, leak, coin
    case build, upgrade, sell, waveStart, bossWarning, waveClear, victory, defeat, tap, error, heal, split
    case power, shield, emp, missile, research, medal
    case flame, scream, psychic, gust, tick, timeStop, warp

    /// Minimum seconds between two plays, so dense fights don't turn into noise.
    var minimumInterval: Double {
        switch self {
        case .pulse: 0.07
        case .pop, .explosion: 0.06
        case .tesla, .frost, .rail: 0.09
        case .heal, .split, .shield: 0.25
        case .missile, .flame: 0.05
        case .scream, .psychic, .gust, .tick: 0.12
        case .warp: 0.2
        case .tap: 0.03
        default: 0.02
        }
    }

    var volume: Float {
        switch self {
        case .pulse: 0.22
        case .pop, .tap: 0.3
        case .frost, .heal: 0.28
        case .tesla, .mortar: 0.35
        case .explosion, .rail: 0.4
        case .missile, .flame, .gust, .tick: 0.25
        case .scream, .psychic, .warp: 0.3
        default: 0.5
        }
    }

    var samples: [Float] {
        typealias V = Synth.Voice
        switch self {
        case .pulse:
            return Synth.render([V(wave: .pulse25, from: 1400, to: 700, duration: 0.07, decay: 2)])
        case .frost:
            return Synth.render([
                V(wave: .noise, from: 9000, to: 4000, duration: 0.22, gain: 0.5, decay: 1.5),
                V(wave: .triangle, from: 1800, to: 2600, duration: 0.18, gain: 0.6, decay: 1.2),
            ])
        case .mortar:
            return Synth.render([
                V(wave: .square, from: 180, to: 60, duration: 0.14, decay: 1.5),
                V(wave: .noise, from: 3000, to: 1000, duration: 0.06, gain: 0.6, decay: 2),
            ])
        case .explosion:
            return Synth.render([
                V(wave: .noise, from: 2200, to: 300, duration: 0.42, decay: 2.2),
                V(wave: .triangle, from: 110, to: 40, duration: 0.3, gain: 0.7, decay: 1.5),
            ])
        case .tesla:
            return Synth.render([
                V(wave: .saw, from: 220, to: 160, duration: 0.16, gain: 0.6, decay: 1, vibrato: 7),
                V(wave: .noise, from: 12000, to: 8000, duration: 0.12, gain: 0.5, decay: 1.6),
            ], crush: 3)
        case .rail:
            return Synth.render([
                V(wave: .square, from: 2400, to: 200, duration: 0.28, decay: 1.4),
                V(wave: .noise, from: 6000, to: 1500, duration: 0.1, gain: 0.5, decay: 2),
            ])
        case .pop:
            return Synth.render([V(wave: .square, from: 620, to: 180, duration: 0.08, decay: 1.8)])
        case .bossDown:
            return Synth.render([
                V(wave: .noise, from: 1800, to: 200, duration: 0.9, decay: 1.6),
                V(wave: .square, from: 300, to: 40, duration: 0.8, gain: 0.6, decay: 1.2),
            ], crush: 2)
        case .leak:
            return Synth.render([
                V(wave: .square, from: 160, to: 70, duration: 0.32, decay: 1, vibrato: 1),
            ])
        case .coin:
            return Synth.render([
                V(wave: .square, from: 988, to: 988, duration: 0.06, decay: 0.3),
                V(wave: .square, from: 1319, to: 1319, duration: 0.18, start: 0.06, decay: 1.2),
            ])
        case .build:
            return Synth.render(Synth.notes([523, 659, 784], length: 0.05, wave: .pulse25) +
                                [V(wave: .noise, from: 4000, to: 1000, duration: 0.05, gain: 0.4, decay: 2)])
        case .upgrade:
            return Synth.render(Synth.notes([523, 659, 784, 1047, 1319], length: 0.055, wave: .square, decay: 0.6))
        case .sell:
            return Synth.render(Synth.notes([1047, 784, 523], length: 0.06, wave: .pulse25) +
                                [V(wave: .square, from: 1319, to: 1319, duration: 0.12, start: 0.2, gain: 0.6, decay: 1)])
        case .waveStart:
            return Synth.render([
                V(wave: .square, from: 392, to: 392, duration: 0.14, decay: 0.4),
                V(wave: .square, from: 523, to: 523, duration: 0.3, start: 0.15, decay: 0.8),
                V(wave: .triangle, from: 131, to: 131, duration: 0.45, gain: 0.8, decay: 0.8),
            ])
        case .bossWarning:
            return Synth.render(
                Synth.notes([220, 208, 220, 208, 220, 208], length: 0.12, wave: .square, decay: 0.3) +
                [V(wave: .triangle, from: 55, to: 55, duration: 0.75, gain: 0.9, decay: 0.6)]
            )
        case .waveClear:
            return Synth.render(Synth.notes([784, 988, 1175, 1568], length: 0.07, wave: .pulse25, decay: 0.5))
        case .victory:
            return Synth.render(
                Synth.notes([523, 659, 784], length: 0.12, wave: .square, decay: 0.4) +
                [V(wave: .square, from: 1047, to: 1047, duration: 0.5, start: 0.36, decay: 0.9),
                 V(wave: .triangle, from: 262, to: 262, duration: 0.86, gain: 0.8, decay: 0.7)]
            )
        case .defeat:
            return Synth.render(
                Synth.notes([440, 349, 294], length: 0.2, wave: .square, decay: 0.5) +
                [V(wave: .square, from: 220, to: 200, duration: 0.6, start: 0.6, decay: 1, vibrato: 1),
                 V(wave: .triangle, from: 110, to: 100, duration: 1.2, gain: 0.8, decay: 1)]
            )
        case .tap:
            return Synth.render([V(wave: .pulse25, from: 1600, to: 1500, duration: 0.025, decay: 1)])
        case .error:
            return Synth.render(Synth.notes([196, 147], length: 0.08, wave: .square, decay: 0.6, gap: 0.02))
        case .heal:
            return Synth.render([V(wave: .triangle, from: 600, to: 1200, duration: 0.2, attack: 0.03, decay: 1)])
        case .split:
            return Synth.render([V(wave: .square, from: 900, to: 450, duration: 0.09, decay: 1.5, vibrato: 12)])
        case .power:
            return Synth.render([
                V(wave: .square, from: 220, to: 1760, duration: 0.35, attack: 0.01, decay: 0.8),
                V(wave: .pulse25, from: 440, to: 2200, duration: 0.35, gain: 0.5, decay: 0.9),
                V(wave: .noise, from: 6000, to: 12000, duration: 0.3, gain: 0.3, decay: 1.2),
            ])
        case .shield:
            return Synth.render([V(wave: .triangle, from: 400, to: 800, duration: 0.25, attack: 0.02, decay: 1, vibrato: 3)])
        case .emp:
            return Synth.render([
                V(wave: .saw, from: 120, to: 40, duration: 0.5, decay: 1.2, vibrato: 2),
                V(wave: .noise, from: 3000, to: 500, duration: 0.4, gain: 0.6, decay: 1.5),
            ], crush: 4)
        case .missile:
            return Synth.render([V(wave: .noise, from: 4000, to: 1200, duration: 0.12, decay: 1.5),
                                 V(wave: .square, from: 300, to: 120, duration: 0.1, gain: 0.5, decay: 2)])
        case .research:
            return Synth.render(Synth.notes([392, 523, 659, 784, 1047], length: 0.06, wave: .triangle, decay: 0.5) +
                                [V(wave: .sine, from: 1568, to: 1568, duration: 0.3, start: 0.3, gain: 0.6, decay: 1)])
        case .flame:
            return Synth.render([V(wave: .noise, from: 2500, to: 1200, duration: 0.12, decay: 1)], crush: 2)
        case .scream:
            return Synth.render([V(wave: .square, from: 1200, to: 900, duration: 0.18, decay: 1, vibrato: 2),
                                 V(wave: .noise, from: 8000, to: 6000, duration: 0.15, gain: 0.3, decay: 1.5)])
        case .psychic:
            return Synth.render([V(wave: .sine, from: 300, to: 900, duration: 0.18, decay: 1, vibrato: 7),
                                 V(wave: .triangle, from: 600, to: 1800, duration: 0.15, gain: 0.5, decay: 1.2)])
        case .gust:
            return Synth.render([V(wave: .noise, from: 5000, to: 2000, duration: 0.14, attack: 0.03, decay: 1)])
        case .tick:
            return Synth.render([V(wave: .square, from: 2000, to: 2000, duration: 0.02, decay: 1),
                                 V(wave: .square, from: 1500, to: 1500, duration: 0.02, start: 0.12, decay: 1)])
        case .timeStop:
            return Synth.render([V(wave: .triangle, from: 1200, to: 80, duration: 0.8, decay: 0.8, vibrato: 1),
                                 V(wave: .sine, from: 2400, to: 160, duration: 0.8, gain: 0.5, decay: 0.8)])
        case .warp:
            return Synth.render([V(wave: .square, from: 200, to: 1600, duration: 0.12, decay: 1, vibrato: 12)])
        case .medal:
            return Synth.render(Synth.notes([659, 784, 1047, 1319, 1568, 2093], length: 0.08, wave: .square, decay: 0.5))
        }
    }
}
