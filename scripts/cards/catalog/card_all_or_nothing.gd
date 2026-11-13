class_name CardAllOrNothing
extends ActionCard

# Tudo ou Nada: escolha uma peça sua e gire a moeda. Na sua cor, ela vira Dama e
# destrói todas as peças inimigas coladas nela (diagonais). Senão, ela é destruída.
const DIRS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

func _init() -> void:
	id = "all_or_nothing"
	icon_path = "res://assets/sprites/cards/icons/all_or_nothing.png"
	name = "Tudo ou Nada"
	description = "Escolha uma peça sua e gire a moeda. Na sua cor, ela vira Dama e destrói as peças inimigas coladas nela. Senão, ela é destruída."
	rarity = Rarity.RARE
	target_type = TargetType.ALLY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	return not board.grid[target_pos.y][target_pos.x].is_tree

static func adjacent_enemies(board: Board, pos: Vector2i, team: int) -> Array:
	var out: Array = []
	for d in DIRS:
		var n: Vector2i = pos + d
		if not board.is_valid_pos(n.y, n.x):
			continue
		var p: BoardPiece = board.grid[n.y][n.x]
		if p != Board.EMPTY and not p.is_tree and p.owner_team != team and p.owner_team != Board.NEUTRAL:
			out.append(n)
	return out

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	var main = context.get("main")
	var won: bool
	if main == null or not ("card_coin_flip_view" in main) or main.card_coin_flip_view == null:
		won = randi() % 2 == 0
	else:
		main.is_resolving_card_effect = true
		var center = main.board_offset + Vector2(board.cols * main.cell_size / 2.0, board.rows * main.cell_size / 2.0)
		main.card_coin_flip_view.play_toss_for_team(center, main.cell_size, team, "TUDO!", "NADA!")
		won = await main.card_coin_flip_view.flip_completed
		main.is_resolving_card_effect = false
	if won:
		if not piece.is_king:
			piece.is_king = true
			piece.temp_king_turns = 0
			await CardFx.crown(main, target_pos, piece)
		for n in adjacent_enemies(board, target_pos, team):
			var victim: BoardPiece = board.grid[n.y][n.x]
			if await RuleLastChance.try_save(main, n, victim):
				continue
			await CardFx.destroy(main, board, n, victim)
		_pop_banner(context, "TUDO!", Color(1.0, 0.85, 0.35), target_pos)
	else:
		if await RuleLastChance.try_save(main, target_pos, piece):
			return
		await CardFx.destroy(main, board, target_pos, piece)
		_pop_banner(context, "NADA...", Color(0.75, 0.6, 0.8), target_pos)
