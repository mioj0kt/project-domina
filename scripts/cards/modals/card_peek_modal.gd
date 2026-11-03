class_name CardPeekModal
extends CanvasLayer

# Escolha de 1 carta entre as do topo do baralho (usada pela carta Visão).
# Uso: var m := CardPeekModal.new(); host.add_child(m); m.present(cartas);
#      var escolhida: ActionCard = await m.chosen

const PEEK_SCALE: float = 1.4

signal chosen(card: ActionCard)

var _cards_box: HBoxContainer
var _tooltip: ActionCardTooltip
var _done: bool = false
var _targets: Array = []  # [{ctrl: Control, card: ActionCard}]

func _init() -> void:
	layer = 120
	visible = false
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 28)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)

	var title := Label.new()
	title.text = "VISÃO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title.add_theme_constant_override("outline_size", 10)
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Escolha 1 carta do topo do baralho para levar à mão. As outras continuam lá."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	vb.add_child(sub)

	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 36)
	_cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_cards_box)

	_tooltip = ActionCardTooltip.new()
	add_child(_tooltip)

func present(cards: Array) -> void:
	_targets.clear()
	for c in _cards_box.get_children():
		c.queue_free()
	for card in cards:
		_cards_box.add_child(_make_widget(card))
	_done = false
	visible = true

func _pick(card: ActionCard) -> void:
	if _done:
		return
	_done = true
	visible = false
	_tooltip.hide_tooltip()
	chosen.emit(card)

# Rede de segurança: trata o clique direto no _input, independente de qual
# controle de GUI estiver capturando o mouse (o modal nasce no meio de um
# clique vindo da mão, e o viewport ainda pode estar com o foco em outra carta).
func _input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for t in _targets:
			var c: Control = t["ctrl"]
			if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(event.position):
				get_viewport().set_input_as_handled()
				_pick(t["card"])
				return
		get_viewport().set_input_as_handled()

func _on_click(event: InputEvent, card: ActionCard) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick(card)

func _make_widget(card: ActionCard) -> Control:
	var rar_color = ActionCardVisual.get_rarity_color(card.rarity)
	var w: float = ActionCardVisual.CARD_WIDTH * PEEK_SCALE
	var h: float = ActionCardVisual.CARD_HEIGHT * PEEK_SCALE

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(w + 44, h + 150)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.11, 0.17, 0.7), Color(0.2, 0.22, 0.28, 0.5), 20))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	box.add_child(v)

	var tag := Label.new()
	tag.text = "[ %s ]" % ActionCard.get_rarity_name(card.rarity)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 19)
	tag.add_theme_color_override("font_color", rar_color)
	v.add_child(tag)

	var frame := Control.new()
	frame.custom_minimum_size = Vector2(w, h)
	v.add_child(frame)

	var vis := ActionCardVisual.new(card, true, PEEK_SCALE)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(vis)
	# O desenho da carta tem controles internos que engolem o mouse; por isso a
	# área clicável é uma camada transparente por cima de tudo.
	var hit := Control.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.add_child(hit)
	_targets.append({"ctrl": hit, "card": card})
	hit.mouse_entered.connect(func():
		_tooltip.show_tooltip(card, frame.global_position + Vector2(w / 2.0, 0.0)))
	hit.mouse_exited.connect(func(): _tooltip.hide_tooltip())
	hit.gui_input.connect(func(ev): _on_click(ev, card))

	var btn := Button.new()
	btn.text = "LEVAR"
	btn.custom_minimum_size = Vector2(w, 58)
	btn.add_theme_font_size_override("font_size", 24)
	PixelUI.skin_button(btn, Color(0.3, 0.9, 0.4), "", "icone_confirmar")
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	btn.pressed.connect(func(): _pick(card))
	v.add_child(btn)
	_targets.append({"ctrl": btn, "card": card})
	return box
