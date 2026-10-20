class_name CardScorchedEarth
extends ActionCard

const DURATION_TURNS: int = 2
const NEIGHBORS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

func _init() -> void:
	id = "scorched_earth"
	icon_path = "res://assets/sprites/cards/icons/scorched_earth.png"
	name = "Terra Queimada"
	description = "A casa e as 4 vizinhas pegam fogo por 2 turnos: a peça POUSAR nelas é destruída."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return not board.fire_tiles.has(target_pos)

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	board.fire_tiles[target_pos] = DURATION_TURNS
	for d in NEIGHBORS:
		var n = target_pos + d
		if board.is_valid_pos(n.y, n.x):
			board.fire_tiles[n] = DURATION_TURNS
	_pop_banner(context, "TERRA QUEIMADA!", Color(1.0, 0.5, 0.15), target_pos)
