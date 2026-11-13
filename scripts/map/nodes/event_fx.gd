class_name EventFx
extends Control

# Camada de vida da cena de um evento ("?"): partículas do bioma/evento,
# luz pulsante no objeto, vinheta nas bordas e as explosões de reação
# (moedas, brilhos, anéis). Tudo em quadradinhos de pixel para combinar com
# a arte. É filha do art_layer: treme junto quando a cena treme.

signal coin_arrived

const PIX: float = 2.0
const GOLD := Color(1.0, 0.85, 0.3)
const COIN_TARGET := Vector2(60, 24)   # onde fica o "Ouro: N" no quadro da arte

# Partículas extras por evento (além da base do bioma).
const EXTRA := {
	"forge": ["ember"], "camp": ["ember"], "witch": ["ember", "spore"], "bandits": ["ember"],
	"prospectors": ["ember"], "ore_cart": ["ember"], "mushrooms": ["spore"], "fountain": ["glint"],
	"oasis": ["glint"], "mirage": ["glint"], "library": ["mote"], "sphinx": ["mote"], "obelisk": ["mote"],
	"sarcophagus": ["mote"], "relics": ["mote"], "altar": ["mote"], "scribe": ["mote"], "monk": ["mote"],
	"echo_chamber": ["echo"], "echo_miner": ["echo"], "mirror_shard": ["glint"], "mirror_altar": ["glint"],
	"crystal_vein": ["glint"], "sandstorm": ["sand", "sand"],
}
# Ponto da luz (0..1 do quadro). Padrão: centro, um pouco abaixo.
const FOCAL := {
	"forge": Vector2(0.5, 0.58), "fountain": Vector2(0.5, 0.55), "oasis": Vector2(0.5, 0.55),
	"witch": Vector2(0.5, 0.6), "camp": Vector2(0.5, 0.62),
}

var art_size: Vector2 = Vector2(900, 405)
var biome: String = "floresta"
var event_id: String = ""
var tint: Color = Color("#d9a441")
var glow_strength: float = 1.0
var _t: float = 0.0
var _danger: float = 0.0
var _parts: Array = []
var _light: Control
var _echo_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(p_biome: String, p_event_id: String, p_tint: Color, p_size: Vector2) -> void:
	biome = p_biome
	event_id = p_event_id
	tint = p_tint
	art_size = p_size
	size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_parts.clear()
	var kinds: Array = []
	match biome:
		"deserto": kinds = ["sand"]
		"mina": kinds = ["glint"]
		_: kinds = ["firefly"]
	kinds.append_array(EXTRA.get(event_id, []))
	for k in kinds:
		_spawn_ambient(k)
	if _light == null:
		_light = Control.new()
		_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_light.size = p_size
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_light.material = mat
		_light.draw.connect(func(): _draw_light(_light))
		add_child(_light)
	_light.size = p_size

func _spawn_ambient(kind: String) -> void:
	var n: int = 0
	match kind:
		"firefly": n = 16
		"sand": n = 34
		"glint": n = 14
		"ember": n = 22
		"spore": n = 14
		"mote": n = 16
		"echo": n = 0
	for i in range(n):
		_parts.append(_make_ambient(kind, true))
	if kind == "echo":
		_echo_timer = 0.2

func _make_ambient(kind: String, scatter: bool) -> Dictionary:
	var p := {"kind": kind, "phase": _rng.randf() * TAU, "t": 0.0}
	var x: float = _rng.randf() * art_size.x
	var y: float = _rng.randf() * art_size.y
	match kind:
		"firefly":
			p["pos"] = Vector2(x, y * 0.85 + 20)
			p["vel"] = Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-12, 6))
			p["col"] = Color(1.0, 0.93, 0.5) if _rng.randf() < 0.7 else Color(0.7, 1.0, 0.6)
		"sand":
			p["pos"] = Vector2(x if scatter else art_size.x + 10, y)
			p["vel"] = Vector2(-_rng.randf_range(70, 170), _rng.randf_range(-6, 10))
			p["len"] = _rng.randi_range(2, 5) * 2
			p["col"] = Color(0.95, 0.82, 0.55, _rng.randf_range(0.25, 0.5))
		"glint":
			p["pos"] = Vector2(x, y)
			p["vel"] = Vector2.ZERO
			var pick: float = _rng.randf()
			p["col"] = Color(0.66, 0.86, 0.94) if pick < 0.4 else (Color(0.7, 0.55, 0.95) if pick < 0.75 else Color(0.35, 0.85, 0.6))
			p["rate"] = _rng.randf_range(0.8, 1.8)
		"ember":
			p["pos"] = Vector2(x, art_size.y * _rng.randf_range(0.55, 1.0))
			p["vel"] = Vector2(_rng.randf_range(-10, 14), -_rng.randf_range(24, 60))
			p["life"] = _rng.randf_range(1.6, 3.2)
			p["t"] = _rng.randf() * float(p["life"]) if scatter else 0.0
			p["col"] = Color(1.0, 0.62, 0.2)
		"spore":
			p["pos"] = Vector2(x, art_size.y * _rng.randf_range(0.4, 1.0))
			p["vel"] = Vector2(_rng.randf_range(-6, 6), -_rng.randf_range(8, 20))
			p["life"] = _rng.randf_range(3.0, 5.0)
			p["t"] = _rng.randf() * float(p["life"]) if scatter else 0.0
			p["col"] = Color(0.95, 0.5, 0.75) if _rng.randf() < 0.5 else Color(0.55, 0.95, 0.65)
		"mote":
			p["pos"] = Vector2(x, y)
			p["vel"] = Vector2(_rng.randf_range(-5, 5), -_rng.randf_range(3, 12))
			p["life"] = _rng.randf_range(4.0, 7.0)
			p["t"] = _rng.randf() * float(p["life"]) if scatter else 0.0
			p["col"] = Color(1.0, 0.9, 0.55)
	return p

# ---------------------------------------------------------------- reações ----

# Chuva de moedas que sobe em arco e voa até o contador de ouro.
func burst_coins(count: int) -> void:
	var origin := art_size * Vector2(0.5, 0.58)
	for i in range(count):
		var a: float = _rng.randf_range(-PI * 0.9, -PI * 0.1)
		var sp: float = _rng.randf_range(220, 420)
		_parts.append({"kind": "coin", "pos": origin + Vector2(_rng.randf_range(-30, 30), 0), "vel": Vector2(cos(a), sin(a)) * sp,
			"t": -_rng.randf() * 0.18, "phase": _rng.randf() * TAU, "fly": 0.0})

func burst_sparkles(count: int = 22) -> void:
	var origin := art_size * Vector2(0.5, 0.52)
	for i in range(count):
		var a: float = _rng.randf() * TAU
		var sp: float = _rng.randf_range(60, 240)
		_parts.append({"kind": "spark", "pos": origin, "vel": Vector2(cos(a), sin(a) - 0.5) * sp, "t": 0.0,
			"life": _rng.randf_range(0.8, 1.5), "col": GOLD if _rng.randf() < 0.65 else Color(1, 1, 0.9),
			"sz": _rng.randi_range(1, 3)})

# Anel que se expande (ouro por padrão, vermelho no perigo).
func ring(col: Color = GOLD, at: Vector2 = Vector2(-1, -1)) -> void:
	var c := art_size * Vector2(0.5, 0.52) if at.x < 0 else at
	_parts.append({"kind": "ring", "pos": c, "t": 0.0, "life": 0.9, "col": col})

# Pulso vermelho na vinheta (emboscada).
func pulse_danger() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_danger", 1.0, 0.08)
	tw.tween_property(self, "_danger", 0.0, 1.4)

# Brilho da luz pulsante: sobe e volta (carta ganha, ouro).
func boost_glow(amount: float = 1.8) -> void:
	var tw := create_tween()
	tw.tween_property(self, "glow_strength", amount, 0.12)
	tw.tween_property(self, "glow_strength", 1.0, 1.0)

# Fumaça escura que sobe da cena (maldição).
func curse_smoke(count: int = 26) -> void:
	for i in range(count):
		_parts.append({"kind": "smoke", "pos": Vector2(_rng.randf() * art_size.x, art_size.y + 6), "vel": Vector2(_rng.randf_range(-12, 12), -_rng.randf_range(60, 130)),
			"t": -_rng.randf() * 0.4, "life": _rng.randf_range(1.0, 1.8), "sz": _rng.randi_range(3, 7)})

# ------------------------------------------------------------------ loop ----

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var keep: Array = []
	for p in _parts:
		if _step(p, delta):
			keep.append(p)
	_parts = keep
	if _has_kind_echo():
		_echo_timer -= delta
		if _echo_timer <= 0.0:
			_echo_timer = 1.7
			ring(Color(0.66, 0.86, 0.94), art_size * Vector2(0.5, 0.55))
	queue_redraw()
	if _light != null:
		_light.queue_redraw()

func _has_kind_echo() -> bool:
	return EXTRA.get(event_id, []).has("echo")

# Devolve false quando a partícula acabou.
func _step(p: Dictionary, dt: float) -> bool:
	var kind: String = p["kind"]
	p["t"] = float(p["t"]) + dt
	var t: float = p["t"]
	if t < 0.0:
		return true
	match kind:
		"firefly":
			var v: Vector2 = p["vel"]
			p["pos"] = Vector2(p["pos"]) + (v + Vector2(cos(_t * 0.9 + float(p["phase"])), sin(_t * 1.3 + float(p["phase"]))) * 10.0) * dt
			_wrap(p)
		"sand":
			p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * dt + Vector2(0, sin(_t * 2.0 + float(p["phase"])) * 6.0 * dt)
			if Vector2(p["pos"]).x < -12.0:
				var fresh := _make_ambient("sand", false)
				p["pos"] = fresh["pos"]
				p["vel"] = fresh["vel"]
		"glint":
			pass
		"ember", "spore", "mote":
			p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * dt + Vector2(sin(_t * 1.6 + float(p["phase"])) * 8.0 * dt, 0)
			if t >= float(p["life"]):
				var fresh2 := _make_ambient(kind, false)
				for k in fresh2.keys():
					p[k] = fresh2[k]
		"coin":
			var fly: float = p["fly"]
			if fly <= 0.0:
				var vel: Vector2 = p["vel"]
				vel.y += 900.0 * dt
				p["vel"] = vel
				p["pos"] = Vector2(p["pos"]) + vel * dt
				if t > 0.55:
					p["fly"] = 0.001
			else:
				fly += dt
				p["fly"] = fly
				var to: Vector2 = COIN_TARGET - Vector2(p["pos"])
				var spd: float = 260.0 + fly * 900.0
				var stepv: Vector2 = to.normalized() * spd * dt
				if to.length() <= stepv.length() + 6.0:
					coin_arrived.emit()
					return false
				p["pos"] = Vector2(p["pos"]) + stepv
		"spark":
			var v2: Vector2 = p["vel"]
			v2.y += 120.0 * dt
			v2 *= (1.0 - 1.6 * dt)
			p["vel"] = v2
			p["pos"] = Vector2(p["pos"]) + v2 * dt
			return t < float(p["life"])
		"ring":
			return t < float(p["life"])
		"smoke":
			p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * dt
			return t < float(p["life"])
	return true

func _wrap(p: Dictionary) -> void:
	var pos: Vector2 = p["pos"]
	if pos.x < -8: pos.x = art_size.x + 8
	if pos.x > art_size.x + 8: pos.x = -8
	if pos.y < -8: pos.y = art_size.y + 8
	if pos.y > art_size.y + 8: pos.y = -8
	p["pos"] = pos

# ---------------------------------------------------------------- desenho ----

func _px(c: CanvasItem, pos: Vector2, sz: float, col: Color) -> void:
	c.draw_rect(Rect2(pos.snapped(Vector2(PIX, PIX)), Vector2(sz, sz)), col)

func _cross(pos: Vector2, arm: float, col: Color) -> void:
	var c := pos.snapped(Vector2(PIX, PIX))
	draw_rect(Rect2(c - Vector2(arm, PIX * 0.5), Vector2(arm * 2.0 + PIX, PIX)), col)
	draw_rect(Rect2(c - Vector2(PIX * 0.5, arm), Vector2(PIX, arm * 2.0 + PIX)), col)
	draw_rect(Rect2(c - Vector2(PIX * 0.5, PIX * 0.5), Vector2(PIX * 2.0, PIX * 2.0)), Color(1, 1, 1, col.a))

func _draw() -> void:
	for p in _parts:
		var kind: String = p["kind"]
		var t: float = p["t"]
		if t < 0.0:
			continue
		var pos: Vector2 = p["pos"]
		match kind:
			"firefly":
				var a: float = clampf(0.5 + 0.5 * sin(_t * 2.2 + float(p["phase"])), 0.0, 1.0)
				a = a * a
				var col: Color = p["col"]
				_px(self, pos - Vector2(4, 4), 10.0, Color(col.r, col.g, col.b, 0.10 * a))
				_px(self, pos - Vector2(2, 2), 6.0, Color(col.r, col.g, col.b, 0.22 * a))
				_px(self, pos, PIX * 1.0, Color(col.r, col.g, col.b, 0.5 + 0.5 * a))
			"sand":
				draw_rect(Rect2(pos.snapped(Vector2(PIX, PIX)), Vector2(float(p["len"]), PIX)), p["col"])
			"glint":
				var s: float = sin(_t * float(p["rate"]) + float(p["phase"]))
				if s > 0.55:
					var col2: Color = p["col"]
					var k: float = (s - 0.55) / 0.45
					_cross(pos, 2.0 + 4.0 * k, Color(col2.r, col2.g, col2.b, 0.35 + 0.6 * k))
			"ember", "spore", "mote":
				var life: float = p["life"]
				var f: float = clampf(1.0 - t / life, 0.0, 1.0)
				var c3: Color = p["col"]
				if kind == "ember":
					c3 = c3.lerp(Color(0.85, 0.2, 0.1), 1.0 - f)
					_px(self, pos, 4.0 if f > 0.5 else PIX, Color(c3.r, c3.g, c3.b, f))
				elif kind == "spore":
					_px(self, pos, 4.0, Color(c3.r, c3.g, c3.b, 0.5 * sin(PI * (1.0 - f))))
				else:
					_px(self, pos, PIX, Color(c3.r, c3.g, c3.b, 0.55 * sin(PI * (1.0 - f))))
			"coin":
				var squish: float = absf(cos(t * 14.0 + float(p["phase"])))
				var w: float = maxf(2.0, 10.0 * squish)
				var cp := pos.snapped(Vector2(PIX, PIX))
				draw_rect(Rect2(cp - Vector2(w * 0.5, 5), Vector2(w, 10)), Color(0.95, 0.72, 0.2))
				draw_rect(Rect2(cp - Vector2(w * 0.5, 5), Vector2(maxf(2.0, w * 0.4), 4)), Color(1.0, 0.95, 0.6))
				draw_rect(Rect2(cp - Vector2(w * 0.5, -3), Vector2(w, 2)), Color(0.6, 0.4, 0.1))
			"spark":
				var f2: float = clampf(1.0 - t / float(p["life"]), 0.0, 1.0)
				var c4: Color = p["col"]
				_cross(pos, 2.0 * float(p["sz"]), Color(c4.r, c4.g, c4.b, f2))
			"ring":
				var u: float = clampf(t / float(p["life"]), 0.0, 1.0)
				var c5: Color = p["col"]
				var r: float = 16.0 + 230.0 * (1.0 - pow(1.0 - u, 3.0))
				draw_arc(pos, r, 0.0, TAU, 40, Color(c5.r, c5.g, c5.b, 0.7 * (1.0 - u)), 4.0)
			"smoke":
				var u2: float = clampf(t / float(p["life"]), 0.0, 1.0)
				var sz: float = float(p["sz"]) * 3.0
				_px(self, pos, sz, Color(0.12, 0.04, 0.18, 0.55 * sin(PI * u2)))
	_draw_vignette()

func _draw_vignette() -> void:
	var base := Color(0.04, 0.02, 0.08)
	var danger := Color(0.55, 0.05, 0.08)
	var col := base.lerp(danger, _danger)
	var steps: int = 10
	var step_w: float = 9.0
	for i in range(steps):
		var k: float = 1.0 - float(i) / float(steps)
		var a: float = (0.40 + 0.35 * _danger) * k * k
		var inset: float = i * step_w
		draw_rect(Rect2(Vector2(inset, inset) + Vector2(step_w, step_w) * 0.5, art_size - Vector2(inset, inset) * 2.0 - Vector2(step_w, step_w)),
			Color(col.r, col.g, col.b, a), false, step_w)

func _draw_light(c: Control) -> void:
	var focal: Vector2 = FOCAL.get(event_id, Vector2(0.5, 0.52))
	var center: Vector2 = art_size * focal
	var pulse: float = 0.5 + 0.5 * sin(_t * 1.7)
	var flick: float = 0.85 + 0.15 * sin(_t * 7.3 + sin(_t * 2.1) * 2.0)
	var base: Color = tint.lightened(0.35)
	var layers: int = 7
	for i in range(layers):
		var k: float = float(i) / float(layers - 1)
		var r: float = (170.0 - 130.0 * k) * (0.92 + 0.12 * pulse)
		var a: float = (0.07 + 0.03 * pulse) * glow_strength * flick
		c.draw_circle(center, r, Color(base.r, base.g, base.b, a))
