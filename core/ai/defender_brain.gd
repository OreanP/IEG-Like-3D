class_name IEGDefenderBrain
extends RefCounted
## IA de démonstration : observer l'état, proposer une commande, ne rien imposer.
## Pas de lecture de l'Input ni d'écriture dans la session.

const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")

func decide(session: IEGTrainingSession, actor: IEGPlayerState) -> IEGGameCommand:
    var command: IEGGameCommand = Command.new()
    if session.is_resetting():
        return command
    var owner: IEGPlayerState = session.get_player(session.ball.owner_id)
    if owner == null:
        var future_ball: Vector2 = Rules.planar(session.ball.position)
        future_ball += Rules.planar(session.ball.velocity) * 0.12
        _move_towards(command, actor, future_ball)
        command.sprint = actor.position.distance_to(future_ball) > 5.0
        return command
    if owner.get_id() == actor.get_id():
        # L'adversaire rouge attaque vers +Z. Il ne sprinte pas ballon au pied,
        # afin que le joueur puisse le rattraper pour essayer la récupération.
        var goal: Vector2 = Vector2(0.0, Rules.HALF_LENGTH if actor.team_id == 1 else -Rules.HALF_LENGTH)
        _move_towards(command, actor, goal)
        if actor.position.distance_to(goal) < 7.0:
            command.shoot = true
            command.shot_charge = 0.55
        return command
    if owner.team_id == actor.team_id:
        _move_towards(command, actor, actor.spawn)
        return command
    # D'abord fermer l'axe du but, puis presser directement le porteur.
    var own_goal: Vector2 = Vector2(0.0, -Rules.HALF_LENGTH if actor.team_id == 1 else Rules.HALF_LENGTH)
    var distance: float = actor.position.distance_to(owner.position)
    var predicted: Vector2 = owner.position + owner.velocity * 0.16
    var target: Vector2 = predicted
    if distance > 3.0:
        target += (own_goal - predicted).normalized() * 0.9
    _move_towards(command, actor, target)
    command.sprint = distance > 5.0
    command.aim = Rules.direction(owner.position - actor.position, actor.facing)
    command.tackle = distance <= 1.20 and actor.tackle_cooldown <= 0.0 and owner.possession_grace <= 0.0
    return command

func _move_towards(command: IEGGameCommand, actor: IEGPlayerState, target: Vector2) -> void:
    var offset: Vector2 = target - actor.position
    command.move = offset.limit_length(1.0) if offset.length() > 0.12 else Vector2.ZERO
    command.aim = Rules.direction(offset, actor.facing)
