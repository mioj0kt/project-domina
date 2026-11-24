class_name Juice
extends RefCounted

# Biblioteca estática de "game juice" (feedback visual): hover/clique em
# controles, pulso, partículas pixel, texto flutuante, screen shake e hit-stop.
# Tudo é opcional e seguro: se o alvo for liberado no meio, o tween morre junto.
# Juice.screen_fx = false desliga os efeitos fortes (shake/hit-stop); fica sempre
# ligado no jogo (a opção foi tirada das configurações), sobra só para testes.

const C_GOLD := Color("#d9a441")
const C_CREAM := Color("#efe6cf")

static var screen_fx: bool = true      # shake + hit-stop
static var _hit_stop_active: bool = false

# ---------------------------------------------------------------
# Controles (botões, nós do mapa, painéis)
# ---------------------------------------------------------------

# Cresce no hover, encolhe ao pressionar e volta com um pequeno "estalo".
static func hover_pop(ctrl: Control, hover_scale: float = 1.05, press_scale: float = 0.95) -> void:
	if ctrl == null or ctrl.has_meta("juice_hover"):
		return
	ctrl.set_meta("juice_hover", true)
	var go := func(target: float, t: float, trans: int):
		if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
			return
		if (ctrl is BaseButton and (ctrl as BaseButton).disabled) or ctrl.has_meta("slab"):
			target = 1.0   # placas com encaixe (SlabStyleBox) não crescem: a peça já marca a escolha
		ctrl.pivot_offset = ctrl.size / 2.0
		var old: Tween = ctrl.get_meta("juice_tween") if ctrl.has_meta("juice_tween") else null
		if old != null and old.is_valid():
			old.kill()
		var tw := ctrl.create_tween()
		tw.tween_property(ctrl, "scale", Vector2(target, target), t).set_trans(trans).set_ease(Tween.EASE_OUT)
		ctrl.set_meta("juice_tween", tw)
	ctrl.mouse_entered.connect(func(): go.call(hover_scale, 0.12, Tween.TRANS_BACK))
	ctrl.mouse_exited.connect(func(): go.call(1.0, 0.1, Tween.TRANS_SINE))
	if ctrl is BaseButton:
		var b := ctrl as BaseButton
		b.button_down.connect(func(): go.call(press_scale, 0.06, Tween.TRANS_SINE))
		b.button_up.connect(func(): go.call(hover_scale if b.is_hovered() else 1.0, 0.14, Tween.TRANS_BACK))

# Pulso rápido (escala sobe e volta) — para "acabou de mudar".
static func pulse(ctrl: Control, amount: float = 1.2, t: float = 0.22) -> void:
	if ctrl == null or not ctrl.is_inside_tree():
		return
	ctrl.pivot_offset = ctrl.size / 2.0
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "scale", Vector2(amount, amount), t * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ctrl, "scale", Vector2.ONE, t * 0.65).set_trans(Tween.TRANS_SINE)

# Pisca a cor do texto/modulate e volta.
static func flash_modulate(node: CanvasItem, color: Color, t: float = 0.3) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base: Color = node.modulate
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", base, t).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------
# Partículas pixel (quadradinhos, sem textura)
# ---------------------------------------------------------------

# Explosão one-shot de quadradinhos em `global_pos`. `parent` é qualquer nó
# da cena (a partícula se libera sozinha).
static func burst(parent: Node, global_pos: Vector2, color: Color = C_GOLD, count: int = 14,
		speed: float = 180.0, life: float = 0.55, px: float = 4.0, gravity: float = 380.0,
		spread_deg: float = 180.0, dir: Vector2 = Vector2.UP) -> CPUParticles2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := CPUParticles2D.new()
	p.top_level = true
	p.z_index = 400
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.direction = dir
	p.spread = spread_deg
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = px
	p.scale_amount_max = px * 1.6
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(p)
	p.global_position = global_pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

# Nuvenzinha de poeira ao pousar: quadrados cremes que sobem pouco e caem.
static func dust(parent: Node, global_pos: Vector2, cell: float = 64.0) -> void:
	burst(parent, global_pos + Vector2(0, cell * 0.28), Color(0.80, 0.74, 0.62, 0.9), 7,
		cell * 1.1, 0.4, maxf(3.0, cell / 18.0), 60.0, 160.0, Vector2.UP)

# Fagulhas douradas (carta jogada, lei ratificada).
static func sparkle(parent: Node, global_pos: Vector2, count: int = 22) -> void:
	burst(parent, global_pos, C_GOLD, count, 260.0, 0.7, 4.0, 220.0, 180.0)
	burst(parent, global_pos, C_CREAM, int(count / 2.0), 180.0, 0.5, 3.0, 160.0, 180.0)

# Anel de impacto que se expande e some (onda de choque pixelada: sem
# anti-aliasing, traço grosso). `radius` é o raio final em px.
static func ring(parent: Node, global_pos: Vector2, radius: float = 40.0, color: Color = C_CREAM,
		width: float = 5.0, dur: float = 0.28) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var r := _RingFx.new()
	r.top_level = true
	r.z_index = 390
	r.color = color
	r.width = width
	parent.add_child(r)
	r.global_position = global_pos
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "radius", radius, dur).from(radius * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "alpha", 0.0, dur).from(1.0).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(r.queue_free)

class _RingFx extends Node2D:
	var radius: float = 10.0:
		set(v):
			radius = v
			queue_redraw()
	var alpha: float = 1.0:
		set(v):
			alpha = v
			queue_redraw()
	var color: Color = Color.WHITE
	var width: float = 4.0
	func _draw() -> void:
		var c := color
		c.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, c, width, false)

# Clarão rápido quadrado sobre uma casa (impacto de captura).
static func flash_square(parent: Node, global_center: Vector2, size_px: float, color: Color = Color(1, 0.95, 0.8, 0.7), dur: float = 0.14) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var cr := ColorRect.new()
	cr.top_level = true
	cr.z_index = 380
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.color = color
	cr.size = Vector2(size_px, size_px)
	parent.add_child(cr)
	cr.global_position = global_center - cr.size / 2.0
	var tw := cr.create_tween()
	tw.tween_property(cr, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(cr.queue_free)

# ---------------------------------------------------------------
# Texto flutuante ("+10", "-5")
# ---------------------------------------------------------------
static func float_text(parent: Node, text: String, global_pos: Vector2, color: Color = C_GOLD,
		font_size: int = 30, rise: float = 46.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.top_level = true
	l.z_index = 450
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.12))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	l.global_position = global_pos
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", global_pos.y - rise, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

# ---------------------------------------------------------------
# Tela: shake e hit-stop
# ---------------------------------------------------------------

# Balança `node` (Node2D ou Control) por `dur` s, com força decrescente.
static func shake(node: Node, strength: float = 6.0, dur: float = 0.22) -> void:
	if not screen_fx or node == null or not node.is_inside_tree():
		return
	if not (node is Node2D or node is Control):
		return
	if not node.has_meta("juice_base_pos"):
		node.set_meta("juice_base_pos", node.get("position"))
	var base: Vector2 = node.get_meta("juice_base_pos")
	var tw := node.create_tween()
	var steps: int = maxi(3, int(dur / 0.03))
	for i in range(steps):
		var k: float = 1.0 - float(i) / float(steps)
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * strength * k
		tw.tween_property(node, "position", base + off.round(), dur / steps)
	tw.tween_property(node, "position", base, 0.03)
	tw.tween_callback(func(): node.remove_meta("juice_base_pos"))

# Congela o jogo por instantes (impacto). O timer ignora o time_scale.
static func hit_stop(tree: SceneTree, secs: float = 0.06, slow: float = 0.05) -> void:
	if not screen_fx or tree == null or _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = slow
	await tree.create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false
