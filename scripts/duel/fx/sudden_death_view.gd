class_name SuddenDeathView
extends CanvasLayer

# Visual da Morte Súbita: (1) aviso grande de início de fase e (2) o contador
# fixo no canto da tela (número grande, barrinhas de turnos, pulsa nos últimos).
# Quem manda nele é o SuddenDeathManager (set_state) e o main (play_intro).

const C_RED := Color(1.0, 0.33, 0.35)
const C_RED_DARK := Color(0.09, 0.015, 0.03)
const C_CREAM := Color(0.94, 0.9, 0.81)
const C_BLUE := Color(0.5, 0.78, 1.0)
const WARN_TURNS: int = 3

const EDGE_SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;   // 0..1
uniform float urgency = 0.0;     // 0..1 (nos últimos turnos)
uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.16, 1.0);
uniform vec2 pixels = vec2(480.0, 270.0);

void fragment() {
	// Pixeliza para combinar com a arte do jogo.
	vec2 uv = floor(UV * pixels) / pixels;
	vec2 aspect = vec2(1.0, pixels.y / pixels.x);
	float d = min(min(uv.x, 1.0 - uv.x) * 1.0, min(uv.y, 1.0 - uv.y) * 1.78);
	// Ondas que sobem das bordas em direção ao centro.
	float wob = sin(uv.y * 14.0 + TIME * 1.6) * 0.012 + sin(uv.x * 11.0 - TIME * 1.2) * 0.012;
	float dd = d + wob;
	float ripple = fract(dd * 7.0 - TIME * 0.28);
	float line = smoothstep(0.0, 0.08, ripple) * (1.0 - smoothstep(0.08, 0.26, ripple));
	// Vinheta: forte na borda, some até ~30% para dentro.
	float vig = 1.0 - smoothstep(0.0, 0.20, dd);
	float a = vig * 0.40;
	a += vig * line * 0.30;
	a = floor(a * 6.0) / 6.0;   // degraus (efeito "pixel")
	COLOR = vec4(tint.rgb, a * intensity);
}
"""

var _edge: ColorRect
var _edge_mat: ShaderMaterial
var _edge_tween: Tween
var _counter: Control
var _num_label: Label
var _title_label: Label
var _sub_label: Label
var _turns: int = 0
var _max: int = 1
var _paused: bool = false
var _active: bool = false
var _time: float = 0.0
var _intro_busy: bool = false

func _init() -> void:
	layer = 90
	_build_edge()
	_build_counter()
	_counter.visible = false

func _ready() -> void:
	set_process(true)

# ---------------------------------------------------------------------
# BORDAS (ondas vermelhas)
# ---------------------------------------------------------------------
func _build_edge() -> void:
	var shader := Shader.new()
	shader.code = EDGE_SHADER
	_edge_mat = ShaderMaterial.new()
	_edge_mat.shader = shader
	_edge_mat.set_shader_parameter("intensity", 0.0)
	_edge_mat.set_shader_parameter("urgency", 0.0)
	_edge = ColorRect.new()
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.material = _edge_mat
	_edge.visible = false
	# Camada própria, abaixo da HUD (80), para não cobrir cartas nem painéis.
	var edge_layer := CanvasLayer.new()
	edge_layer.layer = 70
	edge_layer.add_child(_edge)
	add_child(edge_layer)

func _update_edge(active: bool, paused: bool) -> void:
	var target: float = 0.0
	if active:
		target = 0.35 if paused else 1.0
	_edge_mat.set_shader_parameter("tint", Color(0.35, 0.65, 1.0) if paused else Color(1.0, 0.12, 0.16))
	if _edge_tween != null and _edge_tween.is_valid():
		_edge_tween.kill()
	if active:
		_edge.visible = true
	_edge_tween = create_tween().set_parallel(true)
	_edge_tween.tween_property(_edge_mat, "shader_parameter/intensity", target, 1.2 if active else 0.4)
	if not active:
		_edge_tween.chain().tween_callback(func(): _edge.visible = false)

# ---------------------------------------------------------------------
# CONTADOR
# ---------------------------------------------------------------------
func _build_counter() -> void:
	_counter = Control.new()
	_counter.position = Vector2(40.0, 10.0)
	_counter.size = Vector2(440.0, 100.0)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.draw.connect(_draw_counter)
	add_child(_counter)

	_num_label = Label.new()
	_num_label.position = Vector2(10.0, 10.0)
	_num_label.size = Vector2(80.0, 80.0)
	_num_label.pivot_offset = Vector2(40.0, 40.0)
	_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_num_label.add_theme_font_size_override("font_size", 72)
	_num_label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02))
	_num_label.add_theme_constant_override("outline_size", 8)
	_counter.add_child(_num_label)

	_title_label = Label.new()
	_title_label.position = Vector2(104.0, 8.0)
	_title_label.size = Vector2(320.0, 34.0)
	_title_label.text = "MORTE SÚBITA"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", C_RED)
	_title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02))
	_title_label.add_theme_constant_override("outline_size", 6)
	_counter.add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.position = Vector2(104.0, 40.0)
	_sub_label.size = Vector2(320.0, 24.0)
	_sub_label.add_theme_font_size_override("font_size", 20)
	_sub_label.add_theme_color_override("font_color", C_CREAM)
	_counter.add_child(_sub_label)

# Retângulo do contador na tela (o tutorial destaca essa área).
func get_counter_rect() -> Rect2:
	return Rect2(_counter.position, _counter.size)

# Chamado pelo manager sempre que algo muda.
func set_state(active: bool, turns_left: int, max_turns: int, paused: bool) -> void:
	var changed_turn: bool = active and _active and turns_left != _turns
	_active = active
	_turns = turns_left
	_max = maxi(1, max_turns)
	_paused = paused
	_counter.visible = active
	_refresh_texts()
	_update_edge(active, paused)
	if changed_turn:
		_pop_number()
	_counter.queue_redraw()

func _refresh_texts() -> void:
	_num_label.text = str(maxi(_turns, 0))
	_sub_label.text = "PAUSADA" if _paused else ("ÚLTIMO TURNO!" if _turns == 1 else "TURNOS RESTANTES")
	_num_label.add_theme_color_override("font_color", _num_color())
	_sub_label.add_theme_color_override("font_color", C_BLUE if _paused else (C_RED if _turns <= WARN_TURNS else C_CREAM))
	_title_label.add_theme_color_override("font_color", C_BLUE if _paused else C_RED)

func _num_color() -> Color:
	if _paused:
		return C_BLUE
	if _turns <= WARN_TURNS:
		return Color(1.0, 0.85, 0.8)
	return C_RED

func _pop_number() -> void:
	_num_label.scale = Vector2(1.7, 1.7)
	var tw := create_tween()
	tw.tween_property(_num_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_counter.queue_redraw()

func _draw_counter() -> void:
	var rect := Rect2(Vector2.ZERO, _counter.size)
	var urgent: bool = _turns <= WARN_TURNS and not _paused
	var speed: float = 9.0 if urgent else 3.0
	var pulse: float = 0.5 + 0.5 * sin(_time * speed)
	var edge: Color = C_BLUE if _paused else C_RED
	var bg := Color(0.04, 0.07, 0.12, 0.96) if _paused else C_RED_DARK
	if urgent:
		bg = bg.lerp(Color(0.32, 0.03, 0.06), pulse * 0.8)
	_counter.draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.45))
	_counter.draw_rect(rect, bg)
	_counter.draw_rect(rect, edge.darkened(0.25 + 0.2 * (1.0 - pulse)), false, 3.0)
	_counter.draw_rect(rect.grow(-6.0), edge.darkened(0.55), false, 1.0)
	PixelRenderer.draw_pixel_corners(_counter, rect, edge.lightened(0.25), 10.0, 3.0)
	# Caixa do número.
	var box := Rect2(8, 8, 84, 84)
	_counter.draw_rect(box, Color(0, 0, 0, 0.45))
	_counter.draw_rect(box, edge.darkened(0.3), false, 2.0)
	# Barrinhas: uma por turno do total; as que restam ficam acesas.
	var n: int = mini(_max, 16)
	var gap: float = 4.0
	var area_w: float = 316.0
	var pw: float = minf(26.0, (area_w - gap * float(n - 1)) / float(n))
	var x0: float = 104.0
	for i in range(n):
		var lit: bool = i < _turns
		var r := Rect2(x0 + float(i) * (pw + gap), 74.0, pw, 14.0)
		if lit:
			var c: Color = edge
			if urgent:
				c = edge.lerp(Color(1, 0.85, 0.8), pulse * 0.6)
			_counter.draw_rect(r, c)
			_counter.draw_rect(Rect2(r.position, Vector2(r.size.x, 4.0)), c.lightened(0.35))
		else:
			_counter.draw_rect(r, Color(0.2, 0.08, 0.1, 0.8))
		_counter.draw_rect(r, Color(0.04, 0.0, 0.02), false, 1.0)

# ---------------------------------------------------------------------
# AVISO DE INÍCIO
# ---------------------------------------------------------------------
# Faixa vermelha cruzando a tela com "MORTE SÚBITA". `stall`: começou por
# impasse (ninguém avançava). Bloqueia cliques e some sozinho (~3 s).
func play_intro(_turns: int = 0, _stall: bool = false, shake_node: Node = null) -> void:
	if _intro_busy:
		return
	_intro_busy = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.2, 0.0, 0.03, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)

	var vp: Vector2 = root.get_viewport().get_visible_rect().size
	var band_h: float = 190.0
	var band := Control.new()
	band.position = Vector2(0.0, (vp.y - band_h) / 2.0)
	band.size = Vector2(vp.x, band_h)
	band.pivot_offset = Vector2(vp.x / 2.0, band_h / 2.0)
	band.scale = Vector2(1.0, 0.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)

	var fill := ColorRect.new()
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.color = Color(0.1, 0.01, 0.03, 0.94)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(fill)
	for top in [true, false]:
		var line := ColorRect.new()
		line.color = C_RED
		line.size = Vector2(vp.x, 6.0)
		line.position = Vector2(0.0, 0.0 if top else band_h - 6.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(line)
		var line2 := ColorRect.new()
		line2.color = Color(1.0, 0.75, 0.3)
		line2.size = Vector2(vp.x, 2.0)
		line2.position = Vector2(0.0, 10.0 if top else band_h - 12.0)
		line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(line2)

	var word := Label.new()
	word.text = "MORTE SÚBITA"
	word.set_anchors_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 128)
	word.add_theme_color_override("font_color", C_RED)
	word.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02))
	word.add_theme_constant_override("outline_size", 18)
	word.modulate.a = 0.0
	band.add_child(word)

	await get_tree().process_frame
	word.pivot_offset = word.size / 2.0
	word.scale = Vector2(1.5, 1.5)

	# Entrada rápida: a faixa abre e a palavra "bate" na tela.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(tint, "color:a", 0.35, 0.12)
	tw.tween_property(band, "scale:y", 1.0, 0.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(word, "modulate:a", 1.0, 0.06).set_delay(0.06)
	tw.tween_property(word, "scale", Vector2.ONE, 0.14).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.16).timeout
	if shake_node != null:
		Juice.shake(shake_node, 12.0, 0.25)
	await tw.finished
	await get_tree().create_timer(0.7).timeout

	var out := create_tween().set_parallel(true)
	out.tween_property(tint, "color:a", 0.0, 0.18)
	out.tween_property(band, "scale:y", 0.0, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	out.tween_property(word, "modulate:a", 0.0, 0.1)
	await out.finished
	root.queue_free()
	_intro_busy = false
	# O contador entra com um "tapa" depois que a faixa some.
	_pop_number()
