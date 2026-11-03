class_name ActionCardRewardModal
extends CanvasLayer

const REWARD_SCALE: float = 1.4

signal card_chosen(card: ActionCard)
signal skipped()

var cards_container: HBoxContainer
var root_ctrl: Control
var card_tooltip: ActionCardTooltip

func _init() -> void:
	layer = 120
	visible = false
	_build_ui()

func _build_ui() -> void:
	root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_ctrl)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(bg)

	var center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_CENTER)
	center_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 32)
	center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(center_vbox)

	var header_vbox = VBoxContainer.new()
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_theme_constant_override("separation", 6)
	center_vbox.add_child(header_vbox)

	var title = Label.new()
	title.text = "RECOMPENSA DE BATALHA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title.add_theme_constant_override("outline_size", 10)
	header_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Escolha 1 Carta de Ação para adicionar ao seu Baralho"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	header_vbox.add_child(subtitle)

	cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 36)
	cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(cards_container)

	var skip_btn = Button.new()
	skip_btn.text = "IGNORAR RECOMPENSA"
	skip_btn.custom_minimum_size = Vector2(320, 60)
	skip_btn.add_theme_font_size_override("font_size", 24)
	PixelUI.skin_button(skip_btn, Color(0.35, 0.4, 0.5), "", "icone_fechar")
	skip_btn.pressed.connect(func():
		visible = false
		if card_tooltip:
			card_tooltip.hide_tooltip()
		skipped.emit()
	)
	center_vbox.add_child(skip_btn)

	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

func prompt_reward() -> void:
	if card_tooltip:
		card_tooltip.hide_tooltip()

	for child in cards_container.get_children():
		child.queue_free()

	var chosen_cards = LootTables.get_random_action_cards(3)

	for card in chosen_cards:
		var card_widget = _create_reward_card_widget(card)
		cards_container.add_child(card_widget)

	visible = true

func _create_reward_card_widget(card: ActionCard) -> Control:
	var rar_color = ActionCardVisual.get_rarity_color(card.rarity)
	var scaled_w = ActionCardVisual.CARD_WIDTH * REWARD_SCALE
	var scaled_h = ActionCardVisual.CARD_HEIGHT * REWARD_SCALE

	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(scaled_w + 44, scaled_h + 150)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	# Sem borda colorida aqui — a carta (visual) já desenha sua própria
	# moldura completa agora, então um painel externo com borda igual
	# duplicava o contorno (dois anéis um dentro do outro).
	container.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.11, 0.17, 0.7), Color(0.2, 0.22, 0.28, 0.5), 20))

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	container.add_child(vb)

	var tag = Label.new()
	tag.text = "[ %s ]" % ActionCard.get_rarity_name(card.rarity)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 19)
	tag.add_theme_color_override("font_color", rar_color)
	vb.add_child(tag)

	var visual_frame = Control.new()
	visual_frame.custom_minimum_size = Vector2(scaled_w, scaled_h)
	vb.add_child(visual_frame)

	var card_visual = ActionCardVisual.new(card, true, REWARD_SCALE)
	card_visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual_frame.add_child(card_visual)

	card_visual.mouse_entered.connect(func():
		if card_tooltip:
			var tip_pos = card_visual.global_position + Vector2(scaled_w / 2.0, 0.0)
			card_tooltip.show_tooltip(card, tip_pos)
	)
	card_visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)

	var deck_full = not TutorialManager.is_active and RunManager != null and RunManager.player_deck.size() >= RunManager.MAX_PLAYER_DECK_SIZE

	var pick_btn = Button.new()
	pick_btn.text = "INVENTARIO CHEIO" if deck_full else "ESCOLHER"
	pick_btn.disabled = deck_full
	pick_btn.custom_minimum_size = Vector2(scaled_w, 58)
	pick_btn.add_theme_font_size_override("font_size", 16 if deck_full else 24)
	if deck_full:
		PixelUI.skin_button(pick_btn, Color(0.4, 0.35, 0.35))
	else:
		PixelUI.skin_button(pick_btn, Color(0.3, 0.9, 0.4), "", "icone_confirmar")
	pick_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	pick_btn.pressed.connect(func():
		# No tutorial, a carta é só ilustrativa — nunca entra no
		# inventário real do jogador (nem precisa checar limite).
		if not TutorialManager.is_active:
			if not RunManager.add_card_to_deck(card):
				return
		visible = false
		if card_tooltip:
			card_tooltip.hide_tooltip()
		card_chosen.emit(card)
	)
	vb.add_child(pick_btn)

	return container
