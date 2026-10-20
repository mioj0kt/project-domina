class_name CardLuckyDuel
extends ActionCard

func _init() -> void:
	id = "lucky_duel"
	icon_path = "res://assets/sprites/cards/icons/lucky_duel.png"
	name = "Duelo de Sorte"
	description = "Escolha uma peça inimiga e gire a moeda: se cair na cor das suas peças, ela é capturada. Senão, uma peça sua aleatória é capturada."
	rarity = Rarity.COMMON
	target_type = TargetType.ENEMY_PIECE

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	var enemy_piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if enemy_piece == Board.EMPTY:
		return

	var main_node = context.get("main")
	if main_node == null or not ("card_coin_flip_view" in main_node) or main_node.card_coin_flip_view == null:
		if randi() % 2 == 0:
			board.grid[target_pos.y][target_pos.x] = Board.EMPTY
		else:
			_capture_random_own_piece(board, human_team)
		return

	main_node.is_resolving_card_effect = true

	var coin_view: CoinFlipView = main_node.card_coin_flip_view

	var center = main_node.board_offset + Vector2(
		board.cols * main_node.cell_size / 2.0,
		board.rows * main_node.cell_size / 2.0
	)
	# Favorável = a moeda cair na cor de quem jogou a carta.
	coin_view.play_toss_for_team(center, main_node.cell_size, human_team, "CAPTURADA!", "PERDEU UMA PECA!")
	var captured_enemy: bool = await coin_view.flip_completed

	if captured_enemy:
		main_node.is_resolving_card_effect = false
		# Última Chance: a vítima pode ser uma Dama do jogador (carta da IA).
		if not await RuleLastChance.try_save(main_node, target_pos, enemy_piece):
			board.grid[target_pos.y][target_pos.x] = Board.EMPTY
	else:
		main_node.is_resolving_card_effect = false
		await _capture_random_own_piece(board, human_team, main_node)

	main_node.is_resolving_card_effect = false

func _capture_random_own_piece(board: Board, team: int, main_node = null) -> void:
	var own_positions: Array = []
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team == team:
				own_positions.append(Vector2i(c, r))
	if own_positions.is_empty():
		return
	var chosen: Vector2i = own_positions[randi() % own_positions.size()]
	# Última Chance: se a sorteada for a Dama do jogador, a moeda gira antes.
	if await RuleLastChance.try_save(main_node, chosen, board.grid[chosen.y][chosen.x]):
		return
	board.grid[chosen.y][chosen.x] = Board.EMPTY
