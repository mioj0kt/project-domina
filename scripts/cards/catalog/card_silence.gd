class_name CardSilence
extends ActionCard

# Silêncio: o adversário não pode usar Cartas de Ação nos próximos 2 turnos dele.
# Ver Board.silenced_turns (o controle de cartas de cada lado consulta antes de jogar).
const DURATION_TURNS: int = 2

func _init() -> void:
	id = "silence"
	icon_path = "res://assets/sprites/cards/icons/silence.png"
	name = "Silêncio"
	description = "O inimigo não pode usar cartas nos próximos 2 turnos dele."
	rarity = Rarity.RARE
	target_type = TargetType.NONE

static func opponent(board: Board, team: int) -> int:
	return board.ai_team_color if team == board.human_team_color else board.human_team_color

func can_play(board: Board, team: int, _context: Dictionary = {}) -> bool:
	return board.silenced_turns.get(opponent(board, team), 0) <= 0

func execute(board: Board, _target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var opp: int = opponent(board, team)
	board.silenced_turns[opp] = DURATION_TURNS
	var main = context.get("main")
	if CardFx._ok(main):
		Sfx.play("bloqueio")
		var vp: Vector2 = main.get_viewport().get_visible_rect().size
		# onda apagando a mão do silenciado (embaixo = jogador, em cima = inimigo)
		var at := Vector2(vp.x / 2.0, vp.y - 90.0) if opp == main.human_team else Vector2(vp.x / 2.0, 75.0)
		Juice.ring(main, at, 160.0, Color(0.65, 0.75, 1.0), 6.0, 0.5)
		Juice.ring(main, at, 100.0, Color(0.85, 0.9, 1.0), 4.0, 0.35)
	_pop_banner(context, "SILÊNCIO!", Color(0.7, 0.8, 1.0))
