class_name CardRebuild
extends ActionCard

func _init() -> void:
	id = "rebuild"
	icon_path = "res://assets/sprites/cards/icons/rebuild.png"
	name = "Reconstrução"
	description = "Revive uma peça que foi capturada e a posiciona em uma casa vazia da sua primeira fileira."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func can_play(board: Board, human_team: int, _context: Dictionary = {}) -> bool:
	var current_allies = 0
	for r in range(board.rows):
		for c in range(board.cols):
			var p = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team == human_team:
				current_allies += 1
	# Só pode ser jogada se o jogador perdeu ao menos 1 peça do total inicial
	@warning_ignore("integer_division")
	var max_initial = board.initial_piece_count if board.initial_piece_count > 0 else board.get_max_deployment_rows() * (board.cols / 2)
	return current_allies < max_initial

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	# Fileira de fundo do "próprio lado" — última linha pro jogador,
	# primeira linha pra IA.
	if human_team == board.human_team_color:
		return target_pos.y == (board.rows - 1)
	return target_pos.y == 0

func execute(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> void:
	board.grid[target_pos.y][target_pos.x] = BoardPiece.new(human_team, false)
