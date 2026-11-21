class_name MapChasm
extends Node2D

# Desfiladeiro do Cume Congelado no mapa: uma fenda que corta o tabuleiro de lado a
# lado, na altura de uma fileira inteira de nodos. Cada nodo dessa fileira fica no
# meio de uma PONTE DE CORDA sobre o abismo (a trilha chega por baixo e sai por
# cima). Os duelos dali são travados em cima da ponte (RunManager.current_node_bridge).

const PX: int = 3
const TILE: float = 78.0
const BRIDGE_W: int = 24          # largura da ponte (px nativos)
const HEIGHT: float = 1.5 * TILE   # altura da fenda (passa um quarto de casa para cada lado da fileira)

const C_ROCK := [Color("5a4855"), Color("4a3a46"), Color("3a2d37"), Color("2a2029"), Color("1b141c")]
const C_VOID := Color("0b0812")
const C_SNOW_HI := Color("f4f7fa")
const C_SNOW := Color("dfe8ef")
const C_SNOW_SH := Color("c3d2de")
const C_ICE := Color("a9dcef")
const C_ICE_DK := Color("6fb6d8")
const C_WOOD := [Color("b08452"), Color("8a623c"), Color("6e4e2e")]
const C_ROPE := Color("d9b47a")
const C_OUT := Color("1f161d")

var _x0: float = 0.0
var _x1: float = 0.0
var _bridges: Array[float] = []     # x (local) de cada ponte
var _duel: Array[bool] = []         # a ponte tem duelo (ganha o selo)
var _badges: Array[Sprite2D] = []
var _mist: Array = []               # [x, y (0..1), velocidade, comprimento]
var _t: float = 0.0
var _seed: int = 0

# `rect`: área das casas do tabuleiro (mundo); `y`: centro da fileira; `nodes_x`: x dos nodos.
func setup(rect: Rect2, y: float, nodes_x: Array, duel_flags: Array, seed_value: int) -> void:
	position = Vector2(0.0, y)
	_x0 = rect.position.x
	_x1 = rect.end.x
	_seed = seed_value
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(nodes_x.size()):
		_bridges.append(float(nodes_x[i]))
		_duel.append(bool(duel_flags[i]))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(26):
		_mist.append([rng.randf(), rng.randf_range(0.55, 0.9), rng.randf_range(0.01, 0.035) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randi_range(3, 9)])
	var holder := Node2D.new()
	holder.z_index = 15
	add_child(holder)
	for i in range(_bridges.size()):
		if not _duel[i]:
			continue
		var b := Sprite2D.new()
		b.texture = _badge_texture()
		b.scale = Vector2(PX, PX)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = Vector2(_bridges[i] + 30.0, -30.0)
		b.set_meta("base", b.position)
		holder.add_child(b)
		_badges.append(b)

func _process(delta: float) -> void:
	_t += delta
	for i in range(_badges.size()):
		var base: Vector2 = _badges[i].get_meta("base")
		_badges[i].position = base + Vector2(0, roundf(sin(_t * 2.4 + float(i))) * float(PX))
	queue_redraw()

func _h(a: int, b: int) -> int:
	return absi(hash(Vector3i(a, b, _seed)))

# A parede da fenda é pintada UMA vez numa textura (1 px = 1 px nativo); eram ~13 mil
# retângulos refeitos a cada quadro.
var _wall_tex: ImageTexture = null

func _bake_wall() -> ImageTexture:
	var cols: int = int((_x1 - _x0) / float(PX))
	var rows: int = int(HEIGHT / float(PX))        # 39 px nativos de altura
	var img := Image.create(cols, rows + 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for cx in range(cols):
		var lip_top: int = 2 + _h(int(cx / 4.0), 1) % 3              # neve da borda de cima
		var lip_bot: int = 1 + _h(int(cx / 5.0), 2) % 3              # neve da borda de baixo
		var wob: int = _h(int(cx / 6.0), 3) % 3
		for ry in range(rows):
			var col: Color
			if ry < lip_top:
				col = C_SNOW_HI if ry == 0 else (C_SNOW if ry < lip_top - 1 else C_SNOW_SH)
			elif ry >= rows - lip_bot:
				col = C_SNOW_SH if ry == rows - lip_bot else C_SNOW_HI
			else:
				var d: int = ry - lip_top + wob
				if d < 4:
					col = C_ROCK[0]
				elif d < 9:
					col = C_ROCK[1]
				elif d < 14:
					col = C_ROCK[2]
				elif d < 19:
					col = C_ROCK[3]
				elif d < 23:
					col = C_ROCK[4]
				else:
					col = C_VOID
				# camadas da rocha (faixas horizontais irregulares) e veios verticais
				if d < 22 and (d + _h(int(cx / 9.0), 5) % 3) % 5 == 4:
					col = col.darkened(0.18)
				if d < 22 and _h(cx, 7) % 9 == 0 and (d + _h(cx, 8)) % 5 != 0:
					col = col.darkened(0.25)
				# sombra da borda de baixo
				if ry == rows - lip_bot - 1:
					col = C_OUT
			img.set_pixel(cx, ry, col)
		# sincelos pendurados da borda de cima
		var ih: int = _h(cx, 11) % 17
		if ih < 3:
			for k in range(ih + 2):
				img.set_pixel(cx, lip_top + k, C_ICE)
			img.set_pixel(cx, lip_top + ih + 1, C_ICE_DK)
	return ImageTexture.create_from_image(img)

func _draw() -> void:
	var u: float = float(PX)
	var half: float = HEIGHT / 2.0
	if _wall_tex == null:
		_wall_tex = _bake_wall()
	draw_texture_rect(_wall_tex, Rect2(Vector2(_x0, -half), Vector2(_wall_tex.get_size()) * u), false)
	# névoa no fundo
	for m in _mist:
		var mx: float = _x0 + fposmod(float(m[0]) + _t * float(m[2]), 1.0) * (_x1 - _x0)
		var my: float = -half + float(m[1]) * HEIGHT
		var q := Vector2(floorf(mx / u) * u, floorf(my / u) * u)
		draw_rect(Rect2(q, Vector2(float(m[3]) * u, u)), Color(0.75, 0.82, 0.95, 0.16))
	# pontes
	for bx in _bridges:
		_draw_bridge(bx, u, half)

func _draw_bridge(bx: float, u: float, half: float) -> void:
	var w: float = BRIDGE_W * u
	var x: float = floorf((bx - w / 2.0) / u) * u
	var top: float = -half - 2.0 * u
	var bot: float = half + 2.0 * u
	# sombra da ponte no abismo
	draw_rect(Rect2(Vector2(x + 2.0 * u, top + 6.0 * u), Vector2(w, bot - top - 8.0 * u)), Color(0, 0, 0, 0.35))
	# tábuas (3 px nativos cada, 1 de vão), levemente tortas
	var y: float = top
	var i: int = 0
	while y < bot - u:
		var off: float = float(_h(int(bx), i) % 3 - 1) * u
		var tone: Color = C_WOOD[_h(int(bx) + 3, i) % 2]
		draw_rect(Rect2(Vector2(x + off - u, y), Vector2(w + 2.0 * u, 3.0 * u)), C_OUT)
		draw_rect(Rect2(Vector2(x + off, y), Vector2(w, 2.0 * u)), tone)
		draw_rect(Rect2(Vector2(x + off, y), Vector2(w, u)), tone.lightened(0.12))
		draw_rect(Rect2(Vector2(x + off, y + 2.0 * u), Vector2(w, u)), C_WOOD[2])
		if _h(int(bx) + 9, i) % 4 == 0:
			draw_rect(Rect2(Vector2(x + off + float(_h(i, int(bx)) % 10) * u, y), Vector2(4.0 * u, u)), C_SNOW_HI)
		y += 4.0 * u
		i += 1
	# cordas dos dois lados (com barriga) e estacas nas quatro pontas
	for sx in [-1.0, 1.0]:
		var rx: float = (x - 2.0 * u) if sx < 0.0 else (x + w + u)
		var steps: int = int((bot - top) / u)
		for k in range(steps):
			var s: float = float(k) / float(steps)
			var bulge: float = roundf(sin(s * PI) * 2.0) * u * sx
			var sway: float = roundf(sin(_t * 1.4 + bx * 0.01 + s * 2.0) * 0.6) * u
			draw_rect(Rect2(Vector2(rx + bulge + sway, top + k * u), Vector2(u, u)), C_ROPE if k % 2 == 0 else C_WOOD[1])
		for py in [top - 3.0 * u, bot - 2.0 * u]:
			draw_rect(Rect2(Vector2(rx - u, py - u), Vector2(3.0 * u, 7.0 * u)), C_OUT)
			draw_rect(Rect2(Vector2(rx, py), Vector2(u, 5.0 * u)), C_WOOD[0])
			draw_rect(Rect2(Vector2(rx - u, py - u), Vector2(3.0 * u, u)), C_SNOW_HI)

static var _badge_tex: ImageTexture = null

# Selo 11x11: pontezinha de corda num disco escuro.
static func _badge_texture() -> ImageTexture:
	if _badge_tex != null:
		return _badge_tex
	var rows: Array[String] = [
		"...#####...",
		"..#######..",
		".#########.",
		"#o#######o#",
		"#oo#####oo#",
		"#o#ooooo#o#",
		"#owwwwwwwo#",
		"#o#w#w#w#o#",
		".#########.",
		"..#######..",
		"...#####...",
	]
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(11):
		for x in range(11):
			var ch: String = rows[y][x]
			if ch == "#":
				img.set_pixel(x, y, Color("#2a1d14"))
			elif ch == "o":
				img.set_pixel(x, y, Color("#f0d9a0"))
			elif ch == "w":
				img.set_pixel(x, y, Color("#c08a52"))
	_badge_tex = ImageTexture.create_from_image(img)
	return _badge_tex
