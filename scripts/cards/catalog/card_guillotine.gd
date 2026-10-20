class_name CardGuillotine
extends ActionCard

func _init() -> void:
	id = "guillotine"
	icon_path = "res://assets/sprites/cards/icons/guillotine.png"
	name = "Guilhotina"
	description = "Captura imediatamente uma Dama inimiga."
	rarity = Rarity.LEGENDARY
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
	return board.grid[target_pos.y][target_pos.x].is_king

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	# Última Chance: se a Dama é do jogador (Guilhotina da IA), a moeda gira antes.
	if await RuleLastChance.try_save(context.get("main"), target_pos, piece):
		return
	board.grid[target_pos.y][target_pos.x] = Board.EMPTY
	board.piece_destroyed.emit(target_pos, piece)
	_pop_banner(context, "GUILHOTINA!", Color(0.9, 0.25, 0.3), target_pos)
