import CoreGraphics

/// Things that happened during a simulation step. The engine emits them;
/// the session, scene and audio react with UI, effects and sound.
enum GameEvent {
    case waveStarted(number: Int, isBoss: Bool, newKinds: [EnemyKind])
    case waveCleared(number: Int, bonus: Int)
    case earlyCallBonus(amount: Int)

    case towerBuilt(towerID: Int, kind: TowerKind, cell: GridPoint)
    case towerUpgraded(towerID: Int, path: Int, tier: Int)
    case towerSold(towerID: Int, cell: GridPoint, refund: Int)

    case shotFired(towerID: Int, kind: TowerKind)
    case frostPulse(center: CGPoint, radius: CGFloat)
    case chainLightning(points: [CGPoint])
    case railBeam(from: CGPoint, to: CGPoint)
    case shellImpact(center: CGPoint, radius: CGFloat)
    case missileImpact(center: CGPoint, radius: CGFloat)
    case boltImpact(at: CGPoint)
    case heavyHit(at: CGPoint, amount: Int)

    case powerActivated(towerID: Int, kind: TowerKind, name: String)
    case powerBurst(towerID: Int, center: CGPoint, radius: CGFloat)
    case powerStrikes(points: [CGPoint], splash: CGFloat)
    case frenzyStarted(towerID: Int)
    case fieldStarted(center: CGPoint, radius: CGFloat, duration: Double)

    case enemyKilled(enemyID: Int, kind: EnemyKind, at: CGPoint, bounty: Int)
    case enemyLeaked(enemyID: Int, kind: EnemyKind, livesLost: Int)
    case enemyHealed(center: CGPoint, radius: CGFloat)
    case enemyShielded(center: CGPoint, radius: CGFloat)
    case enemySplit(at: CGPoint)
    case bossSummon(at: CGPoint)
    case towersDisrupted(center: CGPoint, radius: CGFloat)

    case victory
    case defeat
}
