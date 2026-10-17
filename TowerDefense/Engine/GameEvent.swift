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
    case auraPulse(towerID: Int, center: CGPoint, radius: CGFloat)
    case coneBlast(towerID: Int, origin: CGPoint, direction: CGPoint, range: CGFloat, angle: CGFloat)
    case mindBlast(from: CGPoint, to: CGPoint)
    case chainLightning(points: [CGPoint])
    case beam(towerID: Int, from: CGPoint, to: CGPoint)
    case shellImpact(center: CGPoint, radius: CGFloat)
    case missileImpact(center: CGPoint, radius: CGFloat)
    case boltImpact(at: CGPoint)
    case heavyHit(at: CGPoint, amount: Int)
    case immune(at: CGPoint)

    case powerActivated(towerID: Int, kind: TowerKind, name: String)
    case powerBurst(towerID: Int, center: CGPoint, radius: CGFloat)
    case powerStrikes(points: [CGPoint], splash: CGFloat)
    case frenzyStarted(towerID: Int)
    case fieldStarted(center: CGPoint, radius: CGFloat, duration: Double, type: DamageType)
    case timeStop(duration: Double)
    case rally(towerID: Int, radius: CGFloat)
    case strip(center: CGPoint, radius: CGFloat)
    case confuseWave(center: CGPoint, radius: CGFloat)

    case enemyKilled(enemyID: Int, kind: EnemyKind, at: CGPoint, bounty: Int)
    case enemyLeaked(enemyID: Int, kind: EnemyKind, livesLost: Int)
    case enemyHealed(center: CGPoint, radius: CGFloat)
    case enemyShielded(center: CGPoint, radius: CGFloat)
    case enemySplit(at: CGPoint)
    case enemyTeleported(from: CGPoint, to: CGPoint)
    case enemyPetrified(at: CGPoint)
    case bossSummon(at: CGPoint)
    case towersDisrupted(center: CGPoint, radius: CGFloat)

    case commanderAttack(kind: CommanderKind, from: CGPoint, to: CGPoint)
    case commanderSkill(kind: CommanderKind, name: String, center: CGPoint, radius: CGFloat)
    case commanderLevelUp(level: Int, at: CGPoint)

    case victory
    case defeat
}
