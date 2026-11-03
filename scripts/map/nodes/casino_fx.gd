class_name CasinoFx
extends Control
# Efeitos de "cassino" da Mesa de Apostas, desenhados por código:
#   - letreiro de lâmpadas piscando em volta do painel (acelera quando a moeda gira)
#   - holofote girando atrás da moeda
#   - celebração ao ACERTAR (chuva de moedas, faíscas, feixes, flash dourado,
#     lâmpadas piscando) e ao ERRAR (flash vermelho, lâmpadas se apagando, poeira)
# Tudo é só visual: `mouse_filter = IGNORE`, não interfere nos botões.

const GOLD := Color(1.0, 0.82, 0.25)
const RED := Color(0.95, 0.25, 0.25)
const BULB_GAP: float = 30.0

var frame_target: Control = null     # painel que recebe o letreiro
var spot_target: Control = null      # espaço da moeda (centro do holofote)
var spinning: bool = false           # moeda girando -> mais agitação

var _t: float = 0.0
var _win_t: float = -1.0
var _lose_t: float = -1.0
var _flash: float = 0.0
var _flash_col: Color = GOLD
var _origin: Vector2 = Vector2.ZERO
var _coins: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []

func _vp() -> Vector2:
	return get_viewport_rect().size

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

# origin: onde a moeda caiu (coordenadas globais da tela)
func celebrate(origin: Vector2, won: bool) -> void:
	_origin = origin
	_flash_col = GOLD if won else RED
	_flash = 1.0
	if won:
		_win_t = 0.0
		_lose_t = -1.0
		for i in range(26):
			var ang: float = -PI * 0.5 + randf_range(-1.1, 1.1)
			var spd: float = randf_range(500.0, 950.0)
			_coins.append({"p": origin, "v": Vector2(cos(ang), sin(ang)) * spd, "rot": randf() * TAU,
				"spin": randf_range(-12.0, 12.0), "life": randf_range(1.2, 1.8)})
		for i in range(40):
			var a2: float = randf() * TAU
			var s2: float = randf_range(160.0, 600.0)
			_sparks.append({"p": origin, "v": Vector2(cos(a2), sin(a2)) * s2, "life": randf_range(0.6, 1.3),
				"max": 1.3, "sz": randf_range(6.0, 13.0), "col": GOLD.lightened(randf_range(0.0, 0.5))})
	else:
		_lose_t = 0.0
		_win_t = -1.0
		for i in range(26):
			var a3: float = randf() * TAU
			var s3: float = randf_range(60.0, 260.0)
			_sparks.append({"p": origin + Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0)),
				"v": Vector2(cos(a3) * s3, sin(a3) * s3 * 0.5 + 40.0), "life": randf_range(0.8, 1.5),
				"max": 1.5, "sz": randf_range(5.0, 9.0), "col": Color(0.5, 0.45, 0.5).lerp(RED, randf() * 0.5)})

func _process(delta: float) -> void:
	_t += delta
	if _win_t >= 0.0:
		_win_t += delta
		if _win_t > 2.2:
			_win_t = -1.0
	if _lose_t >= 0.0:
		_lose_t += delta
		if _lose_t > 1.6:
			_lose_t = -1.0
	_flash = maxf(0.0, _flash - delta * 1.8)
	for c in _coins:
		c["v"].y += 1500.0 * delta
		c["p"] += c["v"] * delta
		c["rot"] += c["spin"] * delta
		c["life"] -= delta
	_coins = _coins.filter(func(c): return c["life"] > 0.0 and c["p"].y < _vp().y + 60.0)
	for s in _sparks:
		s["p"] += s["v"] * delta
		s["v"] *= (1.0 - 1.5 * delta)
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()

func _draw() -> void:
	var inv: Transform2D = get_global_transform().affine_inverse()
	if spot_target != null and is_instance_valid(spot_target) and spot_target.is_inside_tree():
		var c: Vector2 = inv * (spot_target.get_global_rect().get_center() + Vector2(0.0, 10.0))
		_draw_spot(c)
	if frame_target != null and is_instance_valid(frame_target) and frame_target.is_inside_tree():
		var gr: Rect2 = frame_target.get_global_rect()
		_draw_marquee(Rect2(inv * gr.position, gr.size))
	var o: Vector2 = inv * _origin
	if _win_t >= 0.0:
		_draw_burst_beams(o)
	for co in _coins:
		_draw_coin(co)
	for s in _sparks:
		var a: float = clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
		_draw_star(s["p"], float(s["sz"]) * (0.5 + 0.5 * a), Color(s["col"], a))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _vp()), Color(_flash_col, _flash * (0.28 if _flash_col == GOLD else 0.32)))

# --- holofote atrás da moeda ---
func _draw_spot(c: Vector2) -> void:
	var k: float = 0.5 if not spinning else 1.0
	if _win_t >= 0.0:
		k = 1.6
	var n: int = 7
	var rot: float = _t * (0.5 if not spinning else 1.6)
	var L: float = 150.0
	for i in range(n):
		var ang: float = rot + float(i) * TAU / float(n)
		var half: float = 0.12
		var pts := PackedVector2Array([c,
			c + Vector2(cos(ang - half), sin(ang - half)) * L,
			c + Vector2(cos(ang + half), sin(ang + half)) * L])
		draw_polygon(pts, PackedColorArray([Color(GOLD, 0.10 * k), Color(GOLD, 0.0), Color(GOLD, 0.0)]))
	for i in range(4):
		draw_circle(c, 120.0 - 22.0 * i, Color(GOLD, 0.025 * k))

# --- letreiro de lâmpadas ---
func _draw_marquee(r: Rect2) -> void:
	var inset: float = 7.0
	var rr := r.grow(-inset)
	var pts: Array[Vector2] = []
	var x: float = rr.position.x
	while x < rr.end.x:
		pts.append(Vector2(x, rr.position.y)); x += BULB_GAP
	var y: float = rr.position.y
	while y < rr.end.y:
		pts.append(Vector2(rr.end.x, y)); y += BULB_GAP
	x = rr.end.x
	while x > rr.position.x:
		pts.append(Vector2(x, rr.end.y)); x -= BULB_GAP
	y = rr.end.y
	while y > rr.position.y:
		pts.append(Vector2(rr.position.x, y)); y -= BULB_GAP
	var speed: float = 5.0 if not spinning else 14.0
	var n: int = pts.size()
	for i in range(n):
		var lit: float
		var col: Color = GOLD
		if _win_t >= 0.0:
			lit = 1.0 if int(_win_t * 10.0) % 2 == 0 else 0.25   # todas piscam
			col = Color(1.0, 0.95, 0.55)
		elif _lose_t >= 0.0:
			lit = 0.0 if _lose_t < 1.1 else clampf((_lose_t - 1.1) * 2.0, 0.0, 0.3)   # apaga
			col = RED
		else:
			var ph: int = (i + int(_t * speed)) % 3
			lit = 1.0 if ph == 0 else 0.22
		var p: Vector2 = pts[i]
		if lit > 0.5:
			draw_circle(p, 9.0, Color(col, 0.16))
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color(0.1, 0.06, 0.04))
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), col.lerp(Color(0.25, 0.18, 0.1), 1.0 - lit))

func _draw_burst_beams(o: Vector2) -> void:
	var k: float = clampf(1.0 - _win_t / 2.2, 0.0, 1.0)
	var n: int = 12
	var rot: float = _t * 0.9
	var L: float = maxf(_vp().x, _vp().y)
	for i in range(n):
		var ang: float = rot + float(i) * TAU / float(n)
		var half: float = 0.06
		var pts := PackedVector2Array([o,
			o + Vector2(cos(ang - half), sin(ang - half)) * L,
			o + Vector2(cos(ang + half), sin(ang + half)) * L])
		draw_polygon(pts, PackedColorArray([Color(GOLD.lightened(0.3), 0.22 * k), Color(GOLD, 0.0), Color(GOLD, 0.0)]))

func _draw_coin(co: Dictionary) -> void:
	var a: float = clampf(float(co["life"]) / 0.3, 0.0, 1.0)
	var w: float = 16.0 * absf(cos(float(co["rot"]))) + 3.0
	var p: Vector2 = co["p"]
	draw_rect(Rect2(p.x - w * 0.5 - 2.0, p.y - 10.0, w + 4.0, 20.0), Color(0.1, 0.06, 0.05, a))
	draw_rect(Rect2(p.x - w * 0.5, p.y - 8.0, w, 16.0), Color(0.98, 0.78, 0.2, a))
	draw_rect(Rect2(p.x - w * 0.5, p.y - 8.0, maxf(w * 0.35, 1.0), 16.0), Color(1.0, 0.95, 0.6, a))

func _draw_star(p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s * 0.28, -s * 0.28), p + Vector2(s, 0), p + Vector2(s * 0.28, s * 0.28),
		p + Vector2(0, s), p + Vector2(-s * 0.28, s * 0.28), p + Vector2(-s, 0), p + Vector2(-s * 0.28, -s * 0.28)])
	draw_colored_polygon(pts, col)
