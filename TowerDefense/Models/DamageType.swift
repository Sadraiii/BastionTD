import Foundation

/// What kind of harm an attack does. Some villains are immune to certain types,
/// so a strong defense mixes heroes with different damage types.
enum DamageType: String, CaseIterable, Codable {
    case kinetic, explosive, cold, energy, fire, toxic, psychic, sonic

    var title: String { rawValue.capitalized }
}

/// How a hero delivers its attack.
enum AttackStyle {
    /// Homing projectile that may ricochet (Blitz, Weaver, Aegis, Cyclone).
    case bolt
    /// Lobbed shell with splash, ground only (Quake).
    case lob
    /// Pulse that hits everything in range (Glacia, Chrono).
    case aura
    /// Lightning that jumps between enemies (Stormbringer).
    case chain
    /// Straight beam that pierces everything in a line (Vanguard, Starlight).
    case beam
    /// Hits everything inside a wedge in front of the hero (Inferno, Echo).
    case cone
    /// Instant mental strike on the target (Mindwave).
    case mind
}
