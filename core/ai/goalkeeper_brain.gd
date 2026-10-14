class_name IEGGoalkeeperBrain
extends RefCounted
## L'IA propose le placement et la relance adverse ; la session décide des arrêts.
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")

func decide(session: IEGTrainingSession, keeper: IEGPlayerState) -> IEGGameCommand:
    var command: IEGGameCommand = Command.new()
    if session.is_resetting():
        return command
    var own_side: float = 1.0 if keeper.team_id == 0 else -1.0
    if session.ball.owner_id == keeper.get_id():
        # Un gardien allié capturant le ballon est immédiatement contrôlé.
        if keeper.team_id != session.LOCAL_TEAM and keeper.keeper_hold_time >= 0.6:
            command.pass_ball = true
            command.lob_pass = true
            command.aim = Vector2(0.0, -own_side)
        return command
    var point: Vector2 = Rules.planar(session.ball.position)
    var target: Vector2 = Vector2(clampf(point.x * 0.55, -2.4, 2.4), own_side * 16.2)
    # Accompagner le ballon lent dans sa zone, sans sortir comme un joueur de champ.
    if session.ball.owner_id < 0 and point.y * own_side > 12.5:
        target = point.clamp(Vector2(-3.8, 12.5) if own_side > 0.0 else Vector2(-3.8, -17.4),
            Vector2(3.8, 17.4) if own_side > 0.0 else Vector2(3.8, -12.5))
    var offset: Vector2 = target - keeper.position
    command.move = offset.limit_length(1.0) if offset.length() > 0.15 else Vector2.ZERO
    command.aim = Rules.direction(point - keeper.position, Vector2(0.0, -own_side))
    return command
