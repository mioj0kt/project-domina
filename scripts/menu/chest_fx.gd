class_name ChestFx
extends Control
# Baú do Grimório desenhado 100% por código (sem arte ainda), com a sequência de
# abertura no estilo "baú do Vampire Survivors": queda, tremedeira com brilho
# crescente na cor da raridade, flash, tampa abrindo, feixes de luz, moedas e
# faíscas. Dois usos:
#   - idle_mode = true : baú pequeno na aba (flutua, brilha, emite `pressed` ao clicar)
#   - play(raridade, cor): sequência completa em tela cheia (emite `opened` quando a
#     tampa abre = hora de mostrar o prêmio, e `finished` quando o baú some)
# Para trocar por sprites depois, basta colocar em res://assets/sprites/grimorio/:
#   bau_<tipo>.png (fechado) e bau_<tipo>_aberto.png (aberto), tipo = "cartas" | "leis".

signal pressed
signal opened
signal finished

const TEX_DIR: String = "res://assets/sprites/grimorio/"
const GOLD := Color(0.95, 0.75, 0.25)
const OUTLINE := Color(0.1, 0.06, 0.05)
const WOOD := Color(0.45, 0.27, 0.14)
const WOOD_DARK := Color(0.28, 0.16, 0.09)
const WOOD_LIGHT := Color(0.62, 0.4, 0.22)

const T_DROP: float = 0.4
const T_SHAKE_END: float = 1.5
const T_FADE: float = 2.3
const T_FADE_LEN: float = 0.45

var tint: Color = GOLD
var rarity: int = 0
var idle_mode: bool = true
var chest_scale: float = 1.0
var kind: String = "cartas"       # "cartas" | "leis" (só para os sprites opcionais)

var _time: float = 0.0
var _t: float = 0.0
var _playing: bool = false
var _opened_fired: bool = false
var _finished_fired: bool = false
var _flash: float = 0.0
var _beams: float = 0.0
var _alpha: float = 1.0
var _coins: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _hover: bool = false
var _spark_acc: float = 0.0
var _tex_closed: Texture2D = null
var _tex_open: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if idle_mode else Control.MOUSE_FILTER_IGNORE
	if idle_mode:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true)
		mouse_exited.connect(func(): _hover = false)
	_load_textures()

func _load_textures() -> void:
	var p1 := "%sbau_%s.png" % [TEX_DIR, kind]
	var p2 := "%sbau_%s_aberto.png" % [TEX_DIR, kind]
	_tex_closed = load(p1) if ResourceLoader.exists(p1) else null
	_tex_open = load(p2) if ResourceLoader.exists(p2) else null

func _gui_input(ev: InputEvent) -> void:
	if idle_mode and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()

# Inicia a sequência de abertura. `color` = cor da raridade sorteada.
func play(rarity_idx: int, color: Color) -> void:
	idle_mode = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rarity = clampi(rarity_idx, 0, 3)
	tint = color
	_t = 0.0
	_playing = true
	_opened_fired = false
	_finished_fired = false
	_flash = 0.0
	_beams = 0.0
	_alpha = 1.0
	_coins.clear()
	_sparks.clear()

func _origin() -> Vector2:
	return size * 0.5

func _process(delta: float) -> void:
	_time += delta
	if _playing:
		_step_sequence(delta)
	elif idle_mode:
		_spark_acc += delta
		var every: float = 0.18 if _hover else 0.45
		if _spark_acc >= every:
			_spark_acc = 0.0
			_add_spark(_origin() + Vector2(randf_range(-90.0, 90.0) * chest_scale, randf_range(-70.0, 30.0) * chest_scale),
				Vector2(randf_range(-10.0, 10.0), randf_range(-50.0, -20.0)), 0.9, randf_range(5.0, 9.0) * chest_scale, tint)
	_step_particles(delta)
	queue_redraw()

func _step_sequence(delta: float) -> void:
	var shake_p: float = clampf((_t - T_DROP) / (T_SHAKE_END - T_DROP), 0.0, 1.0)
	if _t > T_DROP and _t < T_SHAKE_END:
		_spark_acc += delta
		var every: float = lerpf(0.12, 0.025, shake_p)
		while _spark_acc >= every:
			_spark_acc -= every
			var a: float = randf() * TAU
			var r: float = randf_range(90.0, 150.0) * chest_scale
			var p: Vector2 = _origin() + Vector2(cos(a), sin(a)) * r
			_add_spark(p, (_origin() - p).normalized() * randf_range(60.0, 140.0), 0.7, randf_range(5.0, 9.0), _glow_color(shake_p))
	_t += delta
	if _t >= T_SHAKE_END and not _opened_fired:
		_opened_fired = true
		_burst()
		opened.emit()
	if _opened_fired:
		_flash = maxf(0.0, 1.0 - (_t - T_SHAKE_END) / 0.7)
		_beams = clampf((_t - T_SHAKE_END) / 0.5, 0.0, 1.0)
	if _t > T_FADE:
		_alpha = clampf(1.0 - (_t - T_FADE) / T_FADE_LEN, 0.0, 1.0)
		if _alpha <= 0.0 and not _finished_fired:
			_finished_fired = true
			finished.emit()

func _glow_color(p: float) -> Color:
	# Brilho começa dourado neutro e vira a cor da raridade perto do fim (suspense).
	return GOLD.lerp(tint, clampf((p - 0.45) / 0.45, 0.0, 1.0))

func _burst() -> void:
	var o: Vector2 = _origin() + Vector2(0.0, -10.0)
	var n_coins: int = 16 + 9 * rarity
	for i in range(n_coins):
		var ang: float = -PI * 0.5 + randf_range(-1.15, 1.15)
		var spd: float = randf_range(520.0, 980.0)
		_coins.append({"p": o, "v": Vector2(cos(ang), sin(ang)) * spd, "rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0), "life": randf_range(1.3, 1.9), "max": 1.9})
	var n_sparks: int = 26 + 16 * rarity
	for i in range(n_sparks):
		var ang2: float = randf() * TAU
		var spd2: float = randf_range(180.0, 620.0)
		var col: Color = tint.lightened(randf_range(0.0, 0.5))
		if rarity == 3 and randf() < 0.5:
			col = Color.from_hsv(randf(), 0.55, 1.0)
		_add_spark(o, Vector2(cos(ang2), sin(ang2)) * spd2, randf_range(0.7, 1.5), randf_range(6.0, 14.0), col)

func _add_spark(p: Vector2, v: Vector2, life: float, sz: float, col: Color) -> void:
	_sparks.append({"p": p, "v": v, "life": life, "max": life, "sz": sz, "col": col})

func _step_particles(delta: float) -> void:
	for c in _coins:
		c["v"].y += 1500.0 * delta
		c["p"] += c["v"] * delta
		c["rot"] += c["spin"] * delta
		c["life"] -= delta
	_coins = _coins.filter(func(c): return c["life"] > 0.0 and c["p"].y < size.y + 60.0)
	for s in _sparks:
		s["p"] += s["v"] * delta
		s["v"] *= (1.0 - 1.4 * delta)
		s["life"] -= delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)

# ---------------------------------------------------------------------
func _draw() -> void:
	var o: Vector2 = _origin()
	if _playing and _beams > 0.0:
		_draw_beams(o + Vector2(0.0, -10.0), _beams * _alpha_beams())
	# baú
	var sc: float = chest_scale
	var c: Vector2 = o
	var open_f: float = 0.0
	var glow_p: float = 0.0
	var glow_col: Color = GOLD
	if _playing:
		sc *= 1.6
		if _t < T_DROP:
			var p: float = _t / T_DROP
			c.y += lerpf(-size.y * 0.7, 0.0, ease(p, 0.35))   # cai de cima
		else:
			var shake_p: float = clampf((_t - T_DROP) / (T_SHAKE_END - T_DROP), 0.0, 1.0)
			if _t < T_SHAKE_END:
				var amp: float = 1.5 + 13.0 * shake_p * shake_p
				c.x += sin(_t * 62.0) * amp
				c.y += cos(_t * 47.0) * amp * 0.4
				sc *= 1.0 + 0.04 * shake_p
				glow_p = shake_p
				glow_col = _glow_color(shake_p)
		if _opened_fired:
			var q: float = clampf((_t - T_SHAKE_END) / 0.4, 0.0, 1.0)
			open_f = 1.0 - pow(1.0 - q, 3.0)
			glow_p = 1.0
			glow_col = tint
		if _t > T_FADE:
			sc *= lerpf(1.0, 0.6, 1.0 - _alpha)
	else:
		c.y += sin(_time * 2.2) * 6.0 * chest_scale
		sc *= 1.06 if _hover else 1.0
		glow_p = 0.35 + (0.35 if _hover else 0.0) + 0.1 * sin(_time * 3.0)
		glow_col = GOLD
	if _alpha > 0.0:
		_draw_glow(c, sc, glow_p, glow_col)
		_draw_chest(c, sc, open_f)
	# partículas
	for co in _coins:
		_draw_coin(co)
	for s in _sparks:
		var a: float = clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
		_draw_star(s["p"], float(s["sz"]) * (0.5 + 0.5 * a), Color(s["col"], a))
	# flash de tela
	if _playing and _flash > 0.0:
		var fc: Color = Color(1, 1, 1).lerp(tint, 0.35)
		draw_rect(Rect2(Vector2.ZERO, size), Color(fc, _flash * (0.55 + 0.1 * rarity)))

func _alpha_beams() -> float:
	return 1.0

func _draw_beams(o: Vector2, k: float) -> void:
	var n: int = 8 + 4 * rarity
	var L: float = maxf(size.x, size.y) * 1.1
	var rot: float = _time * (0.35 + 0.08 * rarity)
	var half: float = 0.065 + 0.01 * rarity
	for i in range(n):
		var ang: float = rot + float(i) * TAU / float(n)
		var col: Color = tint.lightened(0.35)
		if rarity == 3:
			col = Color.from_hsv(fmod(float(i) / float(n) + _time * 0.15, 1.0), 0.45, 1.0)
		var pts := PackedVector2Array([o,
			o + Vector2(cos(ang - half), sin(ang - half)) * L,
			o + Vector2(cos(ang + half), sin(ang + half)) * L])
		var cols := PackedColorArray([Color(col, 0.55 * k), Color(col, 0.0), Color(col, 0.0)])
		draw_polygon(pts, cols)
	# anel de luz expandindo no estouro
	var ring_t: float = clampf((_t - T_SHAKE_END) / 0.8, 0.0, 1.0)
	if ring_t < 1.0:
		draw_arc(o, 40.0 + ring_t * 520.0, 0.0, TAU, 64, Color(tint.lightened(0.5), (1.0 - ring_t) * 0.8), 6.0 * (1.0 - ring_t) + 1.0)

func _draw_glow(c: Vector2, sc: float, p: float, col: Color) -> void:
	if p <= 0.0:
		return
	for i in range(7):
		var f: float = float(i) / 7.0
		draw_circle(c + Vector2(0.0, -10.0 * sc), (190.0 - 120.0 * f) * sc * (0.6 + 0.5 * p), Color(col, 0.045 * p + 0.01))

func _col(c: Color) -> Color:
	return Color(c, c.a * _alpha)

func _rect(r: Rect2, fill: Color, outline_px: float = 0.0) -> void:
	if outline_px > 0.0:
		draw_rect(r.grow(outline_px), _col(OUTLINE))
	draw_rect(r, _col(fill))

func _draw_chest(c: Vector2, sc: float, f: float) -> void:
	# Sprite próprio (se existir): usa no lugar do desenho em código.
	var tex: Texture2D = _tex_open if (f > 0.5 and _tex_open != null) else _tex_closed
	if tex != null:
		var ts: Vector2 = tex.get_size() * sc * 2.0
		draw_texture_rect(tex, Rect2(c - ts * 0.5, ts), false, Color(1, 1, 1, _alpha))
		return
	var W: float = 220.0 * sc
	var H: float = 118.0 * sc
	var LH: float = 64.0 * sc
	var u: float = sc            # "pixel" do desenho
	var band: Color = GOLD.lerp(tint, 0.45)
	var band_dark: Color = band.darkened(0.35)
	var base_y: float = c.y - (H - LH) * 0.5 + 0.0   # topo do corpo
	var x0: float = c.x - W * 0.5
	var body := Rect2(x0, base_y, W, H)
	# corpo
	_rect(body, WOOD, 4.0 * u)
	draw_rect(Rect2(x0, base_y + H * 0.30, W, 3.0 * u), _col(WOOD_DARK))
	draw_rect(Rect2(x0, base_y + H * 0.62, W, 3.0 * u), _col(WOOD_DARK))
	draw_rect(Rect2(x0, base_y, W, 5.0 * u), _col(WOOD_LIGHT))
	draw_rect(Rect2(x0, base_y + H - 8.0 * u, W, 8.0 * u), _col(WOOD_DARK))
	for bx in [0.12, 0.76]:
		var r := Rect2(x0 + W * bx, base_y, W * 0.12, H)
		_rect(r, band, 2.0 * u)
		draw_rect(Rect2(r.position.x, r.position.y, 4.0 * u, r.size.y), _col(band.lightened(0.35)))
		draw_rect(Rect2(r.end.x - 4.0 * u, r.position.y, 4.0 * u, r.size.y), _col(band_dark))
	# interior aceso (aparece quando abre)
	var hinge_y: float = base_y - 12.0 * u
	if f > 0.0:
		var ih: float = 18.0 * u * f
		var inner := Rect2(x0 + 8.0 * u, base_y - ih + 4.0 * u, W - 16.0 * u, ih + 2.0 * u)
		draw_rect(inner, _col(tint.lightened(0.7)))
		draw_rect(Rect2(inner.position.x + 6.0 * u, inner.position.y, inner.size.x - 12.0 * u, 4.0 * u), _col(Color(1, 1, 1, 0.9)))
	# tampa
	var ang: float = f * PI * 0.56
	var ca: float = cos(ang)
	if ca >= 0.0:
		var lh: float = maxf(LH * ca, 2.0 * u)
		var bottom: float = base_y - 12.0 * u * sin(ang)
		var lid := Rect2(x0, bottom - lh, W, lh)
		_draw_lid_face(lid, u, band, band_dark, false)
	else:
		var lh2: float = maxf(LH * -ca, 2.0 * u)
		var lid2 := Rect2(x0 + 6.0 * u, hinge_y - lh2, W - 12.0 * u, lh2)
		_draw_lid_face(lid2, u, band, band_dark, true)
	# fechadura (só fechado)
	if f < 0.3:
		var lock := Rect2(c.x - 17.0 * u, base_y - 12.0 * u, 34.0 * u, 36.0 * u)
		_rect(lock, band, 3.0 * u)
		draw_rect(Rect2(lock.position.x, lock.position.y, lock.size.x, 4.0 * u), _col(band.lightened(0.4)))
		draw_rect(Rect2(c.x - 3.0 * u, lock.position.y + 11.0 * u, 6.0 * u, 12.0 * u), _col(OUTLINE))

func _draw_lid_face(r: Rect2, u: float, band: Color, band_dark: Color, inside: bool) -> void:
	if r.size.y <= 0.0:
		return
	var fill: Color = Color(0.55, 0.12, 0.16) if inside else WOOD
	_rect(r, fill, 4.0 * u)
	if not inside:
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5.0 * u), _col(WOOD_LIGHT))
		for bx in [0.12, 0.76]:
			var b := Rect2(r.position.x + r.size.x * bx, r.position.y, r.size.x * 0.12, r.size.y)
			_rect(b, band, 2.0 * u)
			draw_rect(Rect2(b.position.x, b.position.y, 4.0 * u, b.size.y), _col(band.lightened(0.35)))
			draw_rect(Rect2(b.end.x - 4.0 * u, b.position.y, 4.0 * u, b.size.y), _col(band_dark))
	else:
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 4.0 * u), _col(Color(0.75, 0.2, 0.25)))

func _draw_coin(co: Dictionary) -> void:
	var life: float = float(co["life"])
	var a: float = clampf(life / 0.3, 0.0, 1.0)
	var w: float = 16.0 * absf(cos(float(co["rot"]))) + 3.0
	var p: Vector2 = co["p"]
	draw_rect(Rect2(p.x - w * 0.5 - 2.0, p.y - 10.0, w + 4.0, 20.0), Color(OUTLINE, a))
	draw_rect(Rect2(p.x - w * 0.5, p.y - 8.0, w, 16.0), Color(0.98, 0.78, 0.2, a))
	draw_rect(Rect2(p.x - w * 0.5, p.y - 8.0, maxf(w * 0.35, 1.0), 16.0), Color(1.0, 0.95, 0.6, a))

func _draw_star(p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s * 0.28, -s * 0.28), p + Vector2(s, 0), p + Vector2(s * 0.28, s * 0.28),
		p + Vector2(0, s), p + Vector2(-s * 0.28, s * 0.28), p + Vector2(-s, 0), p + Vector2(-s * 0.28, -s * 0.28)])
	draw_colored_polygon(pts, col)
