class_name CardCorrupt
extends ActionCard

func _init() -> void:
	id = "corrupt"
	icon_path = "res://assets/sprites/cards/icons/corrupt.png"
	name = "Corromper"
	description = "Toma para sempre uma peça comum inimiga isolada (sem aliadas coladas nela)."
	rarity = Rarity.EPIC
	target_type = TargetType.ENEMY_PIECE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false

	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece.is_king:
		return false

	# Precisa estar isolada: nenhuma peça do MESMO dono adjacente na diagonal
	var dirs = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for d in dirs:
		var nr = target_pos.y + d.y
		var nc = target_pos.x + d.x
		if board.is_valid_pos(nr, nc):
			var neighbor: BoardPiece = board.grid[nr][nc]
			if neighbor != Board.EMPTY and neighbor.owner_team == piece.owner_team:
				return false

	return true

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	await _convert_piece(board, target_pos, piece, human_team, context)

# Troca o dono com a animação de conversão (CardFx.convert). Se a peça já estiver
# na fileira de promoção do NOVO dono, ela vira Dama na hora: mesma regra de
# quando uma peça anda até lá (Board.make_move).
func _convert_piece(board: Board, pos: Vector2i, piece: BoardPiece, human_team: int, context: Dictionary) -> void:
	var old_team: int = piece.owner_team
	var promotion_row = 0 if (human_team == board.human_team_color) else (board.rows - 1)
	await CardFx.convert(context.get("main"), pos, old_team, human_team, func():
		piece.owner_team = human_team
		piece.rooted_turns = 0
		if pos.y == promotion_row:
			piece.is_king = true)
