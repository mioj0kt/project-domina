class_name MapGlacier
extends Node2D

# Glaciar de Gelo Fino do Cume Congelado no mapa: uma placa de gelo que troca as
# casas em volta de 1 a 3 duelos por casas de gelo. Quando a peça chega num duelo
# do glaciar, as rachaduras se espalham a partir dele e ficam lá. O duelo travado
# ali é o de GELO FINO (RunManager.current_node_glacier).

const PX: int = 3
const TILE: float = 78.0
const DIR := "res://assets/sprites/biomas/cume/tabuleiro/casas/"
const CRACK_MAX: float = 2.7          # raio (em casas) das rachaduras em volta de um nodo visitado
const CRACK_SPEED: float = 1.6        # casas por segundo

var _cells: Array[Vector2i] = []      # casas do glaciar (grade do mapa)
var _set: Dictionary = {}
var _members: Array[Vector2] = []     # nodos (em casas, fracionário)
var _crack_r: Array[float] = []
var _crack_target: Array[float] = []
var _badges: Array[Sprite2D] = []
var _t: float = 0.0
var _tex: Dictionary = {}
var _fx: Node2D = null
# Fundo do mapa: a placa acompanha os patamares dele (sombra do patamar e a
# beirada de neve desenhada por cima do gelo).
var forest: ForestBackground = null

func setup(cells: Array, member_positions: Array) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for c in cells:
		_cells.append(c)
		_set[c] = true
	for wp in member_positions:
		_members.append(wp / TILE)
		_crack_r.append(0.0)
		_crack_target.append(0.0)
	for n in ["clara", "escura"]:
		_tex[n] = load(DIR + "casa_gelo_%s.png" % n)
		for k in range(1, 4):
			_tex["%s_%d" % [n, k]] = load(DIR + "casa_gelo_%s_rachada_%d.png" % [n, k])
	# brilhos: num nó à parte, para a placa (pesada) só ser redesenhada quando racha
	_fx = Node2D.new()
	_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var holder := Node2D.new()
	holder.z_index = 15
	add_child(holder)
	for wp in member_positions:
		var b := Sprite2D.new()
		b.texture = _badge_texture()
		b.scale = Vector2(PX, PX)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = wp + Vector2(30.0, -30.0)
		b.set_meta("base", b.position)
		holder.add_child(b)
		_badges.append(b)

# O nodo `i` do glaciar já foi pisado? `instant`: sem animação (ao abrir o mapa).
func set_cracked(i: int, on: bool, instant: bool = false) -> void:
	if i < 0 or i >= _crack_target.size():
		return
	_crack_target[i] = CRACK_MAX if on else 0.0
	if instant:
		_crack_r[i] = _crack_target[i]

func _process(delta: float) -> void:
	_t += delta
	var changed := false
	for i in range(_crack_r.size()):
		if _crack_r[i] != _crack_target[i]:
			_crack_r[i] = move_toward(_crack_r[i], _crack_target[i], CRACK_SPEED * delta)
			changed = true
	if changed:
		queue_redraw()
	for i in range(_badges.size()):
		var base: Vector2 = _badges[i].get_meta("base")
		_badges[i].position = base + Vector2(0, roundf(sin(_t * 2.4 + float(i))) * float(PX))
	if _fx != null:
		_fx.queue_redraw()

# 0 = inteira; 1..3 = cada vez mais rachada (perto do nodo pisado).
func _crack_stage(c: Vector2i) -> int:
	var best: int = 0
	for i in range(_members.size()):
		if _crack_r[i] <= 0.05:
			continue
		var d: float = (Vector2(c) - _members[i]).length() + float(absi(hash(c)) % 5) * 0.12
		if d > _crack_r[i]:
			continue
		var st: int = 3 if d < 1.1 else (2 if d < 1.9 else 1)
		best = maxi(best, st)
	return best

func _draw() -> void:
	var u: float = float(PX)
	var half := Vector2(TILE, TILE) / 2.0
	for c in _cells:
		var light: bool = ((c.x + c.y) % 2 + 2) % 2 == 0
		var key: String = "clara" if light else "escura"
		var st: int = _crack_stage(c)
		if st > 0:
			key += "_%d" % st
		var p: Vector2 = Vector2(c) * TILE - half
		draw_texture_rect(_tex[key], Rect2(p, Vector2(TILE, TILE)), false)
		if forest != null:
			var sh: float = forest.terrace_shade(float(c.y) * TILE)
			if sh > 0.005:
				draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.10, 0.07, 0.16, sh))
	# borda da placa: contorno escuro por fora, degrau de gelo claro por dentro e
	# sombra embaixo/à direita (a placa fica um degrau acima do chão)
	var out := Color("1c3550")
	for c in _cells:
		var p2: Vector2 = Vector2(c) * TILE - half
		var up: bool = not _set.has(c + Vector2i(0, -1))
		var lf: bool = not _set.has(c + Vector2i(-1, 0))
		var rt: bool = not _set.has(c + Vector2i(1, 0))
		var dn: bool = not _set.has(c + Vector2i(0, 1))
		if rt:
			draw_rect(Rect2(p2 + Vector2(TILE + u, u * 3.0), Vector2(u * 3.0, TILE)), Color(0.05, 0.04, 0.1, 0.4))
		if dn:
			draw_rect(Rect2(p2 + Vector2(u * 3.0, TILE + u), Vector2(TILE, u * 4.0)), Color(0.05, 0.04, 0.1, 0.4))
		if up:
			draw_rect(Rect2(p2 + Vector2(-u if lf else 0.0, -u), Vector2(TILE + (u if lf else 0.0) + (u if rt else 0.0), u)), out)
			draw_rect(Rect2(p2, Vector2(TILE, u * 2.0)), Color("f4f7fa"))
		if lf:
			draw_rect(Rect2(p2 + Vector2(-u, 0), Vector2(u, TILE + (u if dn else 0.0))), out)
			draw_rect(Rect2(p2, Vector2(u * 2.0, TILE)), Color("e4f6ff"))
		if rt:
			draw_rect(Rect2(p2 + Vector2(TILE, 0), Vector2(u, TILE + (u if dn else 0.0))), out)
			draw_rect(Rect2(p2 + Vector2(TILE - u * 2.0, 0), Vector2(u * 2.0, TILE)), Color("3f7fa6"))
		if dn:
			draw_rect(Rect2(p2 + Vector2(0, TILE), Vector2(TILE, u)), out)
			draw_rect(Rect2(p2 + Vector2(0, TILE - u * 2.0), Vector2(TILE, u * 2.0)), Color("3f7fa6"))
	# o degrau de cada patamar passa por cima do gelo, inteiro
	if forest != null:
		forest.draw_terraces_over(self, _set)

# Brilhos de pixel correndo pela placa (redesenhados a cada quadro: são poucos).
func _draw_fx() -> void:
	var u: float = float(PX)
	var half := Vector2(TILE, TILE) / 2.0
	for c in _cells:
		var hsh: int = absi(hash(c))
		var k: float = fposmod(_t * 0.25 + float(hsh % 100) / 100.0, 1.0)
		if k < 0.12:
			var q: Vector2 = Vector2(c) * TILE - half + Vector2(float(hsh % 17) + 3.0, float(int(hsh / 17.0) % 17) + 3.0) * u
			var a: float = sin(k / 0.12 * PI)
			_fx.draw_rect(Rect2(q, Vector2(u, u)), Color(1, 1, 1, a))
			_fx.draw_rect(Rect2(q + Vector2(-u, 0), Vector2(u * 3.0, u)), Color(1, 1, 1, a * 0.5))
			_fx.draw_rect(Rect2(q + Vector2(0, -u), Vector2(u, u * 3.0)), Color(1, 1, 1, a * 0.5))

static var _badge_tex: ImageTexture = null

# Selo 11x11: rachadura clara num disco azul-escuro.
static func _badge_texture() -> ImageTexture:
	if _badge_tex != null:
		return _badge_tex
	var rows: Array[String] = [
		"...#####...",
		"..###o###..",
		".####o####.",
		"###oo#o####",
		"####o##oo##",
		"###o#o#####",
		"##o##o##o##",
		"####o#oo###",
		".###o#####.",
		"..##o####..",
		"...#####...",
	]
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(11):
		for x in range(11):
			var ch: String = rows[y][x]
			if ch == "#":
				img.set_pixel(x, y, Color("#1c3550"))
			elif ch == "o":
				img.set_pixel(x, y, Color("#e4f6ff"))
	_badge_tex = ImageTexture.create_from_image(img)
	return _badge_tex
