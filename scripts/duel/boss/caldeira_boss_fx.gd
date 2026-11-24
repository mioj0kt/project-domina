class_name CaldeiraBossFx
extends RefCounted

# Desenho das leis do chefe da Caldeira no tabuleiro (chamado pelo BoardRenderer).
# Tudo em pixel: casas do bioma (bigorna, crosta) ampliadas inteiras e o resto em
# blocos de `u` px. A lava da Escorrida usa o desenho de lava que já existe
# (board.lava_tiles) e a brasa do Caldeirão usa a casa em brasa (board.ember_tiles).

const DIR := "res://assets/sprites/biomas/caldeira/tabuleiro/casas/"
const C_OUT := Color8(31, 22, 29)
const C_LAVA := Color8(240, 102, 42)
const C_LAVA_HI := Color8(255, 224, 138)
const C_LAVA_DK := Color8(198, 58, 34)
const C_BRONZE := Color8(192, 130, 64)
const C_BRONZE_DK := Color8(138, 84, 40)
const C_IRON := Color8(92, 86, 96)
const C_IRON_DK := Color8(62, 58, 68)
const C_GOLD := Color8(240, 210, 122)
const C_PLATE := Color8(44, 33, 41)

static func tex(path: String) -> Texture2D:
	return MineBossFx.tex(path)

static func unit(cell: float) -> float:
	return maxf(2.0, floorf(cell / 22.0))

static func cell_rect(off: Vector2, cell: float, pos: Vector2i) -> Rect2:
	return Rect2(off.x + pos.x * cell, off.y + pos.y * cell, cell, cell)

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func _duel(host) -> DuelBossCaldeira:
	if host != null and host.current_duel is DuelBossCaldeira:
		return host.current_duel
	return null

static func _px(ci: CanvasItem, p: Vector2, s: Vector2, c: Color) -> void:
	ci.draw_rect(Rect2(p.round(), s.round()), c)

# ---------------------------------------------------------------------------
# Camada de baixo (depois das casas, antes das peças)
# ---------------------------------------------------------------------------
static func draw_under(ci: CanvasItem, host, board: Board, off: Vector2, cell: float) -> void:
	_draw_anvils(ci, board, off, cell)
	_draw_crust(ci, board, off, cell)
	var duel := _duel(host)
	if duel == null:
		return
	match duel.law_id:
		DuelBossCaldeira.LAW_LAVA_FLOW:
			_draw_flow_warning(ci, duel, board, off, cell)
		DuelBossCaldeira.LAW_CAULDRON:
			_draw_cauldron_targets(ci, duel, off, cell)
		DuelBossCaldeira.LAW_HAMMER:
			if duel.hammer_pos.x >= 0:
				_draw_hammer_target(ci, duel.hammer_pos, off, cell)

# Bigorna: casa de METAL (chapa de ferro rebitada). Quente = miolo em brasa
# pulsando, cantos dourados e faíscas; esfriando = ferro cinza com pontinhos de
# quantas rodadas faltam. Usa a arte (casa_bigorna_metal_quente/_fria) quando
# existir; senão desenha a chapa por código.
const ANVIL_HOT := DIR + "casa_bigorna_metal_quente.png"
const ANVIL_COLD := DIR + "casa_bigorna_metal_fria.png"

static func _draw_anvils(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	if board.anvil_tiles.is_empty():
		return
	var t: float = now()
	var u: float = unit(cell)
	for pos in board.anvil_tiles.keys():
		var r: Rect2 = cell_rect(off, cell, pos)
		var cool: int = int(board.anvil_tiles[pos])
		var hot: bool = cool == 0
		var tx: Texture2D = tex(ANVIL_HOT if hot else ANVIL_COLD)
		if tx != null:
			ci.draw_texture_rect(tx, r, false)
		else:
			_draw_metal_plate(ci, r, u, hot, t + pos.x)
		if hot:
			var pulse: float = 0.5 + 0.5 * sin(t * 4.0 + pos.x)
			PixelRenderer.draw_pixel_corners(ci, r.grow(-u * 0.5), Color(C_GOLD, 0.65 + 0.35 * pulse), 9.0, 2.5)
			# faíscas subindo da chapa
			for i in range(3):
				var k: float = fposmod(t * 0.9 + i * 0.33 + pos.x * 0.17, 1.0)
				var sx: float = r.position.x + r.size.x * (0.25 + 0.25 * i) + sin(t * 3.0 + i) * u
				var sy: float = r.end.y - r.size.y * (0.25 + 0.6 * k)
				_px(ci, Vector2(sx, sy), Vector2(u, u), Color(C_LAVA_HI, 1.0 - k))
		else:
			@warning_ignore("integer_division")
			var rounds: int = (cool + 1) / 2
			for i in range(rounds):
				_px(ci, r.position + Vector2(cell * 0.14 + i * u * 2.0, cell * 0.14), Vector2(u, u), Color(0.82, 0.8, 0.86))

# Chapa de ferro por código (provisória até a arte chegar): borda chanfrada,
# rebites nos cantos, face polida no meio; quente, a face fica em brasa.
static func _draw_metal_plate(ci: CanvasItem, r: Rect2, u: float, hot: bool, t: float) -> void:
	var dark := Color8(38, 34, 41)
	var iron := C_IRON_DK
	var iron_hi := C_IRON
	var shine := Color8(150, 142, 152)
	ci.draw_rect(r, dark)
	var inner: Rect2 = r.grow(-u)
	ci.draw_rect(inner, iron)
	# chanfro: luz em cima/esquerda, sombra embaixo/direita
	_px(ci, inner.position, Vector2(inner.size.x, u), iron_hi)
	_px(ci, inner.position, Vector2(u, inner.size.y), iron_hi)
	_px(ci, Vector2(inner.position.x, inner.end.y - u), Vector2(inner.size.x, u), dark.lerp(iron, 0.4))
	_px(ci, Vector2(inner.end.x - u, inner.position.y), Vector2(u, inner.size.y), dark.lerp(iron, 0.4))
	# rebites
	for cx in [inner.position.x + u * 2.0, inner.end.x - u * 3.0]:
		for cy in [inner.position.y + u * 2.0, inner.end.y - u * 3.0]:
			_px(ci, Vector2(cx, cy), Vector2(u, u), shine)
			_px(ci, Vector2(cx + u * 0.5, cy + u * 0.5), Vector2(u * 0.5, u * 0.5), dark)
	# face de bater (polida) no meio
	var face := Rect2(inner.position + inner.size * 0.25, inner.size * 0.5)
	if hot:
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
		ci.draw_rect(face, C_LAVA_DK.lerp(C_LAVA, 0.4 + 0.3 * pulse))
		ci.draw_rect(face.grow(-u), C_LAVA.lerp(C_LAVA_HI, 0.3 + 0.4 * pulse))
	else:
		ci.draw_rect(face, iron_hi)
		_px(ci, face.position, Vector2(face.size.x, u), shine)
	# marcas de martelo
	_px(ci, face.position + Vector2(face.size.x * 0.6, face.size.y * 0.55), Vector2(u * 2.0, u), Color(dark, 0.6))
	_px(ci, face.position + Vector2(face.size.x * 0.2, face.size.y * 0.3), Vector2(u, u), Color(dark, 0.6))

# ---------------------------------------------------------------------------
# Martelada na bigorna (e na Martelada): o martelo desce, bate e volta.
# ---------------------------------------------------------------------------
const HAMMER_SHEET := "res://assets/sprites/biomas/caldeira/tabuleiro/fx/martelo_bigorna.png"
const HAMMER_FRAMES := 6
const STRIKE_SEC := 0.6
const STRIKE_IMPACT := 0.3       # segundos até a face encostar na casa (começo do quadro 3)
static var _strikes: Array = []  # [{"pos": Vector2i, "t0": ms}]

static func strike(pos: Vector2i) -> void:
	_strikes.append({"pos": pos, "t0": Time.get_ticks_msec()})

static func _draw_strikes(ci: CanvasItem, off: Vector2, cell: float) -> void:
	if _strikes.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	var keep: Array = []
	for s in _strikes:
		var k: float = (now_ms - int(s["t0"])) / 1000.0
		if k > STRIKE_SEC:
			continue
		keep.append(s)
		_draw_one_strike(ci, cell_rect(off, cell, s["pos"]), cell, k)
	_strikes = keep

static func _draw_one_strike(ci: CanvasItem, r: Rect2, cell: float, k: float) -> void:
	var sheet: Texture2D = tex(HAMMER_SHEET)
	var u: float = unit(cell)
	var impact: Vector2 = r.get_center() + Vector2(0, cell * 0.08)
	if sheet != null:
		# tira de 6 quadros; o pé de cada quadro (centro de baixo) é o ponto de batida
		var fw: float = sheet.get_width() / float(HAMMER_FRAMES)
		var fh: float = sheet.get_height()
		var f: int = clampi(int(k / STRIKE_SEC * HAMMER_FRAMES), 0, HAMMER_FRAMES - 1)
		var scale: float = maxf(1.0, roundf(cell * 1.15 / fw))
		var size := Vector2(fw, fh) * scale
		var fade: float = clampf((STRIKE_SEC - k) / 0.12, 0.0, 1.0)   # some de leve no fim
		ci.draw_texture_rect_region(sheet, Rect2((impact - Vector2(size.x * 0.5, size.y)).round(), size), Rect2(f * fw, 0, fw, fh), Color(1, 1, 1, fade))
		return
	# provisório por código: martelo girando no cabo (pivô em cima à direita)
	var ang: float
	if k < STRIKE_IMPACT:
		var a: float = k / STRIKE_IMPACT
		ang = lerpf(-1.25, 0.0, a * a)                 # acelera na descida
	else:
		var b: float = (k - STRIKE_IMPACT) / (STRIKE_SEC - STRIKE_IMPACT)
		ang = -0.35 * sin(b * PI) - 0.9 * maxf(0.0, b - 0.5) * 2.0
	var handle_len: float = cell * 0.95
	var pivot: Vector2 = impact + Vector2(handle_len * 0.72, -handle_len * 0.72)
	ci.draw_set_transform(pivot, ang, Vector2.ONE)
	# no espaço do pivô: o cabo vai do pivô até a cabeça (que fica no ponto de batida quando ang = 0)
	var head_c: Vector2 = impact - pivot
	var dir: Vector2 = head_c.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var steps: int = int(handle_len / u)
	for i in range(steps):
		var q: Vector2 = dir * (i * u)
		ci.draw_rect(Rect2(q - Vector2(u, u), Vector2(u * 2.0, u * 2.0)), C_OUT)
		ci.draw_rect(Rect2(q - Vector2(u * 0.5, u * 0.5), Vector2(u, u)), C_BRONZE_DK if i % 3 else C_BRONZE)
	# cabeça (bloco de ferro atravessado no cabo)
	var hw: float = cell * 0.56
	var hh: float = cell * 0.28
	var pts := PackedVector2Array([head_c + perp * hw * 0.5 - dir * hh * 0.5, head_c - perp * hw * 0.5 - dir * hh * 0.5,
		head_c - perp * hw * 0.5 + dir * hh * 0.5, head_c + perp * hw * 0.5 + dir * hh * 0.5])
	ci.draw_colored_polygon(pts, C_OUT)
	var pts2 := PackedVector2Array()
	for p in pts:
		pts2.append(head_c + (p - head_c) * 0.82)
	ci.draw_colored_polygon(pts2, C_IRON)
	ci.draw_line(pts2[0], pts2[1], Color8(150, 142, 152), u)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	# clarão no instante da batida
	if absf(k - STRIKE_IMPACT) < 0.06:
		ci.draw_circle(impact, cell * 0.35, Color(1.0, 0.9, 0.6, 0.55))

# Basalto da Escorrida esfriando: casa de crosta (bloqueada).
static func _draw_crust(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	if board.crust_tiles.is_empty():
		return
	var t: float = now()
	var u: float = unit(cell)
	for pos in board.crust_tiles.keys():
		var r: Rect2 = cell_rect(off, cell, pos)
		var light: bool = (pos.x + pos.y) % 2 == 0
		var tx: Texture2D = tex(DIR + ("casa_crosta_clara.png" if light else "casa_crosta_escura.png"))
		if tx != null:
			ci.draw_texture_rect(tx, r, false)
		else:
			ci.draw_rect(r, Color8(58, 45, 55))
		# rachadinhas ainda acesas, apagando
		var glow: float = 0.35 + 0.25 * sin(t * 2.0 + pos.y)
		_px(ci, r.position + Vector2(cell * 0.3, cell * 0.55), Vector2(u * 3.0, u), Color(C_LAVA, glow))
		_px(ci, r.position + Vector2(cell * 0.55, cell * 0.35), Vector2(u, u * 3.0), Color(C_LAVA_DK, glow))
		PixelRenderer.draw_pixel_corners(ci, r, Color(0.6, 0.45, 0.4, 0.85), 8.0, 2.0)

# Escorrida: a coluna avisada (véu laranja com setas descendo) e, nas línguas que
# já descem, a casa onde a lava chega no fim do turno (pisca vermelho).
static func _draw_flow_warning(ci: CanvasItem, duel: DuelBossCaldeira, board: Board, off: Vector2, cell: float) -> void:
	var t: float = now()
	var u: float = unit(cell)
	if duel.flow_warn_col >= 0:
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
		for r in range(board.rows):
			var rect: Rect2 = cell_rect(off, cell, Vector2i(duel.flow_warn_col, r))
			ci.draw_rect(rect, Color(1.0, 0.45, 0.15, 0.14 + 0.10 * pulse))
			# setas de pixel saindo da fonte (para cima acima dela, para baixo abaixo)
			if r == duel.flow_warn_row:
				continue
			var dir: float = -1.0 if r < duel.flow_warn_row else 1.0
			var k: float = fposmod(t * 1.1 + absf(r - duel.flow_warn_row) * -0.22, 1.0)
			var c: Vector2 = rect.get_center() + Vector2(0, (k - 0.5) * cell * 0.6 * dir)
			for j in range(4):
				for sgn in [-1.0, 1.0]:
					_px(ci, c + Vector2(sgn * j * u - u * 0.5, -j * u * dir), Vector2(u, u), Color(C_LAVA_HI, 0.8 * (1.0 - absf(k - 0.5))))
		var top: Rect2 = cell_rect(off, cell, Vector2i(duel.flow_warn_col, 0))
		PixelRenderer.draw_pixel_corners(ci, Rect2(top.position, Vector2(cell, cell * board.rows)), Color(1.0, 0.6, 0.25, 0.7 + 0.3 * pulse), 12.0, 3.0)
	var fast: float = 0.5 + 0.5 * sin(t * 9.0)
	for p in duel.flow_next_tiles():
		var nr: Rect2 = cell_rect(off, cell, p)
		ci.draw_rect(nr, Color(1.0, 0.25, 0.1, 0.20 + 0.20 * fast))
		PixelRenderer.draw_pixel_corners(ci, nr, Color(1.0, 0.4, 0.2, 0.75 + 0.25 * fast), 9.0, 3.0)

# Caldeirão: as casas onde o respingo vai cair (bolhas de lava pulsando no chão).
static func _draw_cauldron_targets(ci: CanvasItem, duel: DuelBossCaldeira, off: Vector2, cell: float) -> void:
	if duel.cauldron_targets.is_empty():
		return
	var t: float = now()
	var u: float = unit(cell)
	var pulse: float = 0.5 + 0.5 * sin(t * 7.0)
	for p in duel.cauldron_targets:
		var r: Rect2 = cell_rect(off, cell, p)
		ci.draw_rect(r, Color(1.0, 0.4, 0.1, 0.30 + 0.25 * pulse))
		PixelRenderer.draw_pixel_corners(ci, r, Color(C_LAVA_HI, 0.8 + 0.2 * pulse), 12.0, 3.5)
		# alvo de respingo: anel de pixels + gota caindo
		var c: Vector2 = r.get_center()
		var rad: float = cell * (0.22 + 0.06 * pulse)
		for i in range(12):
			var a: float = TAU * i / 12.0
			_px(ci, c + Vector2(cos(a), sin(a) * 0.6) * rad - Vector2(u, u) * 0.5, Vector2(u, u), Color(C_LAVA_HI, 0.95))
		var k: float = fposmod(t * 1.4 + p.x * 0.3, 1.0)
		var dy: float = -cell * 0.45 * (1.0 - k)
		_px(ci, c + Vector2(-u, dy - u * 2.0), Vector2(u * 2.0, u * 3.0), Color(C_LAVA_HI, 0.95))

# Martelada: mira vermelha na casa marcada.
static func _draw_hammer_target(ci: CanvasItem, pos: Vector2i, off: Vector2, cell: float) -> void:
	var t: float = now()
	var u: float = unit(cell)
	var r: Rect2 = cell_rect(off, cell, pos)
	var pulse: float = 0.5 + 0.5 * sin(t * 6.0)
	ci.draw_rect(r, Color(0.9, 0.15, 0.1, 0.16 + 0.14 * pulse))
	var c: Vector2 = r.get_center()
	var rad: float = cell * (0.42 - 0.04 * pulse)
	for i in range(20):
		var a: float = TAU * i / 20.0
		if i % 5 == 0:
			continue
		_px(ci, c + Vector2(cos(a), sin(a)) * rad - Vector2(u, u) * 0.5, Vector2(u, u), Color(1.0, 0.3, 0.2, 0.95))
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		for j in range(3):
			_px(ci, c + d * (rad + u * (1 + j)) - Vector2(u, u) * 0.5, Vector2(u, u), Color(1.0, 0.85, 0.6, 0.95))

# ---------------------------------------------------------------------------
# Camada de cima (depois das peças)
# ---------------------------------------------------------------------------
static func draw_over(ci: CanvasItem, host, board: Board, off: Vector2, cell: float) -> void:
	_draw_strikes(ci, off, cell)
	var duel := _duel(host)
	if duel == null:
		return
	match duel.law_id:
		DuelBossCaldeira.LAW_FOUNDRY:
			_draw_counter(ci, board, off, cell, duel.foundry_count, DuelBossCaldeira.FOUNDRY_NEED,
				"FUNDIÇÃO" if duel.foundry_poured < DuelBossCaldeira.FOUNDRY_MAX else "ESFRIOU", duel.foundry_poured >= DuelBossCaldeira.FOUNDRY_MAX, false)
		DuelBossCaldeira.LAW_CAULDRON:
			_draw_counter(ci, board, off, cell, duel.cauldron, DuelBossCaldeira.CAULDRON_MAX,
				"CALDEIRÃO", false, duel.cauldron_fuse >= 0)
		DuelBossCaldeira.LAW_HAMMER:
			if duel.hammer_pos.x >= 0:
				_draw_hammer_icon(ci, duel.hammer_pos, off, cell)
		DuelBossCaldeira.LAW_CROWN_PRICE:
			if board.crown_price_team != 0:
				var vp: Vector2i = board.crown_price_victim(board.crown_price_team)
				if vp.x >= 0:
					_draw_crown_price_mark(ci, vp, off, cell)

# Contador do lado do chefe (coluna do indicador de vez, logo abaixo do encaixe
# dele): n encaixes que acendem como metal derretido.
static func _draw_counter(ci: CanvasItem, board: Board, off: Vector2, cell: float, n: int, total: int, label: String, cold: bool, alarm: bool) -> void:
	var t: float = now()
	var x: float = off.x + board.cols * cell + 81.0
	var y0: float = off.y + cell * 0.5 + 42.0 + 30.0
	var gap: float = 30.0
	var blink: float = 0.5 + 0.5 * sin(t * 10.0) if alarm else 0.0
	for i in range(total):
		var c := Vector2(x, y0 + i * gap)
		var box := Rect2((c - Vector2(16, 12)).round(), Vector2(32, 24))
		ci.draw_rect(box.grow(3), C_OUT)
		ci.draw_rect(box, C_PLATE)
		if cold:
			ci.draw_rect(box.grow(-4), Color8(70, 62, 68))
		elif i < n:
			ci.draw_rect(box.grow(-4), C_LAVA.lerp(C_LAVA_HI, 0.3 + 0.4 * blink))
			ci.draw_rect(Rect2(box.position + Vector2(4, 4), Vector2(box.size.x - 8, 3)), C_LAVA_HI)
		else:
			ci.draw_rect(box.grow(-4), Color8(58, 45, 55))
	var font: Font = ThemeDB.fallback_font
	var fs: int = 18
	var txt: String = "%s %d/%d" % [label, n, total] if not cold else label
	var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2(x - w / 2.0, y0 + total * gap + 8.0)
	for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		ci.draw_string(font, base + d, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_OUT)
	var tc: Color = Color8(228, 217, 188).lerp(C_LAVA_HI, blink)
	ci.draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)

# Martelada: martelo de pixel pairando sobre a casa marcada, balançando.
static func _draw_hammer_icon(ci: CanvasItem, pos: Vector2i, off: Vector2, cell: float) -> void:
	var t: float = now()
	var u: float = unit(cell)
	var r: Rect2 = cell_rect(off, cell, pos)
	var bob: float = roundf(sin(t * 3.0) * 1.5) * u
	var o: Vector2 = Vector2(r.end.x - u * 7.0, r.position.y - u * 6.0 + bob)
	# cabo
	_px(ci, o + Vector2(u * 2.0, u * 3.0), Vector2(u * 2.0, u * 8.0), C_OUT)
	_px(ci, o + Vector2(u * 2.5, u * 3.0), Vector2(u, u * 7.5), C_BRONZE_DK)
	# cabeça
	_px(ci, o + Vector2(-u, 0), Vector2(u * 8.0, u * 4.0), C_OUT)
	_px(ci, o + Vector2(0, u * 0.5), Vector2(u * 6.0, u * 3.0), C_IRON)
	_px(ci, o + Vector2(0, u * 0.5), Vector2(u * 6.0, u), Color8(150, 142, 152))

# Preço da Coroa: metal derretido escorrendo da peça que vai pagar a próxima coroa
# (a peça comum mais atrasada do jogador). Pinga devagar, em pixels.
static func _draw_crown_price_mark(ci: CanvasItem, pos: Vector2i, off: Vector2, cell: float) -> void:
	var t: float = now()
	var u: float = unit(cell)
	var r: Rect2 = cell_rect(off, cell, pos)
	var c: Vector2 = r.get_center()
	var base_y: float = roundf(c.y + cell * 0.30)
	# brilho quente na base da peça
	var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
	_px(ci, Vector2(roundf(c.x - u * 5.0), base_y - u), Vector2(u * 10.0, u), Color(C_LAVA, 0.55 + 0.3 * pulse))
	_px(ci, Vector2(roundf(c.x - u * 4.0), base_y), Vector2(u * 8.0, u), Color(C_LAVA_DK, 0.8))
	# três gotas pingando em ritmos diferentes
	for i in range(3):
		var gx: float = roundf(c.x + (float(i) - 1.0) * u * 3.0)
		var k: float = fposmod(t * 0.9 + float(i) * 0.37, 1.0)
		var len_: float = roundf(lerpf(1.0, 4.0, minf(1.0, k * 1.6)))
		_px(ci, Vector2(gx, base_y + u), Vector2(u, u * len_), C_LAVA)
		_px(ci, Vector2(gx, base_y + u), Vector2(u, u), C_LAVA_HI)
		if k > 0.62:   # a gota se solta e cai
			var fy: float = roundf(base_y + u * (len_ + 1.0) + (k - 0.62) * u * 14.0)
			_px(ci, Vector2(gx, fy), Vector2(u, u), Color(C_LAVA_HI, 1.0 - (k - 0.62) / 0.38))
