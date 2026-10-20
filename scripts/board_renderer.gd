class_name BoardRenderer
extends Node2D

# Renderização do tabuleiro (peças, seleção, alvos, hazards do boss, highlight
# de cartas de ação), extraída de main.gd.
#
# Em vez de exigir que main.gd chame queue_redraw() no momento exato certo
# (main.gd tinha ~20 pontos de chamada espalhados — fácil esquecer um e gerar
# um bug visual sutil), este nó simplesmente se redesenha a cada frame. Para
# um tabuleiro de damas isso é computacionalmente desprezível, e elimina essa
# classe inteira de bug em troca de um _process trivial.
#
# Lê o estado do host (hoje, main.gd) só para leitura — nunca escreve nele:
# board, board_offset, cell_size, current_duel, selected_tile, selection_pulse,
# valid_moves_for_selected, show_enemy_threats, ai_team, action_cards,
# animating_coronation_tile, moving_piece_tile, piece_spawn_scales.

var host: Node2D
var _mist_tex: GradientTexture2D = null

# Sprites das leis do Chefe da Floresta (assets/sprites/fx). Se um arquivo não
# existir, o desenho procedural antigo continua servindo de reserva.
const FX_DIR: String = "res://assets/sprites/fx/"
const ROOT_GROW_SECS: float = 0.4
var _fx_cache: Dictionary = {}
var _root_t0: Dictionary = {}   # instance_id da peça -> ms em que ficou enraizada (visto pela 1ª vez)

func _fx(tex_name: String) -> Texture2D:
	if not _fx_cache.has(tex_name):
		var path: String = FX_DIR + tex_name + ".png"
		_fx_cache[tex_name] = load(path) if ResourceLoader.exists(path) else null
	return _fx_cache[tex_name]

# Quadrado de 32 px de arte, ampliado em ESCALA INTEIRA (pixel perfeito) e centrado.
func _sprite_rect(center: Vector2, cell: float) -> Rect2:
	var px: float = 32.0 * maxf(1.0, floorf(cell / 32.0))
	return Rect2((center - Vector2(px, px) / 2.0).round(), Vector2(px, px))

func setup(p_host: Node2D) -> void:
	host = p_host
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if host == null or host.board == null:
		return

	var board: Board = host.board
	var board_offset: Vector2 = host.board_offset
	var cell_size: float = host.cell_size

	if BoardSkin.has_sprite(board.skin_id):
		# Sprite único 8x8 fatiado em código (moldura + 2 casinhas) e
		# remontado pro tamanho real deste tabuleiro.
		if BoardSkin.frame_over_tiles(board.skin_id):
			# Deserto: a borda de areia/pedra cobre a beirada das casas (como no mapa).
			BoardSkin.draw_tiles(self, board_offset, board.rows, board.cols, cell_size, board.light_tile_tint, board.dark_tile_tint, board.skin_id)
			BoardSkin.draw_frame(self, board_offset, board.rows, board.cols, cell_size, board.frame_tint, board.skin_id)
		else:
			BoardSkin.draw_frame(self, board_offset, board.rows, board.cols, cell_size, board.frame_tint, board.skin_id)
			BoardSkin.draw_tiles(self, board_offset, board.rows, board.cols, cell_size, board.light_tile_tint, board.dark_tile_tint, board.skin_id)
	else:
		for r in range(board.rows):
			for c in range(board.cols):
				var rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
				var base_color = board.light_tile_color if (r + c) % 2 == 0 else board.dark_tile_color
				draw_rect(rect, base_color)
				draw_rect(rect, board.grid_border_color, false, 1.0)

	for pos in board.scorched_tiles.keys():
		var tile_rect = Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
		if board.sand_tiles.has(pos):
			_draw_sand_cover(tile_rect, pos)
			continue
		draw_rect(tile_rect, Color(1.0, 0.3, 0.05, 0.5))
		PixelRenderer.draw_pixel_corners(self, tile_rect, Color(1.0, 0.75, 0.1, 0.95), 8.0, 2.5)

	_draw_fire_tiles(board, board_offset, cell_size)
	_draw_quicksand_tiles(board, board_offset, cell_size)
	_draw_desert_boss_telegraph(board_offset, cell_size)
	_draw_light_tile_laws(board, board_offset, cell_size)

	if board.rule_pipeline != null and (board.rule_pipeline.has_rule("sacred_zone") or board.rule_pipeline.has_rule("power_center")):
		var center_color = Color(0.85, 0.55, 1.0, 0.4) if board.rule_pipeline.has_rule("sacred_zone") else Color(1.0, 0.85, 0.3, 0.4)
		var center_border = Color(0.9, 0.6, 1.0, 0.9) if board.rule_pipeline.has_rule("sacred_zone") else Color(1.0, 0.9, 0.4, 0.9)
		for r in range(board.rows):
			for c in range(board.cols):
				if board.is_center_tile(r, c):
					var center_rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
					draw_rect(center_rect, center_color)
					PixelRenderer.draw_pixel_corners(self, center_rect, center_border, 8.0, 2.0)

	if host.current_duel is DuelBoss and host.current_duel.law_id == DuelBoss.LAW_FROG:
		# Só desenha o destaque vermelho DEPOIS que as moscas terminarem de
		# pousar — antes disso, hazard_tiles já está preenchido mas as
		# moscas ainda estão voando pra lá, então mostrar o vermelho antes
		# da hora entrega a casa antes da mosca sequer ter chegado.
		var flies_still_landing = host.frog_animation_view != null and host.frog_animation_view.is_spawning_flies
		if not flies_still_landing:
			for pos in host.current_duel.hazard_tiles:
				var hazard_rect = Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
				draw_rect(hazard_rect, Color(0.85, 0.1, 0.2, 0.35))
				PixelRenderer.draw_pixel_corners(self, hazard_rect, Color(1.0, 0.2, 0.3, 0.85), 8.0, 2.0)

	if host.selected_tile != Vector2i(-1, -1):
		var selected_rect = Rect2(board_offset.x + host.selected_tile.x * cell_size, board_offset.y + host.selected_tile.y * cell_size, cell_size, cell_size)
		PixelRenderer.draw_pixel_selected_tile(self, selected_rect, host.selection_pulse)

	# Indicador de captura obrigatória: só aparece quando o jogador
	# está REALMENTE sendo forçado a capturar (respeita regras como
	# Captura Opcional, que tornam a captura não-obrigatória mesmo
	# disponível) — marca as peças que podem realizá-la com um contorno
	# grosso e pulsante. Continua visível mesmo depois do jogador
	# selecionar outra peça, pra sempre dar pra ver quem tem a captura
	# disponível.
	if host.current_turn == host.human_team:
		var capture_mandatory = true
		if board.rule_pipeline != null:
			capture_mandatory = board.rule_pipeline.is_capture_mandatory(host.human_team, board.human_team_color)

		if capture_mandatory:
			var all_moves = board.get_all_valid_moves(host.human_team)
			var must_capture_from: Dictionary = {}
			for m in all_moves:
				if m.get("is_capture", false) and not m.get("optional", false):
					must_capture_from[m["from"]] = true
			if not must_capture_from.is_empty():
				var pulse_alpha = 0.6 + 0.4 * host.selection_pulse
				for from_pos in must_capture_from.keys():
					var must_rect = Rect2(board_offset.x + from_pos.x * cell_size, board_offset.y + from_pos.y * cell_size, cell_size, cell_size)
					PixelRenderer.draw_pixel_corners(self, must_rect, Color(1.0, 0.65, 0.05, pulse_alpha), 12.0, 4.0)

	for m in host.valid_moves_for_selected:
		var target_rect = Rect2(board_offset.x + m["to"].x * cell_size, board_offset.y + m["to"].y * cell_size, cell_size, cell_size)
		PixelRenderer.draw_pixel_move_target(self, target_rect, m["is_capture"], host.selection_pulse)

	if host.show_enemy_threats:
		var enemy_moves = board.get_all_valid_moves(host.ai_team)
		for em in enemy_moves:
			var threat_rect = Rect2(board_offset.x + em["to"].x * cell_size, board_offset.y + em["to"].y * cell_size, cell_size, cell_size)
			var threat_col = Color(1.0, 0.2, 0.2, 0.4) if em["is_capture"] else Color(1.0, 0.8, 0.2, 0.25)
			draw_rect(threat_rect, threat_col)
			PixelRenderer.draw_pixel_corners(self, threat_rect, Color(1.0, 0.2, 0.2, 0.9), 6.0, 2.0)

	if not host.predicted_ai_move.is_empty():
		var from_pos: Vector2i = host.predicted_ai_move["from"]
		var to_pos: Vector2i = host.predicted_ai_move["to"]
		var prophecy_color = Color(0.85, 0.4, 1.0, 0.9)
		var from_rect = Rect2(board_offset.x + from_pos.x * cell_size, board_offset.y + from_pos.y * cell_size, cell_size, cell_size)
		var to_rect = Rect2(board_offset.x + to_pos.x * cell_size, board_offset.y + to_pos.y * cell_size, cell_size, cell_size)
		draw_rect(from_rect, Color(prophecy_color.r, prophecy_color.g, prophecy_color.b, 0.3))
		draw_rect(to_rect, Color(prophecy_color.r, prophecy_color.g, prophecy_color.b, 0.3))
		PixelRenderer.draw_pixel_corners(self, from_rect, prophecy_color, 8.0, 2.5)
		PixelRenderer.draw_pixel_corners(self, to_rect, prophecy_color, 8.0, 2.5)
		var line_from = board_offset + Vector2(from_pos.x * cell_size + cell_size / 2.0, from_pos.y * cell_size + cell_size / 2.0)
		var line_to = board_offset + Vector2(to_pos.x * cell_size + cell_size / 2.0, to_pos.y * cell_size + cell_size / 2.0)
		draw_line(line_from, line_to, prophecy_color, 3.0)

	if host.action_cards != null and host.action_cards.has_selected_card():
		for r in range(board.rows):
			for c in range(board.cols):
				var pos = Vector2i(c, r)
				if host.action_cards.is_target_valid(pos):
					var tile_rect = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
					draw_rect(tile_rect, Color(0.2, 0.8, 1.0, 0.25 * host.selection_pulse))
					PixelRenderer.draw_pixel_corners(self, tile_rect, Color(0.3, 0.9, 1.0, 0.95), 8.0, 2.0)

	for r in range(board.rows):
		for c in range(board.cols):
			var pos = Vector2i(c, r)
			var piece_obj: BoardPiece = board.grid[r][c]

			if pos == host.animating_coronation_tile or pos == host.moving_piece_tile:
				continue

			if piece_obj != Board.EMPTY:
				# Peças do chefe somem na névoa; árvores e as suas continuam visíveis.
				if piece_obj.owner_team == host.ai_team and host.current_duel != null and host.current_duel.is_fogged(pos):
					continue
				var center = board_offset + Vector2(c * cell_size + cell_size / 2.0, r * cell_size + cell_size / 2.0)
				var scale_factor = host.piece_spawn_scales.get(pos, 1.0)
				_draw_roots_back(piece_obj, center, cell_size * scale_factor)
				PixelRenderer.draw_piece(self, piece_obj, center, cell_size, scale_factor)
				_draw_piece_status(piece_obj, center, cell_size * scale_factor)

	_draw_night_and_status(board, board_offset, cell_size)

# Terra Queimada: chamas animadas (spritesheet 8 frames de 64x64, loop a 8 fps)
# sobre as casas em fogo. Cada casa começa num frame diferente pra não piscarem
# em uníssono.
const FIRE_SHEET: String = "res://assets/sprites/fx/chama_sheet.png"
const FIRE_FRAMES: int = 8
const FIRE_FRAME_PX: int = 64
const FIRE_FPS: float = 8.0
var _fire_tex: Texture2D = null

# Areia soterrada (Tempestade de Areia / Ampulheta): casa coberta, bloqueada.
func _draw_sand_cover(rect: Rect2, pos: Vector2i) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	draw_rect(rect, Color(0.80, 0.64, 0.38, 0.93))
	var u: float = rect.size.x / 100.0
	for k in range(4):
		var y: float = rect.position.y + rect.size.y * (0.18 + 0.22 * k)
		var pts := PackedVector2Array()
		for i in range(9):
			var x: float = rect.position.x + rect.size.x * (float(i) / 8.0)
			pts.append(Vector2(x, y + sin(t * 1.4 + float(i) * 0.9 + float(k) * 1.7 + pos.x + pos.y) * 3.0 * u))
		draw_polyline(pts, Color(0.62, 0.46, 0.24, 0.8), maxf(2.0, 2.0 * u))
	for k in range(5):
		var gx: float = fposmod(float(k) * 37.0 + float(pos.x * 13 + pos.y * 7) + t * 14.0, 100.0)
		var gy: float = fposmod(float(k) * 53.0 + float(pos.x * 5 + pos.y * 17), 100.0)
		draw_rect(Rect2(rect.position + Vector2(gx, gy) * u, Vector2(3, 3) * u), Color(0.95, 0.85, 0.6, 0.85))
	PixelRenderer.draw_pixel_corners(self, rect, Color(0.95, 0.8, 0.5, 0.95), 8.0, 2.0)

# Areia Movediça: espiral escura que gira.
func _draw_quicksand_tiles(board: Board, board_offset: Vector2, cell_size: float) -> void:
	if board.quicksand_tiles.is_empty():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	for pos in board.quicksand_tiles.keys():
		var rect := Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
		draw_rect(rect, Color(0.36, 0.24, 0.12, 0.78))
		var ctr: Vector2 = rect.get_center()
		for k in range(4):
			var rad: float = cell_size * (0.12 + 0.09 * float(k))
			var a0: float = t * (1.6 - 0.3 * float(k)) + float(k) * 1.3
			draw_arc(ctr, rad, a0, a0 + TAU * 0.72, 18, Color(0.85, 0.65, 0.35, 0.75), maxf(2.0, cell_size * 0.025))
		draw_rect(Rect2(ctr - Vector2(2, 2), Vector2(4, 4)), Color(0.2, 0.12, 0.06, 0.95))
		PixelRenderer.draw_pixel_corners(self, rect, Color(0.8, 0.55, 0.25, 0.9), 8.0, 2.0)

# Casas que a lei do chefe do deserto vai afetar no próximo ciclo.
func _draw_desert_boss_telegraph(board_offset: Vector2, cell_size: float) -> void:
	if host == null or not (host.current_duel is DuelBossDesert):
		return
	var duel: DuelBossDesert = host.current_duel
	if duel.telegraph_tiles.is_empty():
		return
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	var fill := Color(1.0, 0.45, 0.1, 0.10 + 0.14 * pulse) if duel.law_id == DuelBossDesert.LAW_SUN else Color(0.9, 0.72, 0.4, 0.10 + 0.14 * pulse)
	var edge := Color(1.0, 0.6, 0.2, 0.9) if duel.law_id == DuelBossDesert.LAW_SUN else Color(0.95, 0.8, 0.5, 0.9)
	for pos in duel.telegraph_tiles:
		var rect := Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
		draw_rect(rect, fill)
		PixelRenderer.draw_pixel_corners(self, rect, edge, 8.0, 2.0)

func _draw_fire_tiles(board: Board, board_offset: Vector2, cell_size: float) -> void:
	if _fire_tex == null and ResourceLoader.exists(FIRE_SHEET):
		_fire_tex = load(FIRE_SHEET)
	var t = Time.get_ticks_msec() / 1000.0
	for pos in board.fire_tiles.keys():
		var rect = Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size)
		# Brasa escura sob as chamas: a casa fica avermelhada e legível.
		draw_rect(rect, Color(0.45, 0.1, 0.08, 0.5 + 0.06 * sin(t * 6.0 + pos.x + pos.y)))
		if _fire_tex != null:
			var f: int = (int(t * FIRE_FPS) + pos.x * 3 + pos.y * 5) % FIRE_FRAMES
			var src := Rect2(f * FIRE_FRAME_PX, 0, FIRE_FRAME_PX, FIRE_FRAME_PX)
			draw_texture_rect_region(_fire_tex, rect, src)
		PixelRenderer.draw_pixel_corners(self, rect, Color(1.0, 0.55, 0.1, 0.95), 8.0, 2.5)

# Marcas de status na peça: bolha azul = escudo (Lei do Luto); grade violeta = imobilizada (Emboscada);
# selo dourado com número = Dama temporária (Herdeiro, turnos restantes).
func _draw_piece_status(piece: BoardPiece, center: Vector2, size: float) -> void:
	if piece.rooted_turns > 0 and host.board != null and host.board.hungry_roots_team != 0:
		_draw_roots_front(piece, center, size)
	elif piece.rooted_turns > 0:
		var half = size * 0.34
		var col = Color(0.62, 0.42, 0.85, 0.95)
		for i in range(3):
			var x = center.x - half + half * i
			draw_line(Vector2(x, center.y - half), Vector2(x, center.y + half), col, 3.0)
		draw_rect(Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), col, false, 3.0)
	if piece.shield_turns > 0:
		# Escudo (Lei do Luto): bolha azul pulsante + contorno ao redor da peça.
		var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
		var rad = size * 0.46
		draw_circle(center, rad, Color(0.35, 0.65, 1.0, 0.16 + 0.1 * pulse))
		draw_arc(center, rad, 0, TAU, 32, Color(0.55, 0.8, 1.0, 0.75 + 0.25 * pulse), 3.0)
		# Selo de escudo no canto inferior esquerdo.
		var sc = center + Vector2(-size * 0.3, size * 0.3)
		var s = size * 0.13
		var shield_pts = PackedVector2Array([sc + Vector2(-s, -s), sc + Vector2(s, -s), sc + Vector2(s, s * 0.2), sc + Vector2(0, s * 1.3), sc + Vector2(-s, s * 0.2)])
		draw_colored_polygon(shield_pts, Color(0.3, 0.6, 0.95))
		draw_polyline(PackedVector2Array([shield_pts[0], shield_pts[1], shield_pts[2], shield_pts[3], shield_pts[4], shield_pts[0]]), Color(0.9, 0.97, 1.0), 2.0)
	if piece.temp_king_turns > 0:
		var badge = center + Vector2(size * 0.3, -size * 0.3)
		draw_circle(badge, size * 0.15, Color(0.14, 0.1, 0.17))
		draw_arc(badge, size * 0.15, 0, TAU, 16, Color(0.85, 0.65, 0.25), 2.0)
		var font = ThemeDB.fallback_font
		# Centraliza de verdade: caixa de largura = diâmetro do círculo, e a
		# linha de base calculada pela altura real da fonte.
		var fs = int(size * 0.2)
		var txt = str(piece.temp_king_turns)
		var r = size * 0.15
		var base_y = badge.y + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0
		draw_string(font, Vector2(badge.x - r, base_y), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1.0, 0.9, 0.5))

# Idade (s) das raízes desta peça: começa a contar na 1ª vez que ela é vista
# enraizada; some do registro quando a peça é liberada.
func _roots_age(piece: BoardPiece) -> float:
	var id: int = piece.get_instance_id()
	if piece.rooted_turns <= 0 or host.board == null or host.board.hungry_roots_team == 0:
		_root_t0.erase(id)
		return -1.0
	if not _root_t0.has(id):
		_root_t0[id] = Time.get_ticks_msec()
	return float(Time.get_ticks_msec() - int(_root_t0[id])) / 1000.0

# Camada de TRÁS (desenhada antes da peça): raízes cruzadas na base.
func _draw_roots_back(piece: BoardPiece, center: Vector2, size: float) -> void:
	var age: float = _roots_age(piece)
	if age < ROOT_GROW_SECS:
		return
	var tex: Texture2D = _fx("raizes_tras")
	if tex != null:
		draw_texture_rect(tex, _sprite_rect(center, size), false)

# Camada da FRENTE (depois da peça): crescendo (spritesheet) e depois as garras.
func _draw_roots_front(piece: BoardPiece, center: Vector2, size: float) -> void:
	var age: float = _roots_age(piece)
	var grow: Texture2D = _fx("raizes_sheet")
	var front: Texture2D = _fx("raizes_frente")
	if grow == null or front == null or _fx("raizes_tras") == null:
		_draw_roots(center, size)
		return
	var rect: Rect2 = _sprite_rect(center, size)
	if age < ROOT_GROW_SECS:
		var f: int = clampi(int(age / (ROOT_GROW_SECS / 4.0)), 0, 3)
		draw_texture_rect_region(grow, rect, Rect2(f * 32, 0, 32, 32))
	else:
		draw_texture_rect(front, rect, false)

# Reserva procedural (sem os sprites): raízes saindo da base da peça (peça presa por 1 turno).
func _draw_roots(center: Vector2, size: float) -> void:
	var brown := Color(0.36, 0.22, 0.1, 0.95)
	var green := Color(0.4, 0.8, 0.3, 0.95)
	var base_y: float = center.y + size * 0.26
	for i in range(-2, 3):
		var a := Vector2(center.x + i * size * 0.08, base_y)
		var mid := Vector2(center.x + i * size * 0.15, base_y + size * (0.10 + 0.02 * absi(i)))
		var b := Vector2(center.x + i * size * 0.2 + (size * 0.05 if i % 2 == 0 else -size * 0.04), base_y + size * 0.19)
		draw_polyline(PackedVector2Array([a, mid, b]), brown, 3.0)
		draw_rect(Rect2(b - Vector2(2, 2), Vector2(4, 4)), green)
	draw_arc(center, size * 0.4, PI * 0.15, PI * 0.85, 10, Color(0.4, 0.8, 0.3, 0.55), 2.0)

# Leis do Chefe que vivem nas casas CLARAS: Cipós e Vaga-lumes.
func _draw_light_tile_laws(board: Board, board_offset: Vector2, cell_size: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for pos in board.vine_tiles.keys():
		_draw_vine(Rect2(board_offset.x + pos.x * cell_size, board_offset.y + pos.y * cell_size, cell_size, cell_size), t, pos)
	_draw_lit_tiles(board, board_offset, cell_size, t)
	if board.firefly_tiles.is_empty():
		return
	var duel = host.current_duel
	var now_ms: int = Time.get_ticks_msec()
	# Zona protegida: as 4 casas de lado de cada vaga-lume brilham de leve.
	for pos in board.firefly_tiles.keys():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = pos + d
			if q.x < 0 or q.y < 0 or q.x >= board.cols or q.y >= board.rows:
				continue
			var qr := Rect2(board_offset.x + q.x * cell_size, board_offset.y + q.y * cell_size, cell_size, cell_size)
			draw_rect(qr, Color(0.95, 1.0, 0.5, 0.10 + 0.04 * sin(t * 3.0 + q.x + q.y)))
			PixelRenderer.draw_pixel_corners(self, qr, Color(0.95, 1.0, 0.55, 0.55), 6.0, 2.0)
	for pos in board.firefly_tiles.keys():
		var center := board_offset + Vector2(pos.x * cell_size + cell_size / 2.0, pos.y * cell_size + cell_size / 2.0)
		# Desliza da casa anterior se acabou de se mover.
		if duel is DuelBoss:
			for fm in duel.firefly_moves:
				if fm["to"] == pos:
					var k: float = clampf(float(now_ms - int(fm["t0"])) / float(DuelBoss.FIREFLY_ANIM_MS), 0.0, 1.0)
					if k < 1.0:
						var from_c := board_offset + Vector2(fm["from"].x * cell_size + cell_size / 2.0, fm["from"].y * cell_size + cell_size / 2.0)
						center = from_c.lerp(center, k * k * (3.0 - 2.0 * k))
		_draw_firefly(center, cell_size, t, pos)
	# Próximo passo (marcado): linha pontilhada + anel na casa de destino.
	if duel is DuelBoss:
		for from_p in duel.firefly_plan.keys():
			var to_p: Vector2i = duel.firefly_plan[from_p]
			if to_p == from_p or not board.firefly_tiles.has(from_p):
				continue
			var a := board_offset + Vector2(from_p.x * cell_size + cell_size / 2.0, from_p.y * cell_size + cell_size / 2.0)
			var b := board_offset + Vector2(to_p.x * cell_size + cell_size / 2.0, to_p.y * cell_size + cell_size / 2.0)
			draw_dashed_line(a, b, Color(0.95, 1.0, 0.5, 0.45), 2.0, 6.0)
			var ptex: Texture2D = _fx("vagalume_proximo")
			if ptex != null:
				draw_texture_rect(ptex, _sprite_rect(b, cell_size), false)
			else:
				draw_arc(b, cell_size * 0.14 + 1.5 * sin(t * 4.0), 0, TAU, 14, Color(0.95, 1.0, 0.5, 0.6), 2.0)

# Casas acesas pela carta Acender Casa: luz quente fixa + brilho nas 4 casas de
# lado (só as do time protegido, que são as que de fato ficam a salvo).
func _draw_lit_tiles(board: Board, board_offset: Vector2, cell_size: float, t: float) -> void:
	for pos in board.lit_tiles.keys():
		var info: Dictionary = board.lit_tiles[pos]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = pos + d
			if q.x < 0 or q.y < 0 or q.x >= board.cols or q.y >= board.rows:
				continue
			var occ: BoardPiece = board.grid[q.y][q.x]
			if occ == Board.EMPTY or occ.owner_team != info["team"]:
				continue
			var qr := Rect2(board_offset.x + q.x * cell_size, board_offset.y + q.y * cell_size, cell_size, cell_size)
			draw_rect(qr, Color(1.0, 0.88, 0.4, 0.12 + 0.04 * sin(t * 3.0 + q.x + q.y)))
			PixelRenderer.draw_pixel_corners(self, qr, Color(1.0, 0.9, 0.45, 0.6), 6.0, 2.0)
		var center := board_offset + Vector2(pos.x * cell_size + cell_size / 2.0, pos.y * cell_size + cell_size / 2.0)
		draw_circle(center, cell_size * 0.40, Color(1.0, 0.85, 0.35, 0.10 + 0.04 * sin(t * 2.5 + pos.x)))
		_draw_firefly(center, cell_size, t, pos)
		# Pontinhos = turnos restantes.
		var u: float = maxf(2.0, floorf(cell_size / 16.0))
		for i in range(int(info["turns"])):
			draw_rect(Rect2((center + Vector2((i - (int(info["turns"]) - 1) / 2.0) * u * 2.5 - u / 2.0, cell_size * 0.36)).floor(), Vector2(u, u)), Color(1.0, 0.92, 0.5))

func _draw_firefly(center: Vector2, cell: float, t: float, pos: Vector2i) -> void:
	var ftex: Texture2D = _fx("vagalume_sheet")
	if ftex != null:
		var fph: float = t * 2.4 + pos.x * 1.7 + pos.y * 2.3
		var fc := center + Vector2(sin(fph) * 0.05, cos(fph * 1.3) * 0.05) * cell
		var ff: int = (int(t * 8.0) + pos.x * 2) % 6
		draw_texture_rect_region(ftex, _sprite_rect(fc, cell), Rect2(ff * 32, 0, 32, 32))
		return
	var ph: float = t * 2.4 + pos.x * 1.7 + pos.y * 2.3
	var c := center + Vector2(sin(ph) * 0.05, cos(ph * 1.3) * 0.05) * cell
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0 + pos.x * 2.0)
	draw_circle(c, cell * 0.34, Color(0.85, 1.0, 0.4, 0.07 + 0.04 * pulse))
	draw_circle(c, cell * 0.22, Color(0.9, 1.0, 0.45, 0.14 + 0.06 * pulse))
	draw_circle(c, cell * 0.11, Color(1.0, 1.0, 0.65, 0.5 + 0.2 * pulse))
	var u: float = maxf(2.0, floorf(cell / 16.0))
	draw_rect(Rect2((c - Vector2(u, u)).floor(), Vector2(u * 2.0, u * 2.0)), Color(1.0, 1.0, 0.85))
	for i in range(3):
		var a: float = t * 1.6 + i * TAU / 3.0 + pos.x
		var sp := c + Vector2(cos(a), sin(a * 1.2)) * cell * 0.28
		draw_rect(Rect2(sp.floor(), Vector2(u, u)), Color(1.0, 1.0, 0.6, 0.55))

# Cipó: cruz de trepadeira (horizontal + vertical) com folhas e uma florzinha,
# em blocos de pixel pra combinar com o resto do tabuleiro.
func _draw_vine(rect: Rect2, t: float, pos: Vector2i) -> void:
	var vtex: Texture2D = _fx("cipo_sheet")
	if vtex != null:
		var vf: int = (int(t * 4.0) + pos.x * 3 + pos.y) % 4
		draw_texture_rect_region(vtex, _sprite_rect(rect.get_center(), rect.size.x), Rect2(vf * 32, 0, 32, 32))
		return
	var u: float = maxf(2.0, floorf(rect.size.x / 16.0))
	var o: Vector2 = rect.position
	var n: int = int(rect.size.x / u)
	var dark := Color(0.12, 0.38, 0.14)
	var mid := Color(0.24, 0.6, 0.2)
	var leaf := Color(0.5, 0.86, 0.3)
	draw_rect(Rect2(o + Vector2(u, u), rect.size - Vector2(u * 2.0, u * 2.0)), Color(0.05, 0.2, 0.08, 0.18))
	var sway: float = sin(t * 1.8 + pos.x + pos.y * 1.3)
	for i in range(n):
		var wob: float = round(sin(i * 0.9 + t * 1.2) * 0.8 + sway * 0.4)
		var col: Color = dark if i % 2 == 0 else mid
		# horizontal
		draw_rect(Rect2(o + Vector2(i * u, rect.size.y / 2.0 - u + wob * u), Vector2(u, u * 2.0)), col)
		# vertical
		draw_rect(Rect2(o + Vector2(rect.size.x / 2.0 - u + wob * u, i * u), Vector2(u * 2.0, u)), col)
	for k in range(4):
		var f: float = (k + 0.5) / 4.0
		draw_rect(Rect2(o + Vector2(rect.size.x * f, rect.size.y / 2.0 - u * 3.0), Vector2(u * 2.0, u * 2.0)), leaf)
		draw_rect(Rect2(o + Vector2(rect.size.x / 2.0 + u * 1.5, rect.size.y * f), Vector2(u * 2.0, u * 2.0)), leaf)
	var cc: Vector2 = o + rect.size / 2.0
	draw_rect(Rect2(cc - Vector2(u * 2.0, u * 2.0), Vector2(u * 4.0, u * 4.0)), dark)
	draw_rect(Rect2(cc - Vector2(u, u), Vector2(u * 2.0, u * 2.0)), Color(0.96, 0.55, 0.72))

# Escuridão da Noite da Coruja (sobre peças já desenhadas, com as peças do
# chefe encobertas pela névoa) + texto de status acima do tabuleiro.
func _draw_night_and_status(board: Board, board_offset: Vector2, cell_size: float) -> void:
	if host.current_duel == null:
		return
	var dark: float = host.current_duel.get_darkness()
	var area = Rect2(board_offset, Vector2(board.cols * cell_size, board.rows * cell_size))
	if dark > 0.0:
		draw_rect(area, Color(0.04, 0.05, 0.16, dark))
		# Névoa: cobre TODA casa distante das suas peças por igual (vazia ou
		# não), com bruma que se move — não dá pra deduzir onde há peças.
		var t = Time.get_ticks_msec() / 1000.0
		for r in range(board.rows):
			for c in range(board.cols):
				var f: float = host.current_duel.fog_strength(Vector2i(c, r))
				if f <= 0.0:
					continue
				var fr = Rect2(board_offset.x + c * cell_size, board_offset.y + r * cell_size, cell_size, cell_size)
				draw_rect(fr, Color(0.42, 0.48, 0.66, f * 0.6))
				for k in range(2):
					var ph = t * 0.3 + (c * 1.7 + r * 2.3) + k * 3.1
					var off = Vector2(sin(ph) * 0.25, cos(ph * 0.8) * 0.2) * cell_size
					var sz = Vector2.ONE * cell_size * (1.7 + 0.4 * k)
					var br = Rect2(fr.get_center() + off - sz / 2.0, sz)
					var clipped = br.intersection(area) # a bruma não vaza pra moldura
					if clipped.size.x > 0.0 and clipped.size.y > 0.0:
						var src = Rect2((clipped.position - br.position) / sz * 128.0, clipped.size / sz * 128.0)
						draw_texture_rect_region(_get_mist_tex(), clipped, src, Color(0.8, 0.85, 1.0, f * 0.55))
	var status: String = host.current_duel.get_status_text()
	if status != "":
		var font = ThemeDB.fallback_font
		var pos = board_offset + Vector2(0, -12)
		draw_string(font, pos + Vector2(2, 2), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.8))
		draw_string(font, pos, status, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.82, 1.0) if dark > 0.0 else Color(1.0, 0.9, 0.5))

# Bolha de bruma com borda suave (gradiente radial, criado uma vez).
func _get_mist_tex() -> GradientTexture2D:
	if _mist_tex == null:
		var g = Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_mist_tex = GradientTexture2D.new()
		_mist_tex.gradient = g
		_mist_tex.fill = GradientTexture2D.FILL_RADIAL
		_mist_tex.fill_from = Vector2(0.5, 0.5)
		_mist_tex.fill_to = Vector2(1.0, 0.5)
		_mist_tex.width = 128
		_mist_tex.height = 128
	return _mist_tex
