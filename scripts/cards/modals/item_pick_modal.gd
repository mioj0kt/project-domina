class_name ItemPickModal
extends CanvasLayer

# Escolha de 1 item numa grade: Cartas de Ação (do baralho ou oferecidas) ou Leis.
# Usado pelos eventos do mapa: trocar/vender/oferecer/forjar a carta que o
# jogador QUISER (em vez de uma aleatória) e escolher 1 entre várias cartas.
# Uso: var m := ItemPickModal.new(); add_child(m)
#      m.present("TROCAR UMA CARTA", "Escolha a carta...", deck, Color(...))
#      m.picked.connect(...) / m.canceled.connect(...)

signal picked(item)
signal canceled()

const DECK_SCALE: float = 0.92      # muitas cartas (baralho inteiro, até 20)
const OFFER_SCALE: float = 1.4      # poucas cartas (escolha 1 de 3)
const LAW_SCALE: float = 0.62
const DECK_COLUMNS: int = 10

var _title: Label
var _sub: Label
var _grid: GridContainer
var _cancel_btn: Button
var _card_tip: ActionCardTooltip
var _rule_tip: RuleCardTooltip
var _done: bool = false

func _init() -> void:
	MenuPieceCursor.auto(self)
	layer = 126
	visible = false
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.07, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 26)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 50)
	_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	_title.add_theme_constant_override("outline_size", 10)
	vb.add_child(_title)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 24)
	_sub.add_theme_color_override("font_color", Color(0.72, 0.8, 0.95))
	vb.add_child(_sub)

	var gc := CenterContainer.new()
	gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(gc)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gc.add_child(_grid)

	_cancel_btn = Button.new()
	_cancel_btn.text = "VOLTAR"
	_cancel_btn.custom_minimum_size = Vector2(300, 58)
	_cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cancel_btn.add_theme_font_size_override("font_size", 22)
	PixelUI.skin_button(_cancel_btn, Color(0.4, 0.42, 0.52), "", "icone_voltar")
	_cancel_btn.pressed.connect(func():
		if _done:
			return
		_close()
		canceled.emit())
	vb.add_child(_cancel_btn)

	_card_tip = ActionCardTooltip.new()
	add_child(_card_tip)
	_rule_tip = RuleCardTooltip.new()
	add_child(_rule_tip)

# items: Array de ActionCard ou de RuleCard. `offer` = poucas cartas grandes
# (escolha de recompensa); senão é o baralho/as Leis do jogador.
func present(title: String, subtitle: String, items: Array, accent: Color, offer: bool = false, cancel_text: String = "VOLTAR") -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", accent.lightened(0.25))
	_sub.text = subtitle
	_cancel_btn.text = cancel_text
	for c in _grid.get_children():
		c.queue_free()
	var is_law: bool = not items.is_empty() and items[0] is RuleCard
	if is_law:
		_grid.columns = mini(items.size(), 6)
	elif offer:
		_grid.columns = maxi(items.size(), 1)
	else:
		_grid.columns = mini(maxi(items.size(), 1), DECK_COLUMNS)
	_grid.add_theme_constant_override("h_separation", 36 if offer else 18)
	for it in items:
		if it is RuleCard:
			_grid.add_child(_law_widget(it, accent))
		elif it is ActionCard:
			_grid.add_child(_card_widget(it, accent, OFFER_SCALE if offer else DECK_SCALE))
	_done = false
	visible = true

func _close() -> void:
	_done = true
	visible = false
	_card_tip.hide_tooltip()
	_rule_tip.hide_tooltip()

func _pick(item) -> void:
	if _done:
		return
	_close()
	Sfx.play("clique")
	picked.emit(item)

# Moldura que acende no hover + camada transparente que recebe o clique
# (o desenho da carta tem controles internos que engoliriam o mouse).
func _wrap(content: Control, size: Vector2, accent: Color, on_hover: Callable, on_exit: Callable, item) -> Control:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var idle := PixelUI.make_pixel_panel(Color(0.09, 0.11, 0.17, 0.75), Color(0.22, 0.24, 0.3, 0.6), 10)
	var hot := PixelUI.make_pixel_panel(Color(0.16, 0.15, 0.12, 0.9), accent, 10)
	box.add_theme_stylebox_override("panel", idle)
	var frame := Control.new()
	frame.custom_minimum_size = size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(content)
	var hit := Control.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.add_child(hit)
	hit.mouse_entered.connect(func():
		box.add_theme_stylebox_override("panel", hot)
		content.position.y = -6.0
		Sfx.play("hover", -10.0)
		on_hover.call(frame))
	hit.mouse_exited.connect(func():
		box.add_theme_stylebox_override("panel", idle)
		content.position.y = 0.0
		on_exit.call())
	hit.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_pick(item))
	return box

func _card_widget(card: ActionCard, accent: Color, sc: float) -> Control:
	var w: float = ActionCardVisual.CARD_WIDTH * sc
	var h: float = ActionCardVisual.CARD_HEIGHT * sc
	var vis := ActionCardVisual.new(card, true, sc)
	return _wrap(vis, Vector2(w, h), accent,
		func(f: Control): _card_tip.show_tooltip(card, f.global_position + Vector2(w / 2.0, 0.0)),
		func(): _card_tip.hide_tooltip(), card)

func _law_widget(rule: RuleCard, accent: Color) -> Control:
	var s: float = RuleCardVisual.CARD_SIZE * LAW_SCALE
	var vis := RuleCardVisual.new(rule, null, true, LAW_SCALE)
	return _wrap(vis, Vector2(s, s), accent,
		func(f: Control): _rule_tip.show_tooltip(rule, f.global_position + Vector2(s / 2.0, 0.0)),
		func(): _rule_tip.hide_tooltip(), rule)
