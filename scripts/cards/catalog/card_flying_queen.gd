class_name CardFlyingQueen
extends ActionCard

func _init() -> void:
	id = "flying_queen"
	icon_path = "res://assets/sprites/cards/icons/flying_queen.png"
	name = "Dama Voadora"
	description = "Uma Dama sua se move duas vezes neste turno."
	rarity = Rarity.COMMON
	target_type = TargetType.ALLY_PIECE

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), human_team, context):
				return true
	return false

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return board.grid[target_pos.y][target_pos.x].is_king

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	board.extra_move_piece = piece
	_pop_banner(context, "DAMA VOADORA!", Color(0.5, 0.85, 1.0), target_pos)
