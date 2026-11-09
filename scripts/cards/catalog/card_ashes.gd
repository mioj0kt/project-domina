class_name CardAshes
extends ActionCard

func _init() -> void:
	id = "ashes"
	icon_path = "res://assets/sprites/cards/icons/ashes.png"
	name = "Cinzas"
	description = "Apaga o fogo de uma casa em chamas."
	rarity = Rarity.COMMON
	target_type = TargetType.EMPTY_TILE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return board.fire_tiles.has(target_pos)

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for pos in board.fire_tiles.keys():
		if is_valid_target(board, pos, human_team, context):
			return true
	return false

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	board.fire_tiles.erase(target_pos)
	board.sun_tiles.erase(target_pos)
	_pop_banner(context, "CINZAS!", Color(0.7, 0.7, 0.75), target_pos)
