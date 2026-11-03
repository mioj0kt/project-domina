class_name CardFx
extends RefCounted

# Efeitos de tabuleiro das Cartas de Ação que antes aconteciam "secos":
# peça destruída, peça que nasce, peça que troca de dono, coroação e rebaixa.
# Tudo recebe o `main` do context da carta e é seguro se ele for nulo (sem
# animação, só aplica o efeito).

const COL_WHITE := Color(0.96, 0.93, 0.85)
const COL_BLACK := Color(0.55, 0.42, 0.85)
const COL_BAD := Color(0.95, 0.3, 0.25)
const COL_CROWN := Color(1.0, 0.85, 0.25)

static func team_color(team: int) -> Color:
	return COL_WHITE if team == Board.WHITE else COL_BLACK

static func _ok(main) -> bool:
	return main != null and is_instance_valid(main) and "cell_size" in main and "board_offset" in main

static func center_of(main, pos: Vector2i) -> Vector2:
	return main.board_offset + Vector2(pos.x * main.cell_size + main.cell_size / 2.0, pos.y * main.cell_size + main.cell_size / 2.0)

static func _scale_tween(main, pos: Vector2i, from: float, to: float, dur: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if not "piece_spawn_scales" in main:
		return
	var tw = main.create_tween()
	tw.tween_method(func(v): main.piece_spawn_scales[pos] = v, from, to, dur).set_trans(trans).set_ease(ease_type)
	await tw.finished

static func _release_scale(main, pos: Vector2i) -> void:
	if "piece_spawn_scales" in main:
		main.piece_spawn_scales.erase(pos)

# Peça destruída por efeito de carta (moeda, etc.): estilhaça, clarão e tremor.
static func destroy(main, board: Board, pos: Vector2i, piece: BoardPiece) -> void:
	board.grid[pos.y][pos.x] = Board.EMPTY
	board.piece_destroyed.emit(pos, piece)   # main estilhaça a peça
	if not _ok(main):
		return
	var c := center_of(main, pos)
	var col := team_color(piece.owner_team) if piece != null else COL_BAD
	Juice.flash_square(main, c, main.cell_size, Color(1.0, 0.4, 0.3, 0.55), 0.2)
	Juice.ring(main, c, main.cell_size * 0.85, COL_BAD, 5.0, 0.32)
	Juice.burst(main, c, col, 14, 240.0, 0.6, maxf(3.0, main.cell_size / 16.0), 420.0, 180.0)
	Juice.shake(main, 4.0, 0.2)
	await main.get_tree().create_timer(0.3).timeout

# Peça que surge numa casa (já colocada em board.grid): cresce com salto, anel
# e fagulhas na cor do time.
static func spawn(main, pos: Vector2i, team: int) -> void:
	if not _ok(main):
		return
	if "piece_spawn_scales" in main:
		main.piece_spawn_scales[pos] = 0.0
	var c := center_of(main, pos)
	var col := team_color(team)
	Juice.ring(main, c, main.cell_size * 0.9, col, 5.0, 0.4)
	Juice.burst(main, c, col, 12, 170.0, 0.6, maxf(3.0, main.cell_size / 18.0), -120.0, 40.0, Vector2.UP)
	Juice.sparkle(main, c, 10)
	await _scale_tween(main, pos, 0.0, 1.0, 0.5, Tween.TRANS_BACK, Tween.EASE_OUT)
	_release_scale(main, pos)
	Juice.dust(main, c, main.cell_size)

# Várias peças nascendo em sequência (Grande Reforço).
static func spawn_many(main, positions: Array, team: int, gap: float = 0.08) -> void:
	if not _ok(main):
		return
	for pos in positions:
		if "piece_spawn_scales" in main:
			main.piece_spawn_scales[pos] = 0.0
	for i in range(positions.size()):
		spawn(main, positions[i], team)   # sem await: cada uma anima por conta própria
		await main.get_tree().create_timer(gap).timeout
	await main.get_tree().create_timer(0.45).timeout

# Troca de dono (Corromper/Rebelião): a peça encolhe soltando a cor antiga e
# volta na cor nova. `apply` roda no ponto mais fechado, quando o dono muda.
static func convert(main, pos: Vector2i, old_team: int, new_team: int, apply: Callable) -> void:
	if not _ok(main):
		apply.call()
		return
	var c := center_of(main, pos)
	Juice.ring(main, c, main.cell_size * 0.9, team_color(old_team), 4.0, 0.25)
	await _scale_tween(main, pos, 1.0, 0.1, 0.22, Tween.TRANS_QUAD, Tween.EASE_IN)
	apply.call()
	Juice.burst(main, c, team_color(old_team), 8, 150.0, 0.45, 4.0, 200.0, 180.0)
	Juice.ring(main, c, main.cell_size * 1.0, team_color(new_team), 6.0, 0.4)
	Juice.burst(main, c, team_color(new_team), 12, 220.0, 0.6, 4.0, 180.0, 180.0)
	Juice.flash_square(main, c, main.cell_size, Color(team_color(new_team), 0.5), 0.2)
	await _scale_tween(main, pos, 0.1, 1.0, 0.4, Tween.TRANS_BACK, Tween.EASE_OUT)
	_release_scale(main, pos)

# Coroação com a animação de giro do Corromper antigo. A peça já deve estar com
# is_king = true (a animação desenha a versão coroada por cima da casa).
static func crown(main, pos: Vector2i, piece: BoardPiece) -> void:
	if not _ok(main) or not ("king_animation_view" in main) or main.king_animation_view == null:
		return
	main.animating_coronation_tile = pos
	var c := center_of(main, pos)
	Juice.ring(main, c, main.cell_size * 0.9, COL_CROWN, 5.0, 0.35)
	await main.king_animation_view.play_coronation(c, main.cell_size, piece)
	main.animating_coronation_tile = Vector2i(-1, -1)
	Juice.sparkle(main, c, 16)

# Dama que perde a coroa: a peça "afunda", a coroa vira estilhaços dourados.
static func demote(main, pos: Vector2i, apply: Callable) -> void:
	if not _ok(main):
		apply.call()
		return
	var c := center_of(main, pos)
	await _scale_tween(main, pos, 1.0, 1.25, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT)
	apply.call()
	Juice.burst(main, c + Vector2(0, -main.cell_size * 0.25), COL_CROWN, 14, 200.0, 0.7, maxf(3.0, main.cell_size / 16.0), 700.0, 70.0, Vector2.UP)
	Juice.ring(main, c, main.cell_size * 0.8, COL_BAD, 4.0, 0.3)
	Juice.shake(main, 3.0, 0.16)
	await _scale_tween(main, pos, 1.25, 0.8, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN)
	await _scale_tween(main, pos, 0.8, 1.0, 0.18, Tween.TRANS_BACK, Tween.EASE_OUT)
	_release_scale(main, pos)
