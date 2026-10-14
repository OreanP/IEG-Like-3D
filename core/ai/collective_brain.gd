class_name IEGCollectiveBrain
extends RefCounted
## Propose des déplacements depuis des couloirs fixes. Aucun allié IA ne passe/tire.
const Command = preload("res://core/game_command.gd")
const Rules = preload("res://core/training_rules.gd")

func decide(session: IEGTrainingSession, actor: IEGPlayerState) -> IEGGameCommand:
    var command: IEGGameCommand = Command.new()
    if session.is_resetting() or session.ball.owner_id == actor.get_id():
        return command
    var owner: IEGPlayerState = session.get_player(session.ball.owner_id)
    var ball_point: Vector2 = Rules.planar(session.ball.position)
    var target: Vector2 = actor.spawn
    # Un seul joueur de champ par équipe poursuit le ballon ou presse le porteur.
    var chaser: IEGPlayerState = null
    var distance: float = INF
    for player: IEGPlayerState in session.players:
        if player.team_id != actor.team_id or player.is_goalkeeper:
            continue
        var candidate: float = player.position.distance_squared_to(ball_point)
        if candidate < distance:
            chaser = player
            distance = candidate
    if (owner == null or owner.team_id != actor.team_id) and chaser == actor:
        target = ball_point
        if owner != null:
            command.tackle = actor.position.distance_to(owner.position) < 1.2
            command.aim = Rules.direction(owner.position - actor.position, actor.facing)
    else:
        # Les couloirs latéraux restent distincts ; le bloc accompagne le jeu sans
        # converger sur le porteur. La zone de soutien est bornée près des buts.
        target.y = clampf(actor.spawn.y + (ball_point.y - 4.0) * 0.35, -12.0, 12.0)
        if owner != null and owner.team_id == actor.team_id:
            var away: Vector2 = target - owner.position
            if away.length() < 3.0:
                target.x += -3.0 if actor.spawn.x <= 0.0 else 3.0
    var offset: Vector2 = target - actor.position
    command.move = offset.limit_length(1.0) if offset.length() > 0.35 else Vector2.ZERO
    if not command.tackle:
        command.aim = Rules.direction(command.move, actor.facing)
    return command
