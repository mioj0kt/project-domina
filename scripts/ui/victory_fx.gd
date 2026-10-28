class_name VictoryFx
extends Control
# Comemoração de vitória desenhada por código: flash dourado, brilho nas bordas,
# fogos de artifício, chuva de moedas, faíscas subindo e (no CHEFE) confete colorido e
# explosões em sequência. Fica por trás do painel (adicione ANTES dele).
#   start(big)        : dispara a comemoração (big = Chefe / vitória da run)
#   pop_at(pos, n)    : pequena explosão de moedas/faíscas num ponto (ex.: cada
#                       Coroa contada)
# É só visual: mouse_filter = IGNORE.

const GOLD := Color(1.0, 0.82, 0.25)
const CONFETTI: Array[Color] = [
	Color(1.0, 0.82, 0.25), Color(0.95, 0.35, 0.4), Color(0.35, 0.8, 0.95),
	Color(0.55, 0.9, 0.45), Color(0.75, 0.45, 1.0)]

var _t: float = 0.0
var _active: bool = false
var _big: bool = false
var _shower_left: float = 0.0
var _shower_acc: float = 0.0
var _spark_acc: float = 0.0
var _burst_times: Array[float] = []
var _flash: float = 0.0
var _glow: float = 0.0              # brilho dourado nas bordas da tela
var _rockets: Array[Dictionary] = []
var _rocket_times: Array[float] = []
var _focus: Vector2 = Vector2.ZERO
var _coins: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _confetti: Array[Dictionary] = []

func _vp() -> Vector2:
	return get_viewport_rect().size

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func start(big: bool = false, focus: Vector2 = Vector2(-1, -1)) -> void:
	_big = big
	_active = true
	_t = 0.0
	_focus = focus if focus.x >= 0.0 else _vp() * 0.5
	_flash = 1.0
	_shower_left = 4.5 if big else 2.2
	_burst_times.assign([0.0])
	_rocket_times.clear()
	var n_rockets: int = 11 if big else 4
	for i in range(n_rockets):
		_rocket_times.append(0.25 + float(i) * (0.34 if big else 0.5) + randf() * 0.12)
	if big:
		for i in range(70):
			_spawn_confetti(true)

func stop() -> void:
	_active = false

func pop_at(pos: Vector2, n: int = 3) -> void:
	for i in range(n):
		var a: float = -PI * 0.5 + randf_range(-0.9, 0.9)
		var s: float = randf_range(180.0, 380.0)
		_coins.append({"p": pos, "v": Vector2(cos(a), sin(a)) * s, "rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0), "life": randf_range(0.5, 0.9), "sz": 0.7})
	for i in range(5):
		var a2: float = randf() * TAU
		_add_spark(pos, Vector2(cos(a2), sin(a2)) * randf_range(60.0, 200.0), randf_range(0.4, 0.8), randf_range(4.0, 8.0), GOLD.lightened(randf() * 0.4))

func _add_spark(p: Vector2, v: Vector2, life: float, sz: float, col: Color) -> void:
	_sparks.append({"p": p, "v": v, "life": life, "max": life, "sz": sz, "col": col})

func _spawn_confetti(anywhere: bool = false) -> void:
	var vp: Vector2 = _vp()
	var y: float = randf_range(-vp.y * 0.6, vp.y * 0.2) if anywhere else -20.0
	_confetti.append({"p": Vector2(randf() * vp.x, y), "vy": randf_range(120.0, 260.0), "sway": randf() * TAU,
		"col": CONFETTI[randi() % CONFETTI.size()], "rot": randf() * TAU, "spin": randf_range(-6.0, 6.0)})

func _burst(o: Vector2, n: int) -> void:
	for i in range(n):
		var a: float = randf() * TAU
		var s: float = randf_range(220.0, 760.0)
		var col: Color = CONFETTI[randi() % CONFETTI.size()] if _big else GOLD.lightened(randf() * 0.5)
		_add_spark(o, Vector2(cos(a), sin(a)) * s, randf_range(0.7, 1.4), randf_range(6.0, 13.0), col)
	for i in range(18 if _big else 12):
		var a2: float = -PI * 0.5 + randf_range(-1.2, 1.2)
		var s2: float = randf_range(520.0, 980.0)
		_coins.append({"p": o, "v": Vector2(cos(a2), sin(a2)) * s2, "rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0), "life": randf_range(1.2, 1.8), "sz": 1.0})

# Fogos de artifício: o foguete sobe deixando rastro e explode em círculo,
# anel ou chuva, com as partículas caindo devagar.
func _launch_rocket() -> void:
	var vp: Vector2 = _vp()
	var x: float = randf_range(0.12, 0.88) * vp.x
	var top: float = randf_range(0.12, 0.42) * vp.y
	var col: Color = CONFETTI[randi() % CONFETTI.size()] if _big else GOLD.lightened(randf() * 0.35)
	var kinds: Array[String] = ["circle", "ring", "willow"]
	_rockets.append({"p": Vector2(x, vp.y + 10.0), "v": Vector2(randf_range(-40.0, 40.0), -randf_range(720.0, 900.0)),
		"top": top, "col": col, "kind": kinds[randi() % kinds.size()], "trail": 0.0, "dead": false})

func _explode(o: Vector2, col: Color, kind: String) -> void:
	var n: int = 44 if _big else 34
	for i in range(n):
		var a: float = float(i) / float(n) * TAU + randf() * 0.05
		var sp: float = 330.0 if kind == "ring" else randf_range(120.0, 440.0)
		var life: float = 1.9 if kind == "willow" else randf_range(0.9, 1.4)
		var c: Color = col.lightened(randf() * 0.35) if kind != "ring" else col
		_sparks.append({"p": o, "v": Vector2(cos(a), sin(a)) * sp, "life": life, "max": life,
			"sz": randf_range(4.0, 8.0), "col": c, "g": 180.0 if kind == "willow" else 90.0})
	# clarão central do estouro
	for i in range(6):
		_sparks.append({"p": o, "v": Vector2.ZERO, "life": 0.18, "max": 0.18, "sz": 18.0 - float(i) * 2.0, "col": Color(1, 1, 0.85), "g": 0.0})

func _process(delta: float) -> void:
	_t += delta
	var vp: Vector2 = _vp()
	if _active:
		_glow = minf(_glow + delta * 1.5, 1.0)
		while not _rocket_times.is_empty() and _t >= _rocket_times[0]:
			_rocket_times.pop_front()
			_launch_rocket()
		_flash = maxf(0.0, _flash - delta * 1.6)
		# disparos de explosão
		while not _burst_times.is_empty() and _t >= _burst_times[0]:
			_burst_times.pop_front()
			var o: Vector2 = _focus
			if _big and _t > 0.3:
				o = Vector2(randf_range(0.2, 0.8) * vp.x, randf_range(0.2, 0.55) * vp.y)
			_burst(o, 46 if _big else 30)
		# chuva de moedas
		if _shower_left > 0.0:
			_shower_left -= delta
			_shower_acc += delta
			var every: float = 0.045 if _big else 0.08
			while _shower_acc >= every:
				_shower_acc -= every
				_coins.append({"p": Vector2(randf() * vp.x, -20.0), "v": Vector2(randf_range(-40.0, 40.0), randf_range(150.0, 420.0)),
					"rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "life": 4.0, "sz": 1.0})
			if _big and randf() < 0.5:
				_spawn_confetti()
		# faíscas subindo (sempre, enquanto ativo)
		_spark_acc += delta
		while _spark_acc >= 0.06:
			_spark_acc -= 0.06
			_add_spark(Vector2(randf() * vp.x, vp.y + 10.0), Vector2(randf_range(-20.0, 20.0), randf_range(-160.0, -60.0)),
				randf_range(1.5, 3.0), randf_range(4.0, 9.0), GOLD.lightened(randf() * 0.4))
	else:
		_glow = maxf(0.0, _glow - delta)
		_flash = maxf(0.0, _flash - delta * 2.0)
	for r in _rockets:
		r["p"] += r["v"] * delta
		r["v"].y += 260.0 * delta
		r["trail"] += delta
		while r["trail"] >= 0.016:
			r["trail"] -= 0.016
			_sparks.append({"p": r["p"], "v": Vector2(randf_range(-25.0, 25.0), randf_range(20.0, 70.0)), "life": 0.45, "max": 0.45, "sz": 4.0, "col": r["col"].lightened(0.3), "g": 0.0})
		if r["v"].y > -60.0 or r["p"].y <= r["top"]:
			r["dead"] = true
			_explode(r["p"], r["col"], r["kind"])
	_rockets = _rockets.filter(func(r): return not r["dead"])
	for c in _coins:
		c["v"].y += 900.0 * delta
		c["p"] += c["v"] * delta
		c["rot"] += c["spin"] * delta
		c["life"] -= delta
	_coins = _coins.filter(func(c): return c["life"] > 0.0 and c["p"].y < vp.y + 40.0)
	for s in _sparks:
		s["p"] += s["v"] * delta
		s["v"] *= (1.0 - 1.1 * delta)
		s["v"].y += float(s.get("g", 0.0)) * delta
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	for f in _confetti:
		f["p"].y += f["vy"] * delta
		f["p"].x += sin(_t * 2.0 + f["sway"]) * 40.0 * delta
		f["rot"] += f["spin"] * delta
	_confetti = _confetti.filter(func(f): return f["p"].y < vp.y + 20.0)
	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = _vp()
	if _glow > 0.0:
		_draw_edge_glow(vp, _glow * (0.75 + 0.25 * sin(_t * 2.2)))
	for f in _confetti:
		var w: float = 10.0 * absf(cos(float(f["rot"]))) + 2.0
		var p: Vector2 = f["p"]
		draw_rect(Rect2(p.x - w * 0.5, p.y - 5.0, w, 10.0), f["col"])
	for c in _coins:
		_draw_coin(c)
	for s in _sparks:
		var a: float = clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
		_draw_star(s["p"], float(s["sz"]) * (0.5 + 0.5 * a), Color(s["col"], a))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.92, 0.6, _flash * 0.35))

# Brilho dourado que "respira" nas bordas da tela (no lugar dos antigos feixes).
func _draw_edge_glow(vp: Vector2, k: float) -> void:
	var th: float = 260.0
	var c0 := Color(GOLD, 0.30 * k)
	var c1 := Color(GOLD, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(th, 0), Vector2(th, vp.y), Vector2(0, vp.y)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(vp.x, 0), Vector2(vp.x - th, 0), Vector2(vp.x - th, vp.y), Vector2(vp.x, vp.y)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(0, vp.y), Vector2(0, vp.y - th), Vector2(vp.x, vp.y - th), Vector2(vp.x, vp.y)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, th), Vector2(vp.x, th), Vector2(vp.x, 0)]), PackedColorArray([c0, c1, c1, c0]))

func _draw_coin(co: Dictionary) -> void:
	var k: float = float(co["sz"])
	var a: float = clampf(float(co["life"]) / 0.3, 0.0, 1.0)
	var w: float = (16.0 * absf(cos(float(co["rot"]))) + 3.0) * k
	var h: float = 16.0 * k
	var p: Vector2 = co["p"]
	draw_rect(Rect2(p.x - w * 0.5 - 2.0, p.y - h * 0.5 - 2.0, w + 4.0, h + 4.0), Color(0.1, 0.06, 0.05, a))
	draw_rect(Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h), Color(0.98, 0.78, 0.2, a))
	draw_rect(Rect2(p.x - w * 0.5, p.y - h * 0.5, maxf(w * 0.35, 1.0), h), Color(1.0, 0.95, 0.6, a))

func _draw_star(p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s * 0.28, -s * 0.28), p + Vector2(s, 0), p + Vector2(s * 0.28, s * 0.28),
		p + Vector2(0, s), p + Vector2(-s * 0.28, s * 0.28), p + Vector2(-s, 0), p + Vector2(-s * 0.28, -s * 0.28)])
	draw_colored_polygon(pts, col)
