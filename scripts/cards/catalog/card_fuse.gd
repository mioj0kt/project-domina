class_name CardFuse
extends ActionCard

func _init() -> void:
	id = "fuse"
	icon_path = "res://assets/sprites/cards/icons/fuse.png"
	name = "Estopim"
	description = "Marca uma peça sua. Quando ela for capturada, a casa dela e as 4 diagonais pegam fogo por 2 turnos: quem a capturou queima junto."
	rarity = Rarity.RARE
	target_type = TargetType.ALLY_PIECE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	var p: BoardPiece = board.grid[target_pos.y][target_pos.x]
	return not p.is_tree and not p.fuse

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), human_team, context):
				return true
	return false

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	board.grid[target_pos.y][target_pos.x].fuse = true
	_pop_banner(context, "ESTOPIM!", Color(1.0, 0.5, 0.15), target_pos)
