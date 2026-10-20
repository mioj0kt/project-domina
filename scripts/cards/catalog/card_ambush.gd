class_name CardAmbush
extends ActionCard

func _init() -> void:
	id = "ambush"
	icon_path = "res://assets/sprites/cards/icons/ambush.png"
	name = "Emboscada"
	description = "Uma peça inimiga não pode andar nem capturar no proximo turno dele."
	rarity = Rarity.COMMON
	target_type = TargetType.ENEMY_PIECE

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), human_team, context):
				return true
	return false

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece.rooted_turns > 0:
		return false
	# Trava anti-vitoria-instantanea: o inimigo precisa continuar com jogadas.
	piece.rooted_turns = 1
	var enemy_still_moves = not board.get_all_valid_moves(piece.owner_team).is_empty()
	piece.rooted_turns = 0
	return enemy_still_moves

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	piece.rooted_turns = 1
	_pop_banner(context, "EMBOSCADA!", Color(0.55, 0.4, 0.8), target_pos)
