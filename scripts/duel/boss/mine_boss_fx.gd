class_name MineBossFx
extends RefCounted

# Desenho das leis do chefe da Mina no tabuleiro (chamado pelo BoardRenderer e
# pelo PixelRenderer). Tudo em pixel: sprites da mina ampliados em escala
# inteira, e o resto em blocos de `u` px.

const CRYSTALS: Array[String] = [
	"cristal_1_violeta_alto", "cristal_2_violeta_largo", "cristal_3_gelo_pequeno",
	"cristal_4_gelo_alto", "cristal_5_esmeralda", "cristal_6_misto",
]
const CRYSTAL_DIR := "res://assets/sprites/biomas/mina/tabuleiro/cristais/"
const ROCKS: Array[String] = [
	"res://assets/sprites/biomas/mina/tabuleiro/props/prop_3_pilha_pedras.png",
	"res://assets/sprites/biomas/mina/tabuleiro/props/prop_1_pedra_veios.png",
	"res://assets/sprites/biomas/mina/tabuleiro/props/prop_9_pedra_veios_gelo.png",
]
const RAIL_DIAG := "res://assets/sprites/events/cena/trilho_d_esq.png"
const CART := "res://assets/sprites/events/cena/carrinho_vazio.png"

const C_OUT := Color8(20, 16, 26)
const C_GOLD := Color8(224, 184, 74)
const C_GOLD_HI := Color8(248, 228, 150)
const C_GOLD_LO := Color8(168, 118, 38)
const C_SHINE := Color8(255, 250, 230)

static var _tex: Dictionary = {}

static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

static func unit(cell: float) -> float:
	return maxf(2.0, floorf(cell / 22.0))

static func cell_rect(off: Vector2, cell: float, pos: Vector2i) -> Rect2:
	return Rect2(off.x + pos.x * cell, off.y + pos.y * cell, cell, cell)

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---------------------------------------------------------------------------
# Camada de baixo (depois das casas, antes das peças)
# ---------------------------------------------------------------------------
static func draw_under(ci: CanvasItem, host, board: Board, off: Vector2, cell: float) -> void:
	_draw_rails(ci, board, off, cell)
	if host == null or not (host.current_duel is DuelBossMine):
		_draw_nuggets(ci, board, off, cell)
		return
	var duel: DuelBossMine = host.current_duel
	match duel.law_id:
		DuelBossMine.LAW_LANTERN:
			_draw_lantern(ci, duel, board, off, cell)
		DuelBossMine.LAW_CAVE_IN:
			_draw_cracks(ci, duel.telegraph_tiles, off, cell)
	_draw_nuggets(ci, board, off, cell)

# Trilhos: um pedaço de trilho diagonal por casa (as casas escuras da diagonal
# se tocam pelos cantos, então o trilho fica contínuo) e a vagoneta nas pontas.
static func _draw_rails(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	if board.rail_lines.is_empty():
		return
	var rail: Texture2D = tex(RAIL_DIAG)
	var cart: Texture2D = tex(CART)
	var k: float = maxf(1.0, floorf(cell / 26.0))
	for line in board.rail_lines:
		var cells: Array = line["cells"]
		var slash: bool = cells.size() > 1 and (cells[1] - cells[0]).x < 0   # "/" desce para a esquerda
		for p in cells:
			var r: Rect2 = cell_rect(off, cell, p)
			if rail != null:
				var sz: Vector2 = rail.get_size() * k
				var dst := Rect2((r.get_center() - sz / 2.0).round(), sz)
				if slash:
					ci.draw_set_transform(Vector2(dst.position.x + dst.size.x, 0.0), 0.0, Vector2(-1, 1))
					ci.draw_texture_rect(rail, Rect2(Vector2(0.0, dst.position.y), dst.size), false)
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					ci.draw_texture_rect(rail, dst, false)
			else:
				ci.draw_line(r.position, r.end if not slash else Vector2(r.position.x, r.end.y), Color(0.6, 0.55, 0.5), 3.0)
		# vagonetas nas duas pontas (a peça que parar ali fica "dentro" dela)
		for e in [line["a"], line["b"]]:
			var er: Rect2 = cell_rect(off, cell, e)
			if cart != null:
				var ck: float = maxf(1.0, floorf(cell / 36.0))
				var csz: Vector2 = cart.get_size() * ck
				ci.draw_texture_rect(cart, Rect2(Vector2(er.get_center().x - csz.x / 2.0, er.end.y - csz.y - cell * 0.04).round(), csz), false)
			var pulse: float = 0.5 + 0.5 * sin(now() * 3.0 + e.x)
			PixelRenderer.draw_pixel_corners(ci, er, Color(0.95, 0.8, 0.45, 0.55 + 0.35 * pulse), 8.0, 2.0)

# Pepita de ouro em pixel (9x8 blocos), balançando e com um brilho piscando.
static func draw_nugget_icon(ci: CanvasItem, center: Vector2, u: float, alpha: float = 1.0, dim: bool = false) -> void:
	var rows: Array[String] = [
		"..oooo...",
		".oHHgGo..",
		"oHHggggo.",
		"oHggggLoo",
		"oggggLLLo",
		".oggLLLo.",
		"..ooooo..",
	]
	var o := Vector2(center.x - 4.5 * u, center.y - 3.5 * u).round()
	for y in range(rows.size()):
		var line: String = rows[y]
		for x in range(line.length()):
			var ch: String = line[x]
			var col: Color
			match ch:
				"o": continue   # sem contorno: só a pepita
				"H": col = C_GOLD_HI
				"g", "G": col = C_GOLD
				"L": col = C_GOLD_LO
				_: continue
			if dim and ch != "o":
				col = Color8(74, 58, 70)
			col.a *= alpha
			ci.draw_rect(Rect2(o + Vector2(x, y) * u, Vector2(u, u)), col)

static func _draw_nuggets(ci: CanvasItem, board: Board, off: Vector2, cell: float) -> void:
	if board.nugget_tiles.is_empty():
		return
	var u: float = unit(cell)
	var t: float = now()
	for p in board.nugget_tiles.keys():
		var c: Vector2 = cell_rect(off, cell, p).get_center()
		var bob: float = roundf(sin(t * 2.6 + p.x * 1.3 + p.y) * 1.0) * u
		# sombra
		ci.draw_rect(Rect2(Vector2(c.x - 3.0 * u, c.y + 3.0 * u).round(), Vector2(6.0 * u, u)), Color(0, 0, 0, 0.35))
		draw_nugget_icon(ci, c + Vector2(0, bob - u), u)
		# brilho em cruz, de vez em quando
		var tw: float = fposmod(t * 0.7 + float(p.x * 3 + p.y * 7) * 0.13, 1.0)
		if tw < 0.25:
			var s: Vector2 = (c + Vector2(-2.0 * u, -3.0 * u + bob)).round()
			ci.draw_rect(Rect2(s, Vector2(u, u)), C_SHINE)
			if tw < 0.15:
				ci.draw_rect(Rect2(s - Vector2(u, 0), Vector2(u * 3, u)), Color(C_SHINE, 0.7))
				ci.draw_rect(Rect2(s - Vector2(0, u), Vector2(u, u * 3)), Color(C_SHINE, 0.7))

# Lampião: a diagonal da vez fica com um facho morno; no acendimento, clarão.
static func _draw_lantern(ci: CanvasItem, duel: DuelBossMine, board: Board, off: Vector2, cell: float) -> void:
	var t: float = now()
	var soon: bool = duel.lantern_soon()
	var pulse: float = 0.5 + 0.5 * sin(t * (6.0 if soon else 3.2))
	var u: float = unit(cell)
	# a mina fica na penumbra; só o facho do lampião clareia
	for r0 in range(board.rows):
		for c0 in range(board.cols):
			var q := Vector2i(c0, r0)
			if not duel.telegraph_tiles.has(q):
				ci.draw_rect(cell_rect(off, cell, q), Color(0.05, 0.03, 0.08, 0.22))
	# o lampião, pendurado na ponta de cima do facho
	if not duel.telegraph_tiles.is_empty():
		var top: Vector2i = duel.telegraph_tiles[0]
		for q2 in duel.telegraph_tiles:
			if q2.y < top.y:
				top = q2
		# sobe pela diagonal até sair do tabuleiro: o lampião fica na moldura
		var lp: Vector2i = top
		while lp.y >= 0 and lp.x < board.cols:
			lp += Vector2i(1, -1)
		var lc: Vector2 = cell_rect(off, cell, lp).get_center()
		lc = Vector2(clampf(lc.x, off.x - cell * 0.3, off.x + board.cols * cell + cell * 0.3), clampf(lc.y, off.y - cell * 0.32, lc.y))
		var lt: Texture2D = tex("res://assets/sprites/events/cena/lanterna_mina.png")
		ci.draw_circle(lc, cell * (0.42 + 0.05 * pulse), Color(1.0, 0.85, 0.45, 0.16 + 0.10 * pulse))
		if lt != null:
			var lk: float = maxf(1.0, floorf(cell / 30.0))
			var lsz: Vector2 = lt.get_size() * lk
			ci.draw_texture_rect(lt, Rect2((lc - lsz / 2.0 + Vector2(0, sin(t * 1.8) * lk)).round(), lsz), false)
	for p in duel.telegraph_tiles:
		var r: Rect2 = cell_rect(off, cell, p)
		ci.draw_rect(r, Color(1.0, 0.86, 0.45, (0.22 if soon else 0.14) + 0.10 * pulse))
		# raios diagonais de pixel atravessando a casa no sentido do facho
		for i in range(3):
			var f: float = fposmod(t * 0.6 + float(i) / 3.0 + float(p.x) * 0.11, 1.0)
			var q: Vector2 = Vector2(r.end.x - f * r.size.x, r.position.y + f * r.size.y).round()
			ci.draw_rect(Rect2(q, Vector2(u, u)), Color(1.0, 0.95, 0.7, 0.35 * (1.0 - absf(f - 0.5) * 2.0)))
		PixelRenderer.draw_pixel_corners(ci, r, Color(1.0, 0.85, 0.45, 0.45 + 0.4 * pulse), 8.0, 2.0)
	var age: float = (Time.get_ticks_msec() - duel.lantern_flash_t0) / 1000.0
	if age >= 0.0 and age < 0.9:
		var a: float = 1.0 - age / 0.9
		for p in duel.lantern_flash_tiles:
			ci.draw_rect(cell_rect(off, cell, p), Color(1.0, 0.97, 0.8, 0.75 * a))

# Desabamento: rachaduras no chão e poeira caindo do teto nas casas marcadas.
static func _draw_cracks(ci: CanvasItem, tiles: Array, off: Vector2, cell: float) -> void:
	if tiles.is_empty():
		return
	var t: float = now()
	var u: float = unit(cell)
	var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
	for p in tiles:
		var r: Rect2 = cell_rect(off, cell, p)
		ci.draw_rect(r, Color(0.9, 0.35, 0.25, 0.10 + 0.10 * pulse))
		# rachadura em zigue-zague (fixa por casa)
		var sd: int = p.x * 7 + p.y * 13
		var x: float = r.position.x + r.size.x * (0.3 + 0.1 * float(sd % 3))
		var y: float = r.position.y + u * 2.0
		while y < r.end.y - u * 2.0:
			ci.draw_rect(Rect2(Vector2(x, y).round(), Vector2(u, u * 2.0)), Color(0.12, 0.08, 0.1, 0.8))
			x += u * float([1, -1, 1, 0][int(y / u + sd) % 4])
			y += u * 2.0
		# poeira e pedrinhas caindo
		for i in range(4):
			var f: float = fposmod(t * 0.9 + float(i) * 0.27 + float(sd) * 0.05, 1.0)
			var dx: float = r.size.x * (0.2 + 0.2 * float((i + sd) % 4))
			ci.draw_rect(Rect2(Vector2(r.position.x + dx, r.position.y + f * r.size.y).round(), Vector2(u, u)),
				Color(0.75, 0.68, 0.72, 0.8 * (1.0 - f)))
		PixelRenderer.draw_pixel_corners(ci, r, Color(1.0, 0.45, 0.35, 0.6 + 0.35 * pulse), 8.0, 2.5)

# ---------------------------------------------------------------------------
# Peças e casas especiais
# ---------------------------------------------------------------------------
static func draw_crystal(ci: CanvasItem, center: Vector2, cell: float, pos: Vector2i) -> void:
	var name: String = CRYSTALS[(pos.x * 5 + pos.y * 3) % CRYSTALS.size()]
	var tx: Texture2D = tex(CRYSTAL_DIR + name + "_escura.png")
	if tx == null:
		ci.draw_rect(Rect2(center - Vector2(cell, cell) * 0.25, Vector2(cell, cell) * 0.5), Color(0.6, 0.45, 0.9))
		return
	var k: float = maxf(1.0, floorf(cell / 34.0))
	var sz: Vector2 = tx.get_size() * k
	var foot := Vector2(center.x, center.y + cell * 0.40)
	ci.draw_texture_rect(tx, Rect2((foot - Vector2(sz.x / 2.0, sz.y)).round(), sz), false)
	# brilho de espelho correndo pelo cristal
	var f: float = fposmod(now() * 0.35 + float(pos.x + pos.y) * 0.2, 1.0)
	if f < 0.18:
		var u: float = k
		var y: float = foot.y - sz.y * (0.2 + f * 3.5)
		ci.draw_rect(Rect2(Vector2(center.x - u, y).round(), Vector2(u * 2.0, u)), Color(1, 1, 1, 0.65))

static func draw_rock(ci: CanvasItem, piece: BoardPiece, center: Vector2, cell: float, scale: float) -> void:
	var tx: Texture2D = tex(ROCKS[piece.get_instance_id() % ROCKS.size()])
	if tx == null:
		ci.draw_circle(center, cell * 0.3 * scale, Color(0.35, 0.28, 0.33))
		return
	var k: float = maxf(1.0, floorf(cell * scale / 24.0))
	var sz: Vector2 = tx.get_size() * k
	var foot := Vector2(center.x, center.y + cell * scale * 0.30)
	ci.draw_rect(Rect2(Vector2(foot.x - sz.x * 0.45, foot.y - k).round(), Vector2(sz.x * 0.9, k * 2.0)), Color(0, 0, 0, 0.3))
	ci.draw_texture_rect(tx, Rect2((foot - Vector2(sz.x / 2.0, sz.y)).round(), sz), false)

# Peça ofuscada pelo lampião: estrelinhas girando em cima e um brilho na peça.
static func draw_dazzle(ci: CanvasItem, center: Vector2, size: float) -> void:
	var t: float = now()
	var u: float = maxf(2.0, floorf(size / 26.0))
	ci.draw_circle(center, size * 0.42, Color(1.0, 0.95, 0.7, 0.28 + 0.10 * sin(t * 6.0)))
	u = maxf(3.0, u * 1.5)
	for i in range(3):
		var a: float = t * 2.4 + TAU * float(i) / 3.0
		var p := Vector2(center.x + cos(a) * size * 0.32, center.y - size * 0.40 + sin(a) * size * 0.09).round()
		var col := Color(1.0, 0.92, 0.55) if i != 1 else Color(1, 1, 1)
		ci.draw_rect(Rect2(p, Vector2(u, u)), col)
		ci.draw_rect(Rect2(p - Vector2(u, 0), Vector2(u * 3.0, u)).grow(-u * 0.0), Color(col, 0.55))
		ci.draw_rect(Rect2(p - Vector2(0, u), Vector2(u, u * 3.0)), Color(col, 0.55))
