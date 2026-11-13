class_name TransformReveal
extends Control

## Cena de "transformação" de carta/Lei (forja, troca do caçador/nômade/mineiro,
## Lei reescrita pelo monge/escriba). Em vez de ANTES → DEPOIS parados, a carta
## antiga aparece grande no centro, passa pelo "trabalho" (marteladas, giro, tinta),
## vira de costas e volta já como a nova, numa explosão de pixels da cor da raridade.
## No fim, a antiga encolhe para a esquerda (apagada) e a nova fica em destaque.
##
## kind: "forge" | "swap" | "law"

const OLD_FINAL_SCALE: float = 0.62
const GAP: float = 96.0
const LABEL_H: float = 40.0
const PX: float = 4.0

var _old: Control
var _new: Control
var _old_holder := Control.new()
var _new_holder := Control.new()
var _old_label := Label.new()
var _new_label := Label.new()
var _kind: String
var _accent: Color
var _parts: Array = []           # {p, v, life, max, col, s, g}
var _flash: float = 0.0          # clarão branco sobre a carta (marteladas, virada)
var _arrow_a: float = 0.0
var _glow: float = 0.0           # brilho pulsante atrás da nova
var _t: float = 0.0
var _panel_a: float = 0.0
var _osz: Vector2
var _nsz: Vector2
var _center_x: float

func _init(old_visual: Control, new_visual: Control, kind: String, accent: Color, old_caption: String, new_caption: String) -> void:
	_old = old_visual
	_new = new_visual
	_kind = kind
	_accent = accent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_osz = old_visual.custom_minimum_size
	_nsz = new_visual.custom_minimum_size
	var w: float = _osz.x * OLD_FINAL_SCALE + GAP + _nsz.x
	var h: float = maxf(_osz.y, _nsz.y) + LABEL_H
	custom_minimum_size = Vector2(w, h)
	_center_x = w - _nsz.x / 2.0
	for pair in [[_old_holder, _old, _osz], [_new_holder, _new, _nsz]]:
		var hd: Control = pair[0]
		hd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hd.size = pair[2]
		hd.pivot_offset = pair[2] / 2.0
		add_child(hd)
		hd.add_child(pair[1])
		(pair[1] as Control).position = Vector2.ZERO
	for pair in [[_old_label, old_caption, Color(0.94, 0.62, 0.62)], [_new_label, new_caption, Color(1.0, 0.86, 0.38)]]:
		var l: Label = pair[0]
		l.text = pair[1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", pair[2])
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.08))
		l.add_theme_constant_override("outline_size", 6)
		l.size = Vector2(320, LABEL_H)
		l.modulate.a = 0.0
		add_child(l)
	# começa: a antiga no centro (onde a nova vai ficar), a nova escondida
	_old_holder.position = Vector2(_center_x - _osz.x / 2.0, LABEL_H)
	_new_holder.position = Vector2(_center_x - _nsz.x / 2.0, LABEL_H)
	_new_holder.visible = false
	_old_holder.scale = Vector2(0.85, 0.85)
	_old_holder.modulate.a = 0.0

var _started: bool = false

func _ready() -> void:
	# só começa quando aparece de fato (o EventView mostra a prévia depois da cena)
	if is_visible_in_tree():
		_start()
	else:
		visibility_changed.connect(func():
			if is_visible_in_tree():
				_start())

func _start() -> void:
	if _started:
		return
	_started = true
	_play()

## Pula direto para o estado final (testes / animações desligadas).
func finish_now() -> void:
	_started = true
	_final_layout(0.0)
	_new_holder.visible = true
	_old_holder.visible = true
	_new_holder.scale = Vector2.ONE

func _play() -> void:
	var tw := create_tween()
	# 1) a antiga surge no centro
	tw.tween_property(_old_holder, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(_old_holder, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	await tw.finished
	if not is_inside_tree():
		return
	# 2) o trabalho
	match _kind:
		"forge":
			for i in range(3):
				await _hit(Color(1.0, 0.62, 0.22))
		"law":
			await _ink()
		_:
			await _spin()
	if not is_inside_tree():
		return
	# 3) vira de costas e volta como a nova
	var t2 := create_tween()
	t2.tween_property(_old_holder, "scale", Vector2(0.0, 1.06), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t2.finished
	_old_holder.visible = false
	_new_holder.visible = true
	_new_holder.scale = Vector2(0.0, 1.06)
	_flash = 1.0
	_burst(_center(_new_holder), _accent, 46, 520.0)
	_ring(_center(_new_holder), _accent)
	Sfx.play("item")
	var t3 := create_tween()
	t3.tween_property(_new_holder, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t3.tween_property(_new_holder, "scale", Vector2.ONE, 0.14)
	await t3.finished
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	# 4) a antiga volta pequena e apagada à esquerda, a seta aparece
	_old_holder.visible = true
	_old_holder.modulate = Color(0.75, 0.68, 0.72, 0.0)
	_final_layout(0.45)

func _final_layout(dur: float) -> void:
	var osc: float = OLD_FINAL_SCALE
	var oy: float = LABEL_H + (maxf(_osz.y, _nsz.y) - _osz.y) / 2.0
	var opos := Vector2(_osz.x * osc / 2.0 - _osz.x / 2.0, oy)
	if dur <= 0.0:
		_old_holder.position = opos
		_old_holder.scale = Vector2(osc, osc)
		_old_holder.modulate = Color(0.75, 0.68, 0.72, 0.8)
		_arrow_a = 1.0
		_place_labels(1.0)
		return
	_old_holder.position = Vector2(_center_x - _osz.x / 2.0, oy)
	_old_holder.scale = Vector2(osc * 1.2, osc * 1.2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_old_holder, "position", opos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_old_holder, "scale", Vector2(osc, osc), dur)
	tw.tween_property(_old_holder, "modulate", Color(0.75, 0.68, 0.72, 0.8), dur)
	tw.tween_property(self, "_arrow_a", 1.0, dur)
	tw.tween_method(_place_labels, 0.0, 1.0, dur)

func _place_labels(a: float) -> void:
	var oc: float = _osz.x * OLD_FINAL_SCALE / 2.0
	var oy: float = LABEL_H + (maxf(_osz.y, _nsz.y) - _osz.y * OLD_FINAL_SCALE) / 2.0 - LABEL_H
	_old_label.position = Vector2(oc - 160.0, oy)
	_new_label.position = Vector2(_center_x - 160.0, 0.0)
	_old_label.modulate.a = a
	_new_label.modulate.a = a

func _center(c: Control) -> Vector2:
	return c.position + c.size / 2.0

# Martelada: amassa, clareia, faísca.
func _hit(spark: Color) -> void:
	var tw := create_tween()
	tw.tween_property(_old_holder, "scale", Vector2(1.08, 0.9), 0.06)
	tw.tween_property(_old_holder, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash = 0.8
	var c := _center(_old_holder) + Vector2(randf_range(-30, 30), -_osz.y * 0.25)
	_burst(c, spark, 16, 360.0)
	Sfx.play("bloqueio", -4.0)
	await tw.finished
	await get_tree().create_timer(0.12).timeout

# Troca: gira duas vezes no ar, cada vez mais rápido.
func _spin() -> void:
	for d in [0.16, 0.11]:
		var tw := create_tween()
		tw.tween_property(_old_holder, "scale", Vector2(0.0, 1.0), d)
		tw.tween_property(_old_holder, "scale", Vector2.ONE, d)
		_burst(_center(_old_holder), Color(0.85, 0.9, 1.0), 10, 260.0)
		Sfx.play("carta_virar", -2.0)
		await tw.finished
	await get_tree().create_timer(0.08).timeout

# Lei reescrita: a tinta sobe e a carta escurece antes de virar.
func _ink() -> void:
	var tw := create_tween()
	tw.tween_property(_old_holder, "modulate", Color(0.55, 0.45, 0.65), 0.55)
	for i in range(4):
		var c := _center(_old_holder) + Vector2(randf_range(-_osz.x * 0.4, _osz.x * 0.4), _osz.y * 0.3)
		for k in range(8):
			_parts.append({"p": c + Vector2(randf_range(-12, 12), 0), "v": Vector2(randf_range(-20, 20), randf_range(-160, -60)),
				"life": 0.9, "max": 0.9, "col": Color(0.42, 0.28, 0.62), "s": PX * float(1 + randi() % 2), "g": -40.0})
		await get_tree().create_timer(0.14).timeout
	Sfx.play("lei", -2.0)
	if tw.is_running():
		await tw.finished

func _burst(at: Vector2, col: Color, n: int, spd: float) -> void:
	for i in range(n):
		var ang: float = randf() * TAU
		var v := Vector2(cos(ang), sin(ang)) * randf_range(spd * 0.35, spd)
		_parts.append({"p": at, "v": v, "life": randf_range(0.45, 0.9), "max": 0.9,
			"col": col.lerp(Color.WHITE, randf() * 0.45), "s": PX * float(1 + randi() % 2), "g": 380.0})

# Anel de pixels que se abre em volta da carta nova.
func _ring(at: Vector2, col: Color) -> void:
	for i in range(28):
		var ang: float = TAU * float(i) / 28.0
		_parts.append({"p": at, "v": Vector2(cos(ang), sin(ang)) * 330.0, "life": 0.55, "max": 0.55,
			"col": col.lerp(Color.WHITE, 0.3), "s": PX, "g": 0.0})

func _process(delta: float) -> void:
	_t += delta
	if _started:
		_panel_a = minf(_panel_a + delta * 5.0, 1.0)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	if _new_holder.visible:
		_glow = minf(_glow + delta * 2.0, 1.0)
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_parts.remove_at(i)
			continue
		p["v"] = (p["v"] as Vector2) * pow(0.12, delta) + Vector2(0, float(p["g"])) * delta
		p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * delta
	queue_redraw()

func _draw() -> void:
	# painel escuro atrás de tudo, com borda creme (separa a carta do cenário)
	var pad := Vector2(44, 30)
	var pr := Rect2(-pad, size + pad * 2.0)
	draw_rect(pr.grow(PX), Color(0.89, 0.85, 0.74, 0.9 * _panel_a))
	draw_rect(pr, Color(0.11, 0.08, 0.11, 0.88 * _panel_a))
	draw_rect(Rect2(pr.position + Vector2(PX, PX), Vector2(pr.size.x - PX * 2.0, PX)), Color(0.29, 0.23, 0.27, _panel_a))
	# brilho em degraus atrás da carta nova (quadrados concêntricos, sem gradiente suave)
	if _new_holder.visible and _glow > 0.0:
		var c: Vector2 = _center(_new_holder)
		var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
		for k in range(3):
			var g: float = (8.0 + 10.0 * float(k)) * (0.9 + 0.1 * pulse)
			var r := Rect2(c - _nsz * _new_holder.scale / 2.0 - Vector2(g, g), _nsz * _new_holder.scale + Vector2(g, g) * 2.0)
			var col := _accent
			col.a = (0.16 - 0.045 * float(k)) * _glow
			draw_rect(Rect2(r.position.snapped(Vector2(PX, PX)), r.size.snapped(Vector2(PX, PX))), col)
	# seta em degraus entre a antiga e a nova
	if _arrow_a > 0.0:
		var ax: float = _osz.x * OLD_FINAL_SCALE + GAP / 2.0 - 18.0 + roundf(sin(_t * 4.0) * 1.5) * PX
		var ay: float = LABEL_H + maxf(_osz.y, _nsz.y) / 2.0
		var ac := Color(1.0, 0.82, 0.32, _arrow_a)
		var dark := Color(0.1, 0.06, 0.1, _arrow_a)
		_draw_arrow(Vector2(ax + PX, ay + PX), dark)
		_draw_arrow(Vector2(ax, ay), ac)
	# partículas
	for p in _parts:
		var a: float = clampf(float(p["life"]) / float(p["max"]) * 1.6, 0.0, 1.0)
		var col2: Color = p["col"]
		col2.a *= a
		var s: float = float(p["s"])
		draw_rect(Rect2(((p["p"] as Vector2) - Vector2(s, s) / 2.0).snapped(Vector2(PX, PX)), Vector2(s, s)), col2)
	# clarão sobre a carta (marteladas / virada)
	if _flash > 0.0:
		var hd: Control = _new_holder if _new_holder.visible else _old_holder
		var sz: Vector2 = hd.size * hd.scale
		draw_rect(Rect2(_center(hd) - sz / 2.0, sz), Color(1, 1, 1, 0.45 * _flash))

func _draw_arrow(o: Vector2, c: Color) -> void:
	draw_rect(Rect2(o + Vector2(0, -PX * 1.5), Vector2(PX * 6, PX * 3)), c)
	for i in range(5):
		var h: float = PX * float(9 - i * 2)
		draw_rect(Rect2(o + Vector2(PX * float(6 + i), -h / 2.0), Vector2(PX, h)), c)
