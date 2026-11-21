class_name RewardStage
extends RefCounted

# Peças visuais das telas de recompensa (Cartas e Leis), no estilo do resto do
# jogo: faixa de título com uma peça de damas em cada ponta, "palco" com raios de
# luz na cor da raridade atrás de cada opção, plaquinha de raridade com gema e a
# entrada das opções (sobem do chão e viram).

const FONT := preload("res://assets/fonts/m5x7.ttf")
const C_OUT := Color("1f161d")
const C_PLUM := Color("4a3a46")
const C_PLUM_DK := Color("31252f")
const C_PLUM_LT := Color("5a4855")
const C_CREAM := Color("efe6cf")
const C_CREAM_SH := Color("b9a983")
const C_GOLD := Color("f0d27a")
const C_GOLD_SH := Color("c99a3a")

# Fundo escurecido com vinheta em degraus (pixel), cor ameixa.
class Backdrop extends Control:
	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var s: Vector2 = size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.03, 0.06, 0.86))
		var step: float = 12.0
		for i in range(6):
			var a: float = 0.06 * float(i + 1)
			var inset: float = step * float(6 - i) * 3.0
			# bordas escurecendo para fora
			draw_rect(Rect2(Vector2.ZERO, Vector2(s.x, maxf(0.0, s.y * 0.5 - inset - s.y * 0.18))), Color(0, 0, 0, 0.05))
			draw_rect(Rect2(Vector2(0, 0), Vector2(maxf(0.0, s.x * 0.5 - inset - s.x * 0.22), s.y)), Color(0, 0, 0, a * 0.35))
			draw_rect(Rect2(Vector2(s.x - maxf(0.0, s.x * 0.5 - inset - s.x * 0.22), 0), Vector2(maxf(0.0, s.x * 0.5 - inset - s.x * 0.22), s.y)), Color(0, 0, 0, a * 0.35))

# Faixa de título: placa com moldura creme, rabos de fita dobrados nas pontas e
# uma peça de damas (creme / escura) em cada lado.
class Banner extends Control:
	var title: String = ""
	var font_size: int = 48
	var _t: float = 0.0
	const PX: float = 3.0

	func _ready() -> void:
		var tw: float = FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		custom_minimum_size = Vector2(ceilf((tw + 64.0 * PX) / PX) * PX, 26.0 * PX)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _r(p: Vector2, sz: Vector2, c: Color) -> void:
		draw_rect(Rect2(p.round(), sz), c)

	func _draw() -> void:
		var u: float = PX
		var w: float = size.x
		var h: float = 20.0 * u
		var y0: float = 3.0 * u
		# rabos de fita (atrás), um pouco mais baixos, com o "V" cortado
		for sx in [-1.0, 1.0]:
			var tail_w: float = 16.0 * u
			var x0: float = (0.0) if sx < 0.0 else (w - tail_w)
			var ty: float = y0 + 4.0 * u
			for k in range(int(tail_w / u)):
				var xx: float = x0 + float(k) * u
				var from_out: int = k if sx < 0.0 else int(tail_w / u) - 1 - k
				var notch: float = maxf(0.0, 4.0 - float(from_out)) * u
				_r(Vector2(xx, ty + notch * 0.0), Vector2(u, h - u * 2.0), C_OUT)
				if from_out >= 1:
					var cut: float = (4.0 - absf(float(from_out) - 0.0)) if from_out < 4 else 0.0
					_r(Vector2(xx, ty + u), Vector2(u, h - u * 4.0), C_PLUM_DK)
					if cut > 0.0:
						# o "V" da ponta da fita
						_r(Vector2(xx, ty + (h - u * 2.0) * 0.5 - cut * u * 0.5), Vector2(u, cut * u), Color(0, 0, 0, 0))
			# dobra (sombra) entre o rabo e a placa
			var fx: float = (tail_w - 2.0 * u) if sx < 0.0 else (w - tail_w)
			_r(Vector2(fx, ty + h - u * 3.0), Vector2(u * 2.0, u * 2.0), C_OUT)
		# placa principal
		var px0: float = 10.0 * u
		var pw: float = w - 20.0 * u
		_r(Vector2(px0 + u, y0), Vector2(pw - u * 2.0, h), C_OUT)
		_r(Vector2(px0, y0 + u), Vector2(pw, h - u * 2.0), C_OUT)
		_r(Vector2(px0 + u, y0 + u), Vector2(pw - u * 2.0, h - u * 2.0), C_CREAM)
		_r(Vector2(px0 + u * 2.0, y0 + u * 2.0), Vector2(pw - u * 4.0, h - u * 4.0), C_OUT)
		_r(Vector2(px0 + u * 3.0, y0 + u * 3.0), Vector2(pw - u * 6.0, h - u * 6.0), C_PLUM)
		_r(Vector2(px0 + u * 3.0, y0 + u * 3.0), Vector2(pw - u * 6.0, u * 2.0), C_PLUM_LT)
		_r(Vector2(px0 + u * 3.0, y0 + h - u * 5.0), Vector2(pw - u * 6.0, u * 2.0), C_PLUM_DK)
		_r(Vector2(px0 + u * 6.0, y0 + u * 4.0), Vector2(pw - u * 12.0, u), C_GOLD_SH)
		# brilho correndo pela borda de cima
		var k2: float = fposmod(_t * 0.35, 1.0)
		var bx: float = px0 + u * 2.0 + k2 * (pw - u * 10.0)
		_r(Vector2(bx, y0 + u), Vector2(u * 6.0, u), Color(1, 1, 1, 0.8))
		# peças nas pontas
		_piece(Vector2(px0 + u * 1.0, y0 + h * 0.5), 8.0 * u, true)
		_piece(Vector2(px0 + pw - u * 1.0, y0 + h * 0.5), 8.0 * u, false)
		# título
		var fs: int = font_size
		var tw: float = FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base: float = y0 + h * 0.5 + (FONT.get_ascent(fs) - FONT.get_descent(fs)) * 0.5 - u * 0.5
		var tx: float = (w - tw) * 0.5
		for o in [Vector2(u, u), Vector2(-u, u), Vector2(0, u * 2.0)]:
			draw_string(FONT, Vector2(tx, base) + o, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_OUT)
		draw_string(FONT, Vector2(tx, base), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_GOLD)

	func _piece(c: Vector2, r: float, light: bool) -> void:
		var u: float = PX
		var face: Color = C_CREAM if light else C_PLUM_DK
		var face_sh: Color = C_CREAM_SH if light else Color("231a22")
		var rim: Color = Color("8f7f5c") if light else C_GOLD_SH
		var n: int = int(r / u)
		# espessura
		for y in range(-n, n + 1):
			for x in range(-n, n + 1):
				var d: float = Vector2(x, y - 1.5).length()
				if d <= float(n) + 0.5:
					_r(c + Vector2(x, y) * u - Vector2(u, u) * 0.5, Vector2(u, u), Color("161016") if d > n - 0.5 else Color("2a2029"))
		for y in range(-n, n + 1):
			for x in range(-n, n + 1):
				var d: float = Vector2(x, y).length()
				if d > float(n) + 0.5:
					continue
				var col: Color
				if d > n - 0.5:
					col = C_OUT
				elif d > n - 1.5:
					col = rim
				elif absf(d - n * 0.55) < 0.5:
					col = face_sh
				elif d > n * 0.55 and x + y > n * 0.6:
					col = face_sh
				else:
					col = face
				_r(c + Vector2(x, y) * u - Vector2(u, u) * 0.5, Vector2(u, u), col)
		_r(c + Vector2(-n * 0.45, -n * 0.55).round() * u - Vector2(u, u) * 0.5, Vector2(u, u), Color.WHITE if light else C_PLUM_LT)

# Palco atrás de uma opção: raios girando devagar na cor da raridade, um halo em
# degraus, sombra no chão e faíscas subindo. `power` sobe no hover.
class Halo extends Control:
	var color: Color = Color.WHITE
	var power: float = 0.0
	var rays: int = 10
	var _t: float = 0.0
	var _seed: float = 0.0
	const PX: float = 3.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_seed = randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var u: float = PX
		var c: Vector2 = size * 0.5
		var R: float = maxf(size.x, size.y) * 0.62
		var a0: float = 0.10 + 0.12 * power
		# raios (triângulos finos girando)
		for i in range(rays):
			var ang: float = _t * 0.18 + _seed + TAU * float(i) / float(rays)
			var half: float = 0.07 + 0.02 * sin(_t * 1.3 + float(i))
			var p1: Vector2 = c + Vector2(cos(ang - half), sin(ang - half)) * R
			var p2: Vector2 = c + Vector2(cos(ang + half), sin(ang + half)) * R
			draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(color, a0 * (0.6 if i % 2 == 0 else 1.0)))
		# halo em degraus (círculos concêntricos, sem gradiente suave)
		for k in range(4):
			var rr: float = size.x * (0.30 + 0.08 * float(k)) * (1.0 + 0.04 * power)
			draw_circle(c, rr, Color(color, (0.07 + 0.05 * power) * (1.0 - float(k) * 0.22)))
		# sombra no chão (elipse em blocos de pixel)
		var fy: float = size.y * 0.92
		for row in range(3):
			var half_w: float = size.x * (0.36 - 0.06 * float(row)) * (1.0 - 0.06 * power)
			_rect(Vector2(c.x - half_w, fy + float(row) * u), Vector2(half_w * 2.0, u), Color(0, 0, 0, 0.35 - 0.08 * float(row)))
		# faíscas subindo
		for i in range(7):
			var ph: float = fposmod(_t * (0.25 + 0.05 * float(i % 3)) + float(i) * 0.37 + _seed, 1.0)
			var x: float = c.x + sin(float(i) * 2.3 + _seed) * size.x * 0.42
			var y: float = size.y * (0.95 - ph * 0.9)
			var a: float = sin(ph * PI) * (0.5 + 0.5 * power)
			_rect(Vector2(x, y), Vector2(u, u), Color(color.lightened(0.4), a))
			if i % 3 == 0:
				_rect(Vector2(x - u, y), Vector2(u * 3.0, u), Color(color.lightened(0.4), a * 0.4))
				_rect(Vector2(x, y - u), Vector2(u, u * 3.0), Color(color.lightened(0.4), a * 0.4))

	func _rect(p: Vector2, s: Vector2, col: Color) -> void:
		draw_rect(Rect2(Vector2(floorf(p.x / PX) * PX, floorf(p.y / PX) * PX), s), col)

# Plaquinha da raridade: placa escura com uma gema na cor da raridade e o nome.
class RarityTag extends Control:
	var text: String = ""
	var color: Color = Color.WHITE
	var _t: float = 0.0
	const PX: float = 3.0

	func _ready() -> void:
		var tw: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		custom_minimum_size = Vector2(ceilf((tw + 24.0 * PX) / PX) * PX, 13.0 * PX)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var u: float = PX
		var w: float = size.x
		var h: float = 11.0 * u
		_rect(Vector2(u, 0), Vector2(w - u * 2.0, h), C_OUT)
		_rect(Vector2(0, u), Vector2(w, h - u * 2.0), C_OUT)
		_rect(Vector2(u, u), Vector2(w - u * 2.0, h - u * 2.0), Color(color.darkened(0.55)))
		_rect(Vector2(u, u), Vector2(w - u * 2.0, u), Color(color.darkened(0.25)))
		_rect(Vector2(0, h), Vector2(w, u * 2.0), Color(0, 0, 0, 0.35))
		# gema (losango) piscando
		var g := Vector2(5.0 * u, h * 0.5)
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
		for d in [Vector2(0, -2), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-2, 0), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2)]:
			var col: Color = color
			if d.y < 0 or (d.y == 0 and d.x < 0):
				col = color.lightened(0.35)
			if d == Vector2(-1, -1):
				col = Color(1, 1, 1, 0.6 + 0.4 * pulse)
			_rect(g + d * u - Vector2(u, u) * 0.5, Vector2(u, u), col)
		var base: float = h * 0.5 + (FONT.get_ascent(24) - FONT.get_descent(24)) * 0.5 - u * 0.3
		draw_string(FONT, Vector2(9.0 * u, base + u * 0.6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, C_OUT)
		draw_string(FONT, Vector2(9.0 * u, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, C_CREAM)

	func _rect(p: Vector2, s: Vector2, col: Color) -> void:
		draw_rect(Rect2(p.round(), s), col)

static func make_subtitle(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Color("d8ccb0"))
	l.add_theme_color_override("font_outline_color", C_OUT)
	l.add_theme_constant_override("outline_size", 6)
	return l

# Monta um "slot" de opção: plaquinha de raridade em cima, palco com o visual da
# opção no meio e o botão embaixo. Devolve {root, stage, halo, holder}.
static func make_slot(visual: Control, visual_size: Vector2, rarity_text: String, rarity_color: Color) -> Dictionary:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := RarityTag.new()
	tag.text = rarity_text
	tag.color = rarity_color
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(tag)
	var stage := Control.new()
	stage.custom_minimum_size = visual_size + Vector2(40, 36)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)
	var halo := Halo.new()
	halo.color = rarity_color
	halo.position = Vector2(-40, -30)
	halo.size = stage.custom_minimum_size + Vector2(80, 60)
	stage.add_child(halo)
	var holder := Control.new()
	holder.position = Vector2(20, 14)
	holder.size = visual_size
	holder.pivot_offset = visual_size * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(holder)
	holder.add_child(visual)
	return {"root": root, "stage": stage, "halo": halo, "holder": holder, "tag": tag}

# Hover no slot: a opção sobe e cresce um pouco e os raios acendem.
static func hook_hover(slot: Dictionary, hot: Control) -> void:
	var holder: Control = slot["holder"]
	var halo: Halo = slot["halo"]
	var base_y: float = holder.position.y
	var tw_ref: Array = [null]
	var go := func(on: bool):
		if tw_ref[0] != null and tw_ref[0].is_valid():
			tw_ref[0].kill()
		var tw := holder.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "position:y", base_y - (12.0 if on else 0.0), 0.18)
		tw.tween_property(holder, "scale", Vector2.ONE * (1.04 if on else 1.0), 0.18)
		tw.tween_property(halo, "power", 1.0 if on else 0.0, 0.2)
		tw_ref[0] = tw
	hot.mouse_entered.connect(func(): go.call(true))
	hot.mouse_exited.connect(func(): go.call(false))

# Entrada: o slot sobe do chão e a opção "vira" (escala horizontal 0 -> 1).
static func play_enter(slot: Dictionary, delay: float) -> void:
	var root: Control = slot["root"]
	var holder: Control = slot["holder"]
	root.modulate.a = 0.0
	holder.scale = Vector2(0.0, 1.0)
	var tw := root.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(root, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(holder, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Sfx.play("carta_virar"))
