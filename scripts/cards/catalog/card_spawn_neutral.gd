class_name CardSpawnNeutral
extends ActionCard
# Base das cartas que fazem BROTAR uma peça neutra (árvore, cacto, sarcófago) numa
# casa escura vazia — as mesmas peças das Leis de Chefe, agora na mão do jogador.
# A peça nasce com a mesma animação de "crescer" do chefe, e a carta só deixa
# jogar onde nenhum dos lados fica sem jogada (igual ao chefe).

func _init() -> void:
	target_type = TargetType.EMPTY_TILE

func _make_piece(_owner_team: int) -> BoardPiece:
	return BoardPiece.make_tree()

func _banner_text() -> String:
	return "BROTOU!"

func _banner_color() -> Color:
	return Color(0.45, 0.9, 0.4)

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), human_team, context):
				return true
	return false

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	if board.vine_tiles.has(target_pos) or board.fire_tiles.has(target_pos):
		return false
	# Nenhum dos lados pode ficar sem jogada por causa da peça.
	var other: int = Board.BLACK if human_team == Board.WHITE else Board.WHITE
	board.grid[target_pos.y][target_pos.x] = _make_piece(human_team)
	var ok: bool = not board.get_all_valid_moves(human_team).is_empty() and not board.get_all_valid_moves(other).is_empty()
	board.grid[target_pos.y][target_pos.x] = Board.EMPTY
	return ok

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	board.grid[target_pos.y][target_pos.x] = _make_piece(human_team)
	_pop_banner(context, _banner_text(), _banner_color(), target_pos)
	var main_node = context.get("main")
	if main_node != null and "piece_spawn_scales" in main_node:
		main_node.piece_spawn_scales[target_pos] = 0.0
		var tw = main_node.create_tween()
		tw.tween_method(func(v): main_node.piece_spawn_scales[target_pos] = v, 0.0, 1.0, 0.45)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
