class_name MineWalls
extends Node2D

# Paredes de rocha DENTRO das cavernas da Mina dos Cristais: dois pilares
# recortados de cada lado de uma área coberta (como a entrada de uma gruta),
# com cristais brilhando na rocha. Ficam no mapa mesmo depois da cobertura
# se desfazer. A rocha é uma textura 96x96 ladrilhável gerada por código.

const UNIT: int = 3
const CRYSTAL_DIR := "res://assets/sprites/biomas/mina/tabuleiro/cristais/"
const CRYSTALS: Array[String] = [
	"cristal_1_violeta_alto_escura", "cristal_2_violeta_largo_escura", "cristal_3_gelo_pequeno_escura",
	"cristal_4_gelo_alto_escura", "cristal_5_esmeralda_escura", "cristal_6_misto_escura",
]
const GLOW_COLORS: Array[Color] = [
	Color(0.56, 0.42, 0.82), Color(0.56, 0.42, 0.82), Color(0.66, 0.86, 0.94),
	Color(0.66, 0.86, 0.94), Color(0.25, 0.7, 0.5), Color(0.75, 0.55, 0.9),
]

static var _rock_cache: ImageTexture = null
static var _glow_cache: ImageTexture = null

var _rng := RandomNumberGenerator.new()
var _rock: ImageTexture
var _glow: ImageTexture

# `half_w`/`half_h`: meia-largura e meia-altura da área coberta (px de tela).
func build(seed_value: int, half_w: float, half_h: float) -> void:
	_rng.seed = seed_value
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if _rock_cache == null:
		_rng.seed = 424242
		_rock_cache = _make_rock_texture()
		_glow_cache = _make_glow_texture()
		_rng.seed = seed_value
	_rock = _rock_cache
	_glow = _glow_cache
	for side in [-1.0, 1.0]:
		var w: float = float(_rng.randi_range(32, 42) * UNIT)
		var h: float = half_h * _rng.randf_range(1.25, 1.6)
		var cx: float = side * (half_w * 0.98 + w * 0.35)
		var cy: float = _rng.randf_range(-half_h * 0.25, half_h * 0.2)
		_pillar(Vector2(cx, cy), w, h, side)

func _pillar(c: Vector2, w: float, h: float, side: float) -> void:
	# Contorno: lado de fora reto e irregular, lado de dentro (voltado à gruta) mais recortado.
	var pts_r := PackedVector2Array()   # lado direito, de cima para baixo
	var pts_l := PackedVector2Array()
	var y: float = c.y - h / 2.0
	var y_end: float = c.y + h / 2.0
	var taper: float = 0.0
	while y < y_end:
		var step: float = float(_rng.randi_range(4, 9) * UNIT)
		var t: float = (y - (c.y - h / 2.0)) / h
		var shrink: float = pow(absf(t - 0.5) * 2.0, 3.0) * w * 0.45   # afina nas pontas
		var wl: float = w / 2.0 - shrink + float(_rng.randi_range(-3, 3) * UNIT)
		var wr: float = w / 2.0 - shrink + float(_rng.randi_range(-3, 3) * UNIT)
		wl = maxf(wl, 6.0)
		wr = maxf(wr, 6.0)
		pts_l.append(Vector2(c.x - wl, y))
		pts_l.append(Vector2(c.x - wl, minf(y + step, y_end)))
		pts_r.append(Vector2(c.x + wr, y))
		pts_r.append(Vector2(c.x + wr, minf(y + step, y_end)))
		y += step
	var poly := PackedVector2Array()
	poly.append_array(pts_l)
	var rr := pts_r.duplicate()
	rr.reverse()
	poly.append_array(rr)
	_add_poly(poly, Color(1.35, 1.25, 1.5))
	var closed := poly.duplicate()
	closed.append(poly[0])
	_add_outline(closed)
	# Cristais nascendo do lado voltado para a gruta e incrustados na rocha.
	var inner: PackedVector2Array = pts_r if side < 0.0 else pts_l
	var yy: float = c.y - h / 2.0 + 60.0
	while yy < y_end - 40.0:
		var idx: int = _rng.randi() % CRYSTALS.size()
		var tex := load(CRYSTAL_DIR + CRYSTALS[idx] + ".png") as Texture2D
		if tex != null:
			var on_edge: bool = _rng.randf() < 0.55
			var ex: float = _edge_x_near(inner, yy)
			var pos: Vector2
			var sc: float
			if on_edge:
				pos = Vector2(ex - side * 6.0, yy)
				sc = float(UNIT) * _rng.randf_range(1.0, 1.4)
			else:
				pos = Vector2(c.x + _rng.randf_range(-w * 0.2, w * 0.2), yy)
				sc = float(UNIT) * _rng.randf_range(0.9, 1.3)
			_place_crystal(tex, pos, sc, GLOW_COLORS[idx], -side if on_edge else 0.0, on_edge)
		yy += _rng.randf_range(90.0, 170.0)

func _edge_x_near(edge: PackedVector2Array, y: float) -> float:
	var best: float = edge[0].x
	var bd: float = 1e9
	for p in edge:
		var d: float = absf(p.y - y)
		if d < bd:
			bd = d
			best = p.x
	return best

func _add_poly(points: PackedVector2Array, tint: Color) -> void:
	var pg := Polygon2D.new()
	pg.polygon = points
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append(p / float(UNIT))
	pg.uv = uvs
	pg.texture = _rock
	pg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	pg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pg.color = tint
	add_child(pg)

func _add_outline(points: PackedVector2Array) -> void:
	var dark := Line2D.new()
	dark.points = points
	dark.width = 9.0
	dark.default_color = Color("#14101b")
	dark.joint_mode = Line2D.LINE_JOINT_SHARP
	add_child(dark)
	var lit := Line2D.new()
	var shifted := PackedVector2Array()
	for p in points:
		shifted.append(p)
	lit.points = shifted
	lit.width = 3.0
	lit.default_color = Color(0.55, 0.45, 0.72, 0.55)
	add_child(lit)

func _place_crystal(tex: Texture2D, pos: Vector2, sc: float, glow_col: Color, dir: float, on_edge: bool) -> void:
	var g := Sprite2D.new()
	g.texture = _glow
	g.position = pos
	g.scale = Vector2.ONE * (sc * 2.0)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.modulate = Color(glow_col.r, glow_col.g, glow_col.b, 0.3)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(g)
	var tw := g.create_tween().set_loops()
	tw.tween_interval(_rng.randf() * 2.0)
	tw.tween_property(g, "modulate:a", 0.42, 1.4 + _rng.randf()).set_trans(Tween.TRANS_SINE)
	tw.tween_property(g, "modulate:a", 0.14, 1.4 + _rng.randf()).set_trans(Tween.TRANS_SINE)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.position = pos
	s.scale = Vector2.ONE * sc
	if on_edge:
		s.rotation = dir * _rng.randf_range(0.2, 0.7)
	else:
		s.rotation = _rng.randf_range(-0.5, 0.5)
	s.flip_h = _rng.randf() < 0.5
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)

func _edge_x_at(edge: PackedVector2Array, y: float) -> float:
	for i in range(0, edge.size() - 1, 2):
		if y >= edge[i].y and y <= edge[i + 1].y:
			return edge[i].x
	return edge[edge.size() - 1].x

func _edge_y_at(edge: PackedVector2Array, x: float) -> float:
	for i in range(0, edge.size() - 1, 2):
		if x >= edge[i].x and x <= edge[i + 1].x:
			return edge[i].y
	return edge[edge.size() - 1].y

# Rocha ladrilhável 96x96 (pixels nativos): ruído periódico em 5 tons de ameixa,
# veios claros, rachaduras e minúsculos pontos de cristal.
func _make_rock_texture() -> ImageTexture:
	var n: int = 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var pal: Array[Color] = [Color("#1c1524"), Color("#251c30"), Color("#2f2539"), Color("#3a2d46"), Color("#4a3a5c")]
	var grid_a: Array = []
	var grid_b: Array = []
	for i in range(12 * 12):
		grid_a.append(_rng.randf())
	for i in range(6 * 6):
		grid_b.append(_rng.randf())
	for y in range(n):
		for x in range(n):
			var v: float = _vnoise(grid_a, 12, x / 8.0, y / 8.0) * 0.6 + _vnoise(grid_b, 6, x / 16.0, y / 16.0) * 0.4
			# faixas horizontais suaves (estratos)
			v += 0.08 * sin(float(y) / 96.0 * TAU * 3.0 + _vnoise(grid_b, 6, x / 16.0, 0.0) * 3.0)
			var dither: float = (float((x + y) % 2) - 0.5) * 0.06
			var idx: int = clampi(int((v + dither) * 5.0), 0, 4)
			img.set_pixel(x, y, pal[idx])
	for k in range(14):
		var p := Vector2(_rng.randf() * n, _rng.randf() * n)
		var d := Vector2.from_angle(_rng.randf() * TAU)
		for s in range(_rng.randi_range(8, 22)):
			img.set_pixel(posmod(int(p.x), n), posmod(int(p.y), n), Color("#120c18"))
			d = d.rotated(_rng.randf_range(-0.5, 0.5))
			p += d
	for k in range(22):
		var gc: Color = [Color("#6a5a80"), Color("#8f6bd1"), Color("#a9dcef"), Color("#3f9b79")][_rng.randi() % 4]
		img.set_pixel(_rng.randi() % n, _rng.randi() % n, gc.darkened(0.2))
	return ImageTexture.create_from_image(img)

func _vnoise(grid: Array, size: int, fx: float, fy: float) -> float:
	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a: float = grid[posmod(y0, size) * size + posmod(x0, size)]
	var b: float = grid[posmod(y0, size) * size + posmod(x0 + 1, size)]
	var c: float = grid[posmod(y0 + 1, size) * size + posmod(x0, size)]
	var d: float = grid[posmod(y0 + 1, size) * size + posmod(x0 + 1, size)]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

func _make_glow_texture() -> ImageTexture:
	var n: int = 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var d: float = Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
