class_name BossBanterView
extends CanvasLayer
# O Chefe "fala" durante o duelo: um rostinho no canto (mesmo formato do Guia e
# do Irmão: tira de 8 quadros 32x32, boca mexendo) com um balão de fala que
# aparece digitando. As falas e a personalidade vivem em BossDialogue.
#
# react(evento) escolhe uma fala do evento respeitando um ritmo: falas
# importantes (início/fim) sempre saem e interrompem; as comuns têm chance e
# tempo mínimo entre si, para o chefe não virar um papagaio.
#
# Sprite próprio do chefe: assets/sprites/guide/boss_<bioma>_talk.png (tira de
# 8 quadros 32x32). Sem ele, usa o rosto do Irmão tingido com a cor do bioma.

const FACE_PX: float = 104.0
const BUBBLE_W: float = 425.0
const FONT_SIZE: int = 32
const BUBBLE_H: float = 210.0   # altura do balão (até 4 linhas)
const TYPE_CPS: float = 38.0       # caracteres por segundo
const ALWAYS := ["start", "win", "lose"]

var biome: String = "floresta"
var law_id: String = ""
var enabled: bool = true

var _root: Control
var _face: GuideFaceControl
var _bubble: PanelContainer
var _label: Label
var _name_label: Label
var _hide_tween: Tween
var _type_tween: Tween
var _last_line: String = ""
var _last_time_ms: int = -100000
var _busy_until_ms: int = 0
var _intro_fx: IntroFx = null
var _big_face: GuideFaceControl = null
var _big_title: Label = null
var intro_playing: bool = false

const BIG_PX: float = 352.0   # 11x o sprite de 32 px (pixels inteiros)

# Camada de efeitos da entrada do chefe (escurecer, clarão, onda de choque, brasas).
class IntroFx extends Control:
	var dim: float = 0.0
	var flash: float = 0.0
	var ring_t: float = -1.0
	var tint: Color = Color.WHITE
	var embers: Array = []
	var center: Vector2 = Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia cliques durante a entrada
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func burst(n: int) -> void:
		for i in range(n):
			var a: float = randf() * TAU
			embers.append({"p": center + Vector2(randf_range(-60, 60), randf_range(-60, 60)),
				"v": Vector2.from_angle(a) * randf_range(250.0, 1000.0), "life": randf_range(0.8, 1.9),
				"max": 1.9, "sz": randf_range(4.0, 11.0)})

	func _process(delta: float) -> void:
		flash = maxf(0.0, flash - delta * 2.2)
		for e in embers:
			e["p"] += e["v"] * delta
			e["v"] *= (1.0 - 1.8 * delta)
			e["v"].y -= 60.0 * delta
			e["life"] -= delta
		embers = embers.filter(func(e): return e["life"] > 0.0)
		queue_redraw()

	func _draw() -> void:
		var vp: Vector2 = get_viewport_rect().size
		if dim > 0.0:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.0, 0.03, 0.72 * dim))
			draw_rect(Rect2(Vector2.ZERO, vp), Color(tint, 0.10 * dim))
		if ring_t >= 0.0:
			var k: float = clampf(ring_t, 0.0, 1.0)
			draw_arc(center, 60.0 + k * 1100.0, 0.0, TAU, 96, Color(tint.lightened(0.4), (1.0 - k) * 0.9), 26.0 * (1.0 - k) + 3.0)
			draw_arc(center, 30.0 + k * 800.0, 0.0, TAU, 96, Color(1, 1, 1, (1.0 - k) * 0.6), 8.0 * (1.0 - k) + 2.0)
		for e in embers:
			var a: float = clampf(float(e["life"]) / float(e["max"]), 0.0, 1.0)
			var sz: float = float(e["sz"]) * (0.4 + 0.6 * a)
			draw_rect(Rect2(e["p"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(tint.lightened(0.35), a))
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, flash * 0.75))

func setup(p_biome: String, p_law_id: String = "") -> void:
	biome = p_biome
	law_id = p_law_id
	layer = 105   # acima do modal de fim de duelo (100)
	_build()

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 0.0   # só aparece depois da entrada (play_intro)
	frame.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.08, 0.06, 0.1, 0.95), BossDialogue.boss_tint(biome), 8))
	_root.add_child(frame)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 2)
	frame.add_child(fv)
	_face = GuideFaceControl.new()
	_face.fallback_tint = BossDialogue.boss_tint(biome)
	_face.setup(FACE_PX, "boss_" + biome)
	fv.add_child(_face)
	_name_label = Label.new()
	_name_label.text = BossDialogue.boss_name(biome)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", BossDialogue.boss_tint(biome))
	_name_label.custom_minimum_size = Vector2(FACE_PX, 0)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fv.add_child(_name_label)

	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", PixelUI.make_dialogue_panel(BossDialogue.boss_tint(biome), 14, 4))
	_bubble.custom_minimum_size = Vector2(BUBBLE_W, 0)
	_bubble.visible = false
	_root.add_child(_bubble)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color("#efe6cf"))
	_label.custom_minimum_size = Vector2(BUBBLE_W - 28.0, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bubble.add_child(_label)

# Entrada dramática (como a do Irmão do Guia): a tela escurece, o rosto do chefe
# SE CHOCA no centro com clarão, onda de choque, brasas e tremor, o nome aparece
# em letreiro gigante e o rosto encolhe voando até o cantinho. Só depois ele fala.
# Bloqueia cliques enquanto dura (~3,3 s). `await` devolve quando termina.
func play_intro() -> void:
	if _root == null or intro_playing:
		return
	intro_playing = true
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tint: Color = BossDialogue.boss_tint(biome)
	var frame: Control = _root.get_node("Frame")
	var slot: Vector2 = _face.get_global_rect().get_center()
	var slot_scale: float = FACE_PX / BIG_PX
	frame.modulate.a = 0.0

	_intro_fx = IntroFx.new()
	_intro_fx.tint = tint
	_intro_fx.center = vp / 2.0 + Vector2(0.0, -40.0)
	_root.add_child(_intro_fx)

	_big_face = GuideFaceControl.new()
	_big_face.fallback_tint = tint
	_big_face.setup(BIG_PX, "boss_" + biome)
	_big_face.pivot_offset = Vector2(BIG_PX, BIG_PX) / 2.0
	_big_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_face.scale = Vector2(0.05, 0.05)
	var base_pos: Vector2 = _intro_fx.center - Vector2(BIG_PX, BIG_PX) / 2.0
	_big_face.position = base_pos
	_root.add_child(_big_face)

	_big_title = Label.new()
	_big_title.text = BossDialogue.boss_name(biome)
	_big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_title.add_theme_font_size_override("font_size", 64)
	_big_title.add_theme_color_override("font_color", tint.lightened(0.15))
	_big_title.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.08))
	_big_title.add_theme_constant_override("outline_size", 14)
	_big_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big_title.size = Vector2(vp.x, 80.0)
	_big_title.position = Vector2(0.0, _intro_fx.center.y + BIG_PX / 2.0 + 24.0)
	_big_title.pivot_offset = Vector2(vp.x / 2.0, 40.0)
	_big_title.modulate.a = 0.0
	_root.add_child(_big_title)

	# 1) Escurece com um tremor de pressentimento.
	var t1 := create_tween()
	t1.tween_property(_intro_fx, "dim", 1.0, 0.35)
	await t1.finished

	# 2) Impacto: o rosto cresce com tranco; clarão, onda de choque, brasas.
	var t2 := create_tween()
	t2.tween_property(_big_face, "scale", Vector2(1.12, 1.12), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t2.tween_property(_big_face, "scale", Vector2.ONE, 0.12)
	await get_tree().create_timer(0.2).timeout
	_intro_fx.flash = 1.0
	_intro_fx.ring_t = 0.0
	_intro_fx.burst(80)
	create_tween().tween_property(_intro_fx, "ring_t", 1.0, 0.8)
	_big_title.scale = Vector2(1.5, 1.5)
	var t3 := create_tween().set_parallel(true)
	t3.tween_property(_big_title, "modulate:a", 1.0, 0.15)
	t3.tween_property(_big_title, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# (rosto parado durante a entrada: sem animação de fala)

	# Tremor que vai acalmando (só o rosto e o letreiro).
	var shake: float = 26.0
	var elapsed: float = 0.0
	var hold: float = 1.5
	while elapsed < hold:
		var dt: float = get_process_delta_time()
		elapsed += dt
		shake = maxf(0.0, shake - 40.0 * dt)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).round() * shake
		_big_face.position = base_pos + off
		_big_title.position.x = off.x * 0.6
		await get_tree().process_frame
	_big_face.position = base_pos
	_big_title.position.x = 0.0
	_big_face.talking = false

	# 3) Encolhe voando até o cantinho; o resto da tela volta ao normal.
	var t4 := create_tween().set_parallel(true)
	t4.tween_property(_big_face, "scale", Vector2(slot_scale, slot_scale), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t4.tween_property(_big_face, "position", slot - Vector2(BIG_PX, BIG_PX) / 2.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t4.tween_property(_big_title, "modulate:a", 0.0, 0.3)
	t4.tween_property(_intro_fx, "dim", 0.0, 0.45)
	await t4.finished

	# 4) Pousa com tranco; o quadrinho aparece.
	frame.modulate.a = 1.0
	frame.pivot_offset = frame.size / 2.0
	frame.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(frame, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_fx.flash = 0.35
	_big_face.queue_free()
	_big_title.queue_free()
	await get_tree().create_timer(0.3).timeout
	_intro_fx.queue_free()
	intro_playing = false

# Posiciona na coluna da direita, logo abaixo do quadro de Leis do inimigo:
# espaço livre, grande e no campo de visão. Balão em cima (largura do quadro),
# rosto embaixo. Chame depois do layout assentar.
func place_near(ref: Control) -> void:
	var r: Rect2 = ref.get_global_rect()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var w: float = maxf(r.size.x, 340.0)
	var frame: Control = _root.get_node("Frame")
	var fw: float = FACE_PX + 28.0
	var bw: float = w - fw - 10.0
	var y0: float = minf(r.end.y + 12.0, vp.y - BUBBLE_H - 8.0)
	_bubble.custom_minimum_size = Vector2(bw, BUBBLE_H)
	_label.custom_minimum_size = Vector2(bw - 40.0, 0)
	_bubble.size = Vector2(bw, BUBBLE_H)
	_bubble.position = Vector2(r.position.x + fw + 10.0, y0)
	frame.position = Vector2(r.position.x, y0 + BUBBLE_H - frame.size.y)

# Pronuncia um evento (com ritmo). `force` ignora chance e tempo mínimo.
func react(event: String, force: bool = false) -> void:
	if not enabled or _root == null or intro_playing:
		return
	var always: bool = ALWAYS.has(event)
	var now: int = Time.get_ticks_msec()
	if not always and not force:
		if now < _busy_until_ms:
			return
		var chance: float = 0.6 if event.begins_with("law_") else 0.38
		if now - _last_time_ms < (6000 if event.begins_with("law_") else 9000):
			return
		if randf() > chance:
			return
	var line: String = BossDialogue.pick(biome, event, law_id, _last_line)
	if line == "":
		return
	say(line)

func say(text: String) -> void:
	var fr0: Control = _root.get_node("Frame")
	if fr0.modulate.a < 1.0 and not intro_playing:
		fr0.modulate.a = 1.0
	_last_line = text
	_last_time_ms = Time.get_ticks_msec()
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_label.text = text
	_label.visible_characters = 0
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bubble.pivot_offset = Vector2(0.0, BUBBLE_H * 0.5)
	_bubble.scale = Vector2(0.8, 0.8)
	var pop := create_tween()
	pop.tween_property(_bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_face.talking = true
	var fr: Control = _root.get_node("Frame")
	fr.pivot_offset = fr.size / 2.0
	fr.scale = Vector2(1.12, 1.12)
	create_tween().tween_property(fr, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var type_t: float = float(text.length()) / TYPE_CPS
	_type_tween = create_tween()
	_type_tween.tween_property(_label, "visible_characters", text.length(), type_t)
	_type_tween.tween_callback(func(): _face.talking = false)
	var hold: float = maxf(3.2, 1.8 + 0.05 * float(text.length()))
	_busy_until_ms = Time.get_ticks_msec() + int((type_t + hold) * 1000.0)
	_hide_tween = create_tween()
	_hide_tween.tween_interval(type_t + hold)
	_hide_tween.tween_property(_bubble, "modulate:a", 0.0, 0.3)
	_hide_tween.tween_callback(func(): _bubble.visible = false)
