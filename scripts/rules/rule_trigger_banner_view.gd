class_name RuleTriggerBannerView
extends Node2D

# Ícone de raio desenhado à mão (zigue-zague simples) em vez do emoji "⚡" —
# fontes pixel art customizadas nem sempre têm glifos de emoji, então o
# desenho garante que sempre aparece igual, em qualquer fonte.
class _SparkIcon:
	extends Control
	var spark_color: Color = Color(1.0, 0.85, 0.3)

	func _draw() -> void:
		var w = size.x
		var h = size.y
		var pts = PackedVector2Array([
			Vector2(w * 0.55, 0.0),
			Vector2(w * 0.15, h * 0.55),
			Vector2(w * 0.45, h * 0.55),
			Vector2(w * 0.35, h),
			Vector2(w * 0.85, h * 0.4),
			Vector2(w * 0.55, h * 0.4),
		])
		draw_colored_polygon(pts, spark_color)

# Emitido junto com cada letreiro que pertence a uma Lei (rule_id preenchido):
# a HUD faz o slot da Lei tremer/brilhar.
signal rule_fired(rule_id: String)

func pop_rule_trigger(world_pos: Vector2, rule_name: String, color: Color = Color(1.0, 0.85, 0.3), rule_id: String = "") -> void:
	if rule_id != "":
		rule_fired.emit(rule_id)
	# Tutorial: a primeira vez que uma Lei age vira um momento "viu só?".
	TutorialManager.report_event("law_triggered")
	TutorialManager.report_law_applied()
	var badge = PanelContainer.new()
	badge.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.06, 0.07, 0.1, 0.92), color, 6))
	badge.z_index = 80
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(hbox)

	var icon = _SparkIcon.new()
	icon.custom_minimum_size = Vector2(14, 16)
	icon.spark_color = color
	hbox.add_child(icon)

	var label = Label.new()
	label.text = rule_name.to_upper()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1.0))
	label.add_theme_constant_override("outline_size", 5)
	hbox.add_child(label)

	add_child(badge)

	# O tamanho real do badge só fica pronto depois de um frame de layout
	# (a HBox precisa medir o ícone + texto primeiro) — por isso a posição
	# final e o pivô (pro "pulo" crescer a partir do centro, não do canto)
	# só são ajustados depois de esperar esse frame.
	await get_tree().process_frame
	badge.position = world_pos - badge.size / 2.0 - Vector2(0.0, 20.0)
	badge.pivot_offset = badge.size / 2.0
	badge.scale = Vector2(0.4, 0.4)
	badge.modulate.a = 0.0

	var start_y = badge.position.y
	var tween = create_tween()

	# 1. Entrada com um leve "pulo" (cresce um pouco além do tamanho final
	# e assenta), em vez de só aparecer estático.
	tween.tween_property(badge, "scale", Vector2(1.08, 1.08), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(badge, "modulate:a", 1.0, 0.12)

	tween.tween_property(badge, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 2. Segura um instante pra dar tempo de ler
	tween.tween_interval(0.35)

	# 3. Sobe flutuando + fade out
	tween.tween_property(badge, "position:y", start_y - 40.0, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(badge, "modulate:a", 0.0, 0.55)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await tween.finished
	badge.queue_free()
