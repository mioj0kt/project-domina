class_name CumeBossFx
extends RefCounted

# Desenho das leis do chefe do Cume no tabuleiro (chamado pelo BoardRenderer).
# Tudo em pixel: sprites do cume ampliados em escala inteira, e o resto em
# blocos de `u` px.

const DIR := "res://assets/sprites/biomas/cume/tabuleiro/"
const ICE_TILE := DIR + "casas/casa_gelo_escura.png"
const ICE_TILE_CRACKED := [DIR + "casas/casa_gelo_escura_rachada_1.png", DIR + "casas/casa_gelo_escura_rachada_2.png"]
const ICE_CUBE := DIR + "gelo/gelo_1_cubo_rachado_escura.png"
# Geada na peça: 3 quadros 32x32 (geada 1/3, geada 2/3, congelada) e a quebra (4 quadros).
const PIECE_FROST := DIR + "gelo/gelo_peca_estagios.png"
const PIECE_SHATTER := DIR + "gelo/gelo_peca_quebra.png"
const SNOW_MOUND := DIR + "props/prop_09_monte_neve.png"
const SNOW_MOUND_WIND := DIR + "props/prop_10_monte_neve_vento.png"

const C_ICE_HI := Color8(228, 246, 255)
const C_ICE := Color8(169, 220, 239)
const C_ICE_DK := Color8(111, 182, 216)
const C_SNOW := Color8(244, 247, 250)
const C_ROPE := Color8(176, 132, 82)
const C_ROPE_DK := Color8(110, 78, 46)
const C_AURORA_A := Color(0.45, 1.0, 0.72)
const C_AURORA_B := Color(0.55, 0.75, 1.0)

static func tex(path: String) -> Texture2D:
	return MineBossFx.tex(path)

static func unit(cell: float) -> float:
	return maxf(2.0, floorf(cell / 22.0))

static func cell_rect(off: Vector2, cell: float, pos: Vector2i) -> Rect2:
	return Rect2(off.x + pos.x * cell, off.y + pos.y * cell, cell, cell)

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func _duel(host) -> DuelBossCume:
	if host != null and host.current_duel is DuelBossCume:
		return host.current_duel
	return null

# ---------------------------------------------------------------------------
# Camada de baixo (depois das casas, antes das peças)
# ---------------------------------------------------------------------------
static func draw_under(ci: CanvasItem, host, board: Board, off: Vector2, cell: float) -> void:
	_draw_ice(ci, board, off, cell)
	_draw_thin_ice(ci, board, off, cell)
	_draw_snow(ci, board, off, cell)
	if host != null and host.current_duel != null and host.current_duel.bridge != null:
		_draw_bridge(ci, host.current_duel.bridge, board, off, cell)
	var duel := _duel(host)
	if duel == null:
		return
	match duel.law_id:
		DuelBossCume.LAW_AVALANCHE:
			for lane in duel.avalanche_lanes:
				_draw_lane(ci, lane, off, cell)
		DuelBossCume.LAW_POLAR:
			_draw_polar(ci, duel, board, off, cell)
		DuelBossCume.LAW_THIN_AIR:
			_draw_thin_air(ci, board, off, cell)

static func _draw_ice(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	if board.ice_tiles.is_empty():
		return
	var t: float = now()
	var u: float = unit(cell)
	for p in board.ice_tiles.keys():
		var r: Rect2 = cell_rect(off, cell, p)
		var path: String = ICE_TILE if (p.x + p.y * 3) % 3 == 0 else ICE_TILE_CRACKED[(p.x + p.y) % 2]
		var tx: Texture2D = tex(path)
		if tx != null:
			ci.draw_texture_rect(tx, r, false)
		else:
			ci.draw_rect(r, Color(C_ICE_DK, 0.85))
		# brilho que corre pela diagonal de vez em quando
		var k: float = fposmod(t * 0.35 + float(p.x * 5 + p.y * 3) * 0.17, 1.0)
		if k < 0.3:
			var s: float = k / 0.3
			var a: Vector2 = r.position + Vector2(r.size.x * s, r.size.y * 0.15)
			for i in range(4):
				var q: Vector2 = (a + Vector2(-i * u, i * u)).round()
				if r.has_point(q):
					ci.draw_rect(Rect2(q, Vector2(u, u)), Color(C_ICE_HI, 0.75 * (1.0 - s)))

# Glaciar de Gelo Fino: o miolo do tabuleiro vira placa de gelo; a casa trincada
# mostra as rachaduras e a casa afundada vira água escura com lascas boiando.
const THIN_LIGHT := DIR + "casas/casa_gelo_clara.png"
const THIN_DARK := DIR + "casas/casa_gelo_escura.png"
const THIN_CRACK := [DIR + "casas/casa_gelo_escura_rachada_1.png", DIR + "casas/casa_gelo_escura_rachada_2.png", DIR + "casas/casa_gelo_escura_rachada_3.png"]
const C_WATER := Color8(18, 34, 58)
const C_WATER_HI := Color8(52, 92, 132)

static func _draw_thin_ice(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	if not board.thin_ice:
		return
	var t: float = now()
	var u: float = unit(cell)
	var light: Texture2D = tex(THIN_LIGHT)
	var dark: Texture2D = tex(THIN_DARK)
	for r in range(1, board.rows - 1):
		for c in range(board.cols):
			var p := Vector2i(c, r)
			var rect: Rect2 = cell_rect(off, cell, p)
			if board.water_tiles.has(p):
				_draw_water(ci, rect, p, t, u)
				continue
			if board.scorched_tiles.has(p) or board.fire_tiles.has(p):
				continue
			var is_dark: bool = (c + r) % 2 == 1
			var tx: Texture2D = dark if is_dark else light
			if board.cracked_tiles.has(p):
				tx = tex(THIN_CRACK[(c * 3 + r * 5) % THIN_CRACK.size()])
			if tx != null:
				ci.draw_texture_rect(tx, rect, false)
			if board.cracked_tiles.has(p):
				# trincada: cantos de aviso piscando devagar (a próxima saída afunda)
				var pulse: float = 0.5 + 0.5 * sin(t * 3.0 + float(c + r))
				PixelRenderer.draw_pixel_corners(ci, rect.grow(-u), Color(1.0, 1.0, 1.0, 0.35 + 0.35 * pulse), 8.0, 2.0)
	# beirada do gelo com as margens firmes (fileiras das pontas)
	var w: float = board.cols * cell
	ci.draw_rect(Rect2(Vector2(off.x, off.y + cell - u), Vector2(w, u)), Color(C_ICE_HI, 0.8))
	ci.draw_rect(Rect2(Vector2(off.x, off.y + (board.rows - 1) * cell), Vector2(w, u)), Color(C_ICE_HI, 0.8))

static func _draw_water(ci: CanvasItem, rect: Rect2, p: Vector2i, t: float, u: float) -> void:
	ci.draw_rect(rect, C_WATER)
	# borda de gelo quebrado (dentes irregulares em volta do buraco)
	var n: int = int(rect.size.x / (u * 2.0))
	for i in range(n):
		var h1: float = float(1 + absi(hash(Vector3i(p.x, p.y, i))) % 3) * u
		var h2: float = float(1 + absi(hash(Vector3i(p.y, i, p.x + 9))) % 3) * u
		var x: float = rect.position.x + i * u * 2.0
		ci.draw_rect(Rect2(Vector2(x, rect.position.y), Vector2(u * 2.0, h1)), C_ICE)
		ci.draw_rect(Rect2(Vector2(x, rect.end.y - h2), Vector2(u * 2.0, h2)), C_ICE_HI)
		var y: float = rect.position.y + i * u * 2.0
		ci.draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(h2, u * 2.0)), C_ICE)
		ci.draw_rect(Rect2(Vector2(rect.end.x - h1, y), Vector2(h1, u * 2.0)), C_ICE_DK)
	# ondinhas andando
	for k in range(3):
		var wy: float = rect.position.y + rect.size.y * (0.3 + 0.2 * k)
		var wx: float = rect.position.x + rect.size.x * (0.22 + 0.1 * fposmod(t * 0.35 + k * 0.37 + p.x * 0.21, 1.0) * 3.0)
		ci.draw_rect(Rect2(Vector2(wx, wy).round(), Vector2(u * (3 + k), u)), Color(C_WATER_HI, 0.8))
	# lasca de gelo boiando
	var bob: float = roundf(sin(t * 1.6 + p.x + p.y)) * u
	var fc: Vector2 = rect.get_center() + Vector2(rect.size.x * 0.12, rect.size.y * 0.12 + bob)
	ci.draw_rect(Rect2((fc - Vector2(u * 2.0, u)).round(), Vector2(u * 4.0, u * 2.0)), C_ICE_HI)
	ci.draw_rect(Rect2((fc + Vector2(-u * 2.0, u)).round(), Vector2(u * 4.0, u)), C_ICE_DK)

# Ponte de corda: corrimãos de corda com estacas dos dois lados do tabuleiro e, no
# lado marcado para o próximo balanço, as colunas acesas com setas para dentro.
static func _draw_bridge(ci: CanvasItem, br: BridgeMod, board: Board, off: Vector2, cell: float) -> void:
	var t: float = now()
	var u: float = unit(cell)
	var h: float = board.rows * cell
	var sway: float = sin(t * 1.3) * u * 1.5
	for sx in [-1, 1]:
		var x0: float = (off.x - cell * 0.98) if sx < 0 else (off.x + board.cols * cell + cell * 0.98)
		# estacas a cada 2 casas e a corda fazendo barriga entre elas
		var posts: int = int(board.rows / 2.0) + 1
		for i in range(posts):
			var y: float = off.y + float(i) * h / float(posts - 1)
			if i < posts - 1:
				var y2: float = off.y + float(i + 1) * h / float(posts - 1)
				var steps: int = maxi(6, int((y2 - y) / u))
				for k in range(steps + 1):
					var s: float = float(k) / steps
					var bx: float = x0 + (sway + u * 3.0 * float(sx)) * 4.0 * s * (1.0 - s)
					var q := Vector2(floorf(bx / u) * u, floorf(lerpf(y, y2, s) / u) * u)
					ci.draw_rect(Rect2(q + Vector2(u * 2.0, 0), Vector2(u, u)), C_ROPE_DK)
					ci.draw_rect(Rect2(q, Vector2(u * 2.0, u)), C_ROPE if k % 2 == 0 else C_ROPE_DK.lerp(C_ROPE, 0.6))
				# cordinhas que seguram as tábuas, da corda até a moldura
				var ym: float = (y + y2) / 2.0
				var xin: float = x0 - float(sx) * cell * 0.3
				for k2 in range(int(cell * 0.3 / u) + 1):
					ci.draw_rect(Rect2(Vector2(floorf((x0 + sway * 0.6 - float(sx) * k2 * u) / u) * u, floorf(ym / u) * u), Vector2(u, u)), C_ROPE_DK)
				ci.draw_rect(Rect2(Vector2(floorf(xin / u) * u, floorf(ym / u) * u - u), Vector2(u, u * 3.0)), C_ROPE_DK)
			var pq := Vector2(floorf(x0 / u) * u, floorf(y / u) * u)
			ci.draw_rect(Rect2(pq - Vector2(u * 2.0, u * 5.0), Vector2(u * 6.0, u * 11.0)), Color8(31, 22, 29))
			ci.draw_rect(Rect2(pq - Vector2(u, u * 4.0), Vector2(u * 4.0, u * 9.0)), Color8(110, 78, 46))
			ci.draw_rect(Rect2(pq - Vector2(u, u * 4.0), Vector2(u, u * 9.0)), Color8(150, 110, 68))
			ci.draw_rect(Rect2(pq - Vector2(u, u * 4.0), Vector2(u * 4.0, u * 2.0)), C_SNOW)
	# lado marcado
	var soon: bool = br.plies_to_gust() <= 2
	var pulse: float = 0.5 + 0.5 * sin(t * (7.0 if soon else 3.5))
	var dx: float = 1.0 if br.side < 0 else -1.0
	for c in br.columns():
		var rect := Rect2(off.x + c * cell, off.y + cell, cell, (board.rows - 2) * cell)
		ci.draw_rect(rect, Color(1.0, 0.72, 0.3, (0.20 if not soon else 0.30) + 0.12 * pulse))
	var cols: Array = br.columns()
	if not cols.is_empty():
		var edge_x: float = off.x if br.side < 0 else off.x + board.cols * cell - u
		ci.draw_rect(Rect2(Vector2(edge_x, off.y + cell), Vector2(u, (board.rows - 2) * cell)), Color(1.0, 0.88, 0.6, 0.55 + 0.35 * pulse))
		# setas de pixel correndo para dentro, uma por fileira
		var span: float = cols.size() * cell
		var x_start: float = off.x if br.side < 0 else off.x + board.cols * cell
		for r in range(1, board.rows - 1):
			var k: float = fposmod(t * (1.4 if soon else 0.7) + float(r) * 0.31, 1.0)
			var cx: float = x_start + dx * k * span
			var cy: float = off.y + (float(r) + 0.5) * cell
			for j in range(4):
				var ox: float = -float(j) * u * dx
				var ac := Color(1.0, 0.95, 0.75, 0.95 * (1.0 - k * 0.7))
				ci.draw_rect(Rect2(Vector2(cx + ox - u, cy - u * float(j) - u * 0.5), Vector2(u * 2.0, u)), ac)
				ci.draw_rect(Rect2(Vector2(cx + ox - u, cy + u * float(j) - u * 0.5), Vector2(u * 2.0, u)), ac)

static func _draw_snow(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	if board.snow_tiles.is_empty():
		return
	var mound: Texture2D = tex(SNOW_MOUND)
	var wind: Texture2D = tex(SNOW_MOUND_WIND)
	var k: float = maxf(1.0, floorf(cell / 20.0))
	for p in board.snow_tiles.keys():
		var r: Rect2 = cell_rect(off, cell, p)
		ci.draw_rect(r, Color(0.86, 0.92, 0.97, 0.78))
		var tx: Texture2D = wind if (p.x + p.y) % 4 == 1 and wind != null else mound
		if tx != null:
			var sz: Vector2 = tx.get_size() * k
			ci.draw_texture_rect(tx, Rect2(Vector2(r.get_center().x - sz.x / 2.0, r.end.y - sz.y - cell * 0.12).round(), sz), false)
		PixelRenderer.draw_pixel_corners(ci, r, Color(0.9, 0.97, 1.0, 0.9), 8.0, 2.0)
		var left: int = int(board.scorched_tiles.get(p, 0))
		if left > 0:
			_draw_pips(ci, Vector2(r.position.x + cell * 0.14, r.position.y + cell * 0.14), left, unit(cell), C_ICE_DK)

static func _draw_pips(ci: CanvasItem, at: Vector2, n: int, u: float, col: Color) -> void:
	for i in range(n):
		ci.draw_rect(Rect2((at + Vector2(i * u * 2.0, 0)).round(), Vector2(u, u)), col)

# Avalanche: a encosta marcada (as casas que vão descer), com setas de pixel
# morro abaixo e um véu branco que pulsa.
static func _draw_lane(ci: CanvasItem, tiles: Array, off: Vector2, cell: float) -> void:
	if tiles.size() < 2:
		return
	var t: float = now()
	var u: float = unit(cell)
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	var d: Vector2 = Vector2(tiles[1] - tiles[0]).normalized()
	for i in range(tiles.size()):
		var r: Rect2 = cell_rect(off, cell, tiles[i])
		ci.draw_rect(r, Color(0.86, 0.94, 1.0, 0.26 + 0.16 * pulse))
		PixelRenderer.draw_pixel_corners(ci, r, Color(0.95, 1.0, 1.0, 0.75 + 0.25 * pulse), 10.0, 3.0)
		# chevron correndo no sentido da descida
		var k: float = fposmod(t * 1.2 + float(i) * 0.25, 1.0)
		var c: Vector2 = r.get_center() + d * (k - 0.5) * cell * 0.6
		var perp := Vector2(-d.y, d.x)
		for j in range(4):
			var back: Vector2 = -d * float(j) * u
			for sgn in [-1.0, 1.0]:
				var q: Vector2 = (c + back + perp * sgn * float(j) * u - Vector2(u, u) * 0.5).round()
				ci.draw_rect(Rect2(q, Vector2(u, u)), Color(1, 1, 1, 0.75 * (1.0 - absf(k - 0.5))))

# Luz Polar: faixa de aurora sobre a fileira acesa (ondulando entre verde e azul)
# e a próxima fileira só contornada.
static func _draw_polar(ci: CanvasItem, duel: DuelBossCume, board: Board, off: Vector2, cell: float) -> void:
	var t: float = now()
	var u: float = unit(cell)
	if duel.polar_row >= 0:
		var y0: float = off.y + duel.polar_row * cell
		var n: int = board.cols * 4
		var w: float = board.cols * cell / float(n)
		for i in range(n):
			var ph: float = float(i) * 0.35 + t * 1.6
			var mix: float = 0.5 + 0.5 * sin(ph)
			var col: Color = C_AURORA_A.lerp(C_AURORA_B, mix)
			var h: float = cell * (0.55 + 0.25 * sin(ph * 0.7 + 1.0))
			var x: float = off.x + i * w
			col.a = 0.20
			ci.draw_rect(Rect2(Vector2(x, y0 + cell - h).round(), Vector2(ceilf(w), h)), col)
			col.a = 0.5
			ci.draw_rect(Rect2(Vector2(x, y0 + cell - h).round(), Vector2(ceilf(w), u)), col)
		var edge := Color(C_AURORA_A, 0.75)
		ci.draw_rect(Rect2(Vector2(off.x, y0 + cell - u), Vector2(board.cols * cell, u)), edge)
	if duel.polar_next_row >= 0 and duel.polar_next_row != duel.polar_row:
		var ny: float = off.y + duel.polar_next_row * cell
		var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
		var c2 := Color(C_AURORA_B, 0.25 + 0.25 * pulse)
		var x2: float = off.x
		while x2 < off.x + board.cols * cell:
			ci.draw_rect(Rect2(Vector2(x2, ny), Vector2(u * 2.0, u)), c2)
			ci.draw_rect(Rect2(Vector2(x2, ny + cell - u), Vector2(u * 2.0, u)), c2)
			x2 += u * 4.0

# Ar Rarefeito: as fileiras do alto com um véu frio e fiapos de vento.
static func _draw_thin_air(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	var t: float = now()
	var u: float = unit(cell)
	var h: float = DuelBossCume.THIN_AIR_ROWS * cell
	ci.draw_rect(Rect2(off, Vector2(board.cols * cell, h)), Color(0.75, 0.88, 1.0, 0.07))
	ci.draw_rect(Rect2(Vector2(off.x, off.y + h - u), Vector2(board.cols * cell, u)), Color(0.8, 0.92, 1.0, 0.35))
	for k in range(6):
		var fx: float = fposmod(float(k) * 0.37 * board.cols * cell + t * cell * 0.9, board.cols * cell)
		var fy: float = off.y + fposmod(float(k) * 0.61, 1.0) * (h - cell * 0.3) + cell * 0.15
		var ln: int = 4 + (k % 3)
		for i in range(ln):
			var x: float = off.x + fposmod(fx + i * u, board.cols * cell)
			ci.draw_rect(Rect2(Vector2(x, fy).round(), Vector2(u, u)), Color(1, 1, 1, 0.22 * (1.0 - float(i) / ln)))

# ---------------------------------------------------------------------------
# Por cima das peças
# ---------------------------------------------------------------------------
static func draw_over(ci: CanvasItem, host, board: Board, off: Vector2, cell: float) -> void:
	_draw_ropes(ci, host, board, off, cell)
	_draw_slide_preview(ci, host, board, off, cell)

# Cordada: corda frouxa entre as duas peças amarradas (com nós nas pontas).
static func _draw_ropes(ci: CanvasItem, host, board: Board, off: Vector2, cell: float) -> void:
	if board.rope_pairs.is_empty():
		return
	var u: float = unit(cell)
	for pair in board.rope_pairs:
		var pa: Vector2i = board.find_piece(pair[0])
		var pb: Vector2i = board.find_piece(pair[1])
		if pa.x < 0 or pb.x < 0:
			continue
		if host != null and (pa == host.moving_piece_tile or pb == host.moving_piece_tile):
			continue
		var a: Vector2 = cell_rect(off, cell, pa).get_center() + Vector2(0, cell * 0.08)
		var b: Vector2 = cell_rect(off, cell, pb).get_center() + Vector2(0, cell * 0.08)
		var dist: float = a.distance_to(b)
		var sag: float = clampf(cell * 1.6 - dist * 0.5, cell * 0.06, cell * 0.35)
		var steps: int = maxi(6, int(dist / u))
		var prev := Vector2.INF
		for i in range(steps + 1):
			var s: float = float(i) / steps
			var p: Vector2 = a.lerp(b, s) + Vector2(0, sag * 4.0 * s * (1.0 - s))
			var q: Vector2 = (p / u).floor() * u
			if q == prev:
				continue
			prev = q
			ci.draw_rect(Rect2(q + Vector2(0, u), Vector2(u, u)), C_ROPE_DK)
			ci.draw_rect(Rect2(q, Vector2(u, u)), C_ROPE if int(i / 2.0) % 2 == 0 else C_ROPE_DK.lerp(C_ROPE, 0.6))
		for e in [a, b]:
			var k: Vector2 = (e / u).floor() * u
			ci.draw_rect(Rect2(k - Vector2(u, u), Vector2(u * 3, u * 3)), C_ROPE_DK)
			ci.draw_rect(Rect2(k - Vector2(0, u), Vector2(u, u)), C_ROPE)

# Gelo Escorregadio: com uma peça selecionada, o passo que pára no gelo mostra
# a seta até a casa onde ela vai escorregar.
static func _draw_slide_preview(ci: CanvasItem, host, board: Board, off: Vector2, cell: float) -> void:
	if board.ice_tiles.is_empty() or host == null or host.valid_moves_for_selected.is_empty():
		return
	var t: float = now()
	var u: float = unit(cell)
	for m in host.valid_moves_for_selected:
		if m.get("is_capture", false):
			continue
		var from: Vector2i = m["from"]
		var to: Vector2i = m["to"]
		if not board.ice_tiles.has(to):
			continue
		var p: BoardPiece = board.grid[from.y][from.x]
		# a peça ainda está na origem: simula sem ela ocupando a casa de destino
		var dest: Vector2i = _slide_dest_for(board, p, from, to)
		if dest.x < 0:
			continue
		var a: Vector2 = cell_rect(off, cell, to).get_center()
		var b: Vector2 = cell_rect(off, cell, dest).get_center()
		var dirv: Vector2 = (b - a).normalized()
		var n: int = int(a.distance_to(b) / (u * 2.0))
		var shift: float = fposmod(t * 3.0, 1.0)
		for i in range(n):
			var q: Vector2 = a + dirv * (float(i) + shift) * u * 2.0
			ci.draw_rect(Rect2((q - Vector2(u, u) * 0.5).round(), Vector2(u, u)), Color(C_ICE_HI, 0.85))
		var dr: Rect2 = cell_rect(off, cell, dest)
		ci.draw_rect(dr, Color(C_ICE, 0.18))
		PixelRenderer.draw_pixel_corners(ci, dr, Color(C_ICE_HI, 0.9), 8.0, 2.0)

static func _slide_dest_for(board: Board, p: BoardPiece, from: Vector2i, to: Vector2i) -> Vector2i:
	if p == Board.EMPTY:
		return Vector2i(-1, -1)
	var d := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var nxt: Vector2i = to + d
	if not board.is_valid_pos(nxt.y, nxt.x) or board.grid[nxt.y][nxt.x] != Board.EMPTY \
			or board.scorched_tiles.has(nxt) or board.fire_tiles.has(nxt):
		return Vector2i(-1, -1)
	if not p.is_king:
		var promo: int = 0 if p.owner_team == board.human_team_color else board.rows - 1
		if nxt.y == promo:
			return Vector2i(-1, -1)
	return nxt

# ---------------------------------------------------------------------------
# Marcas na peça (chamado de _draw_piece_status)
# ---------------------------------------------------------------------------
static func draw_piece_marks(ci: CanvasItem, piece: BoardPiece, center: Vector2, size: float) -> void:
	var u: float = unit(size)
	var frost_tex: Texture2D = tex(PIECE_FROST)
	if (piece.frozen or piece.frost > 0) and frost_tex != null:
		# Mesmo retângulo do sprite da peça (32 px em escala inteira).
		var px: float = 32.0 * maxf(1.0, floorf(size / 32.0))
		var r := Rect2((center - Vector2(px, px) / 2.0).round(), Vector2(px, px))
		var frame: int = 2 if piece.frozen else clampi(piece.frost - 1, 0, 1)
		if piece.frozen:
			# janela do bloco: azul translúcido por cima da peça presa
			ci.draw_circle(center, px * 0.26, Color(0.62, 0.86, 1.0, 0.38))
		ci.draw_texture_rect_region(frost_tex, r, Rect2(frame * 32, 0, 32, 32))
	elif piece.frozen:
		var cube: Texture2D = tex(ICE_CUBE)
		if cube != null:
			var k: float = maxf(1.0, floorf(size / 22.0))
			var sz: Vector2 = cube.get_size() * k
			ci.draw_texture_rect(cube, Rect2((center - sz / 2.0 - Vector2(0, size * 0.04)).round(), sz), false, Color(1, 1, 1, 0.72))
	elif piece.frost > 0:
		for i in range(piece.frost):
			var fc: Vector2 = center + Vector2(-size * 0.22 + i * size * 0.22, -size * 0.30)
			_flake(ci, fc, u, Color(C_ICE_HI, 0.95))
	if piece.polar_shield:
		var t: float = now()
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
		var col: Color = C_AURORA_A.lerp(C_AURORA_B, 0.5 + 0.5 * sin(t * 1.3))
		col.a = 0.55 + 0.35 * pulse
		ci.draw_arc(center, size * 0.43, 0, TAU, 28, col, maxf(2.0, u))
		for i in range(4):
			var ang: float = t * 1.5 + i * TAU / 4.0
			var q: Vector2 = center + Vector2(cos(ang), sin(ang)) * size * 0.43
			ci.draw_rect(Rect2((q - Vector2(u, u)).round(), Vector2(u * 2, u * 2)), Color(1, 1, 1, 0.8))

# Sem fôlego (Ar Rarefeito): baforadas brancas subindo da peça.
static func draw_winded(ci: CanvasItem, center: Vector2, size: float) -> void:
	var t: float = now()
	var u: float = unit(size)
	for i in range(3):
		var k: float = fposmod(t * 0.8 + i / 3.0, 1.0)
		var p: Vector2 = center + Vector2(size * (0.18 + 0.10 * sin(k * 6.0 + i)), -size * (0.2 + 0.45 * k))
		var r: float = (1.0 + 1.5 * k) * u
		var col := Color(1, 1, 1, 0.75 * (1.0 - k))
		ci.draw_rect(Rect2((p - Vector2(r, r * 0.6)).round(), Vector2(r * 2.0, r * 1.2)), col)
	# reticências de cansaço
	for j in range(3):
		var on: bool = int(t * 2.5) % 4 > j
		if on:
			ci.draw_rect(Rect2((center + Vector2(-size * 0.16 + j * u * 2.5, size * 0.28)).round(), Vector2(u, u)), Color(0.85, 0.94, 1.0, 0.9))

static func _flake(ci: CanvasItem, c: Vector2, u: float, col: Color) -> void:
	var o: Vector2 = (c - Vector2(u, u) * 0.5).round()
	ci.draw_rect(Rect2(o, Vector2(u, u)), col)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		ci.draw_rect(Rect2(o + d * u, Vector2(u, u)), Color(col, col.a * 0.7))

# Degelo: o bloco se parte (4 quadros) por cima da peça. Um Sprite2D solto no
# host, que se apaga sozinho no fim.
static func play_shatter(host: Node, center: Vector2, cell: float) -> void:
	var t: Texture2D = tex(PIECE_SHATTER)
	if t == null:
		return
	var spr := Sprite2D.new()
	spr.texture = t
	spr.hframes = 4
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var k: float = maxf(1.0, floorf(cell / 32.0))
	spr.scale = Vector2(k, k)
	spr.position = center.round()
	spr.z_index = 50
	host.add_child(spr)
	var tw := spr.create_tween()
	for f in range(1, 4):
		tw.tween_interval(0.09)
		tw.tween_callback(func(): spr.frame = f)
	tw.tween_property(spr, "modulate:a", 0.0, 0.18)
	tw.tween_callback(spr.queue_free)
