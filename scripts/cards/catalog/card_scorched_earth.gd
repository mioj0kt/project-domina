class_name CardScorchedEarth
extends ActionCard

const DURATION_TURNS: int = 2
const NEIGHBORS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

func _init() -> void:
	id = "scorched_earth"
	icon_path = "res://assets/sprites/cards/icons/scorched_earth.png"
	name = "Terra Queimada"
	description = "A casa escolhida e as 4 vizinhas pegam fogo por 2 turnos. Peça que pousar nelas é destruída."
	rarity = Rarity.EPIC
	target_type = TargetType.EMPTY_TILE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return not board.fire_tiles.has(target_pos)

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	board.ignite(target_pos, DURATION_TURNS, team == board.human_team_color)
	for d in NEIGHBORS:
		var n = target_pos + d
		if board.is_valid_pos(n.y, n.x):
			board.ignite(n, DURATION_TURNS, team == board.human_team_color)
	_pop_banner(context, "TERRA QUEIMADA!", Color(1.0, 0.5, 0.15), target_pos)
