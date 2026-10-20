class_name CardTripleToss
extends ActionCard

# Cara ou Coroa Triplo: sem alvo à escolha. Sorteia até 3 peças inimigas e gira
# 3 moedas em sequência — cada moeda na cor de quem jogou captura a peça
# sorteada dela na hora; cada moeda contra custa uma peça aleatória sua.
const COINS: int = 3

func _init() -> void:
	id = "triple_toss"
	icon_path = "res://assets/sprites/cards/icons/triple_toss.png"
	name = "Cara ou Coroa Triplo"
	description = "Sorteia até 3 peças inimigas e gira 3 moedas: cada moeda que cair na cor das suas peças captura a peça sorteada do inimigo. Cada uma que cair contra você custa uma peça sua aleatória."
	rarity = Rarity.EPIC
	target_type = TargetType.NONE

func can_play(board: Board, human_team: int, _context: Dictionary = {}) -> bool:
	return not _enemy_positions(board, human_team).is_empty()

func execute(board: Board, _target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	var enemies: Array = _enemy_positions(board, human_team)
	enemies.shuffle()
	var picks: Array = enemies.slice(0, mini(COINS, enemies.size()))
	if picks.is_empty():
		return

	var main_node = context.get("main")
	var results: Array = []
	if main_node == null or not ("multi_coin_flip_view" in main_node) or main_node.multi_coin_flip_view == null:
		for i in range(picks.size()):
			results.append(randi() % 2 == 0)
	else:
		main_node.is_resolving_card_effect = true
		var view: MultiCoinFlipView = main_node.multi_coin_flip_view
		var is_white: bool = human_team == Board.WHITE
		view.white_sprite_path = BoardPiece.TEXTURE_WHITE_PATH
		view.black_sprite_path = BoardPiece.TEXTURE_BLACK_PATH
		view.favorable_is_white = is_white
		view.win_text = "%s! CAPTURA!" % CoinFlipView.color_word(is_white)
		view.lose_text = "%s... PERDEU!" % CoinFlipView.color_word(not is_white)
		var center: Vector2 = main_node.board_offset + Vector2(board.cols * main_node.cell_size / 2.0, board.rows * main_node.cell_size / 2.0)
		results = await view.play_sequence(center, picks.size(), main_node.cell_size)
		view.clear()

	for i in range(picks.size()):
		if results[i]:
			var pos: Vector2i = picks[i]
			var victim: BoardPiece = board.grid[pos.y][pos.x]
			if victim != Board.EMPTY and not victim.is_tree:
				board.grid[pos.y][pos.x] = Board.EMPTY
				board.piece_destroyed.emit(pos, victim)
				_pop_banner(context, "CAPTURADA!", Color(0.4, 0.9, 0.5), pos)
		else:
			await _lose_random_own_piece(board, human_team, main_node, context)
		if main_node != null:
			await main_node.get_tree().create_timer(0.35).timeout

	if main_node != null:
		main_node.is_resolving_card_effect = false

func _enemy_positions(board: Board, team: int) -> Array:
	var out: Array = []
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team != team and not p.is_tree:
				out.append(Vector2i(c, r))
	return out

func _lose_random_own_piece(board: Board, team: int, main_node, context: Dictionary) -> void:
	var own: Array = []
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.owner_team == team and not p.is_tree:
				own.append(Vector2i(c, r))
	if own.is_empty():
		return
	var chosen: Vector2i = own[randi() % own.size()]
	var piece: BoardPiece = board.grid[chosen.y][chosen.x]
	# Última Chance: se a sorteada for a Dama do jogador, a moeda gira antes.
	if await RuleLastChance.try_save(main_node, chosen, piece):
		return
	board.grid[chosen.y][chosen.x] = Board.EMPTY
	board.piece_destroyed.emit(chosen, piece)
	_pop_banner(context, "PECA PERDIDA!", Color(0.9, 0.3, 0.3), chosen)
