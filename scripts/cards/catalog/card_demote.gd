class_name CardDemote
extends ActionCard

func _init() -> void:
	id = "demote"
	icon_path = "res://assets/sprites/cards/icons/demote.png"
	name = "Rebaixar"
	description = "Uma Dama inimiga volta a ser uma peça comum."
	rarity = Rarity.RARE
	target_type = TargetType.ENEMY_PIECE

func can_play(board: Board, human_team: int, _context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if _is_enemy_king(board, Vector2i(c, r), human_team):
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
	# Última Chance: salva = continua Dama (o próprio perigo era virar peça comum).
	if await RuleLastChance.try_save(context.get("main"), target_pos, piece, true):
		return
	piece.is_king = false
	piece.temp_king_turns = 0
	_pop_banner(context, "REBAIXADA!", Color(0.9, 0.45, 0.4), target_pos)

func _is_enemy_king(board: Board, pos: Vector2i, team: int) -> bool:
	var p: BoardPiece = board.grid[pos.y][pos.x]
	return p != Board.EMPTY and p.is_king and p.owner_team != team and not p.is_tree
