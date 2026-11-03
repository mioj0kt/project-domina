class_name GameOverModal
extends CanvasLayer

signal action_confirmed(won: bool)

var is_won_state: bool = false
var is_counting: bool = false
var skip_requested: bool = false

var modal_panel: PanelContainer
var title_label: Label
var stats_container: VBoxContainer
var total_label: Label
var confirm_btn: Button

var reward_data: Dictionary = {}
var victory_fx: VictoryFx

func _ready() -> void:
	layer = 100
	visible = false
	_build_ui()

func _build_ui() -> void:
	var bg_overlay = ColorRect.new()
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_overlay.color = Color(0.02, 0.03, 0.05, 0.82)
	add_child(bg_overlay)

	# Comemoração por código (por trás do painel).
	victory_fx = VictoryFx.new()
	add_child(victory_fx)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	modal_panel = PanelContainer.new()
	center.add_child(modal_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	modal_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title_label)

	var divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color(0.25, 0.28, 0.35, 0.9)
	vbox.add_child(divider)

	stats_container = VBoxContainer.new()
	stats_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_container.add_theme_constant_override("separation", 14)
	vbox.add_child(stats_container)

	total_label = Label.new()
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_label.add_theme_font_size_override("font_size", 24)
	total_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	vbox.add_child(total_label)

	confirm_btn = Button.new()
	confirm_btn.custom_minimum_size = Vector2(260, 52)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_btn.add_theme_font_size_override("font_size", 22)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	vbox.add_child(confirm_btn)

func show_game_over(won: bool, rewards: Dictionary = {}, custom_title: String = "", defeat_message: String = "") -> void:
	is_won_state = won
	visible = true
	skip_requested = false
	reward_data = rewards

	for child in stats_container.get_children():
		child.queue_free()

	if won:
		var title_txt = custom_title if custom_title != "" else "VITORIA NO DUELO!"
		title_label.text = title_txt
		title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
		modal_panel.custom_minimum_size = Vector2(580, 420)
		modal_panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.08, 0.1, 0.14, 0.98), Color(1.0, 0.84, 0.2), 24))

		confirm_btn.text = "CONTINUAR ->"
		PixelUI.skin_button(confirm_btn, Color(0.3, 0.9, 0.45))
		confirm_btn.disabled = true
		total_label.text = ""

		var is_boss: bool = not TutorialManager.is_active and RunManager != null and RunManager.current_node_type == MapNode.NodeType.Chefe
		victory_fx.start(is_boss)
		_pop_in(is_boss)
		_run_rewards_animation()
	else:
		victory_fx.stop()
		var title_txt = custom_title if custom_title != "" else "DERROTA NO DUELO!"
		title_label.text = title_txt
		title_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.25))
		modal_panel.custom_minimum_size = Vector2(500, 240)
		modal_panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.12, 0.05, 0.06, 0.98), Color(0.85, 0.15, 0.2), 24))

		var defeat_lbl = Label.new()
		defeat_lbl.text = defeat_message if defeat_message != "" else "Suas pecas foram eliminadas pelo exercito inimigo."
		defeat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		defeat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		defeat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		defeat_lbl.add_theme_font_size_override("font_size", 28)
		defeat_lbl.add_theme_color_override("font_color", Color(0.9, 0.82, 0.82))
		stats_container.add_child(defeat_lbl)

		total_label.text = ""
		confirm_btn.text = "VER RESUMO DA RUN"
		PixelUI.skin_button(confirm_btn, Color(0.9, 0.25, 0.3))
		confirm_btn.disabled = false

# Entrada do painel e do título com "pop" (maior no Chefe).
func _pop_in(big: bool) -> void:
	modal_panel.pivot_offset = modal_panel.custom_minimum_size * 0.5
	modal_panel.scale = Vector2(0.6, 0.6)
	modal_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(modal_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(modal_panel, "modulate:a", 1.0, 0.2)
	title_label.pivot_offset = Vector2(modal_panel.custom_minimum_size.x * 0.5 - 28.0, 20.0)
	title_label.scale = Vector2(0.4, 0.4)
	var tt := create_tween()
	tt.tween_interval(0.25)
	tt.tween_property(title_label, "scale", Vector2(1.18 if big else 1.1, 1.18 if big else 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.tween_property(title_label, "scale", Vector2.ONE, 0.2)

func _input(event: InputEvent) -> void:
	if not visible or not is_won_state:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_counting and not skip_requested:
			skip_requested = true

func _run_rewards_animation() -> void:
	is_counting = true

	var rows = [
		{"label": "VITORIA:", "amount": reward_data.get("base", 5)},
		{"label": "CAPTURAS:", "amount": reward_data.get("captures", 0)},
		{"label": "SOBREVIVENTES:", "amount": reward_data.get("survival", 0)}
	]
	if reward_data.get("bonus", 0) > 0:
		rows.append({"label": "SAQUE:", "amount": reward_data["bonus"]})

	var total_gold_accum = 0

	for item in rows:
		var row_box = HBoxContainer.new()
		row_box.add_theme_constant_override("separation", 14)
		stats_container.add_child(row_box)

		var lbl = Label.new()
		lbl.text = item["label"]
		lbl.custom_minimum_size = Vector2(180, 0)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		row_box.add_child(lbl)

		var coins_container = HBoxContainer.new()
		coins_container.add_theme_constant_override("separation", 2)
		row_box.add_child(coins_container)

		var val_lbl = Label.new()
		val_lbl.text = ""
		val_lbl.add_theme_font_size_override("font_size", 20)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		row_box.add_child(val_lbl)

		var count: int = item["amount"]
		total_gold_accum += count

		var current_delay = 0.14
		for c in range(count):
			var coin = PixelUI.make_coin_icon(32.0)
			coins_container.add_child(coin)
			val_lbl.text = "+%d" % (c + 1)

			if not skip_requested:
				var t = create_tween()
				coin.scale = Vector2(0.3, 0.3)
				t.tween_property(coin, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

				await get_tree().create_timer(current_delay).timeout
				if is_instance_valid(coin):
					victory_fx.pop_at(coin.global_position + coin.size * 0.5, 1)
				current_delay = max(0.02, current_delay * 0.88)
			else:
				coin.scale = Vector2.ONE

		if count == 0:
			val_lbl.text = "+0"

		if not skip_requested:
			await get_tree().create_timer(0.12).timeout

	total_label.text = "TOTAL RECEBIDO: +%d OURO" % reward_data.get("total", total_gold_accum)
	if int(reward_data.get("coroas", 0)) > 0:
		total_label.text += "\n+%d COROAS (META)" % int(reward_data["coroas"])
	# fecha com um estouro de moedas no total
	total_label.pivot_offset = total_label.size * 0.5
	total_label.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(total_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	victory_fx.pop_at(total_label.global_position + total_label.size * 0.5, 8)
	is_counting = false
	confirm_btn.disabled = false

func _on_confirm_pressed() -> void:
	if is_counting:
		return
	action_confirmed.emit(is_won_state)
