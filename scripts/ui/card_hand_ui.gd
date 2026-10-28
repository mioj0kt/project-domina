class_name CardHandUI
extends CanvasLayer

signal card_clicked_for_target(card: ActionCard, card_index: int)
signal card_drag_started(card: ActionCard, card_index: int)
signal card_drag_released(card: ActionCard, card_index: int, screen_pos: Vector2)
signal card_selection_cancelled()

const CARD_WIDTH: float = ActionCardVisual.CARD_WIDTH
const CARD_HEIGHT: float = ActionCardVisual.CARD_HEIGHT
const DRAG_THRESHOLD: float = 8.0

# Mão "recolhida": cartas pequenas e coladas na base da tela; ao passar o
# mouse na região elas crescem e se afastam (transição animada via _expand,
# 0 = recolhida, 1 = aberta).
# Escalas relativas ao tamanho base da carta (CARD_WIDTH x CARD_HEIGHT). As
# cartas da mão são construídas já no tamanho ABERTO (EXPANDED_SCALE) e só
# encolhem por transform quando recolhidas — assim ficam nítidas abertas.
const COLLAPSED_SCALE: float = 0.65
const EXPANDED_SCALE: float = 1.5
const WIDGET_W: float = CARD_WIDTH * EXPANDED_SCALE
const WIDGET_H: float = CARD_HEIGHT * EXPANDED_SCALE
const COLLAPSED_STEP_FRAC: float = 0.55      # passo entre cartas (fração da largura), recolhida
const EXPANDED_STEP_PAD: float = 10.0        # passo extra além da largura, aberta
const BOTTOM_MARGIN: float = 14.0
const EXPAND_TIME: float = 0.28
const COLLAPSE_TIME: float = 0.22
const HOVER_LIFT: float = 30.0

var deck_mgr: CardDeckManager
var hud_bar_ref: HUDBar
var cards_root: Control
var _expand: float = 0.0
var _expand_target: float = 0.0
var _expand_tween: Tween
var _hover_idx: int = -1
var _tooltip_idx: int = -1
var card_tooltip: ActionCardTooltip

var previous_hand_count: int = 0
var selected_card_idx: int = -1

var is_dragging: bool = false
var drag_potential_card: ActionCard = null
var drag_potential_idx: int = -1
var drag_origin_ctrl: Control = null
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_preview_control: Control = null
var drag_offset: Vector2 = Vector2.ZERO

func _init() -> void:
	layer = 85
	_build_ui()

func _build_ui() -> void:
	visible = true

	var root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	# Mão de Cartas: Control simples; o layout das cartas é feito à mão em
	# _apply_layout() (posição/escala animadas), não por um HBoxContainer.
	cards_root = Control.new()
	cards_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(cards_root)

func setup(p_deck_mgr: CardDeckManager, p_hud_bar: HUDBar = null) -> void:
	deck_mgr = p_deck_mgr
	hud_bar_ref = p_hud_bar
	deck_mgr.hand_updated.connect(refresh_hand)
	previous_hand_count = 0
	refresh_hand()

# ---------------------------------------------------------------------------
# Layout recolhido <-> aberto
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if cards_root == null:
		return
	var want_open = _mouse_in_hand_zone()
	if want_open != (_expand_target > 0.5):
		_set_expanded(want_open)
	_apply_layout(delta)
	_update_tooltip()

# Tooltip só com a mão totalmente aberta (senão ele nasceria na posição antiga
# da carta, ainda pequena) e acompanhando a carta sob o mouse.
func _update_tooltip() -> void:
	if card_tooltip == null or deck_mgr == null:
		return
	var want = _hover_idx if (_expand > 0.98 and not is_dragging) else -1
	if want == _tooltip_idx:
		return
	_tooltip_idx = want
	if want < 0 or want >= deck_mgr.hand.size() or want >= cards_root.get_child_count():
		card_tooltip.hide_tooltip()
		return
	var w = cards_root.get_child(want) as Control
	var pos = w.get_global_transform() * Vector2(WIDGET_W / 2.0, 0.0)
	pos.y -= HOVER_LIFT
	card_tooltip.show_tooltip(deck_mgr.hand[want], pos)

func _set_expanded(open: bool) -> void:
	_expand_target = 1.0 if open else 0.0
	if _expand_tween != null and _expand_tween.is_valid():
		_expand_tween.kill()
	_expand_tween = create_tween()
	_expand_tween.tween_property(self, "_expand", _expand_target, EXPAND_TIME if open else COLLAPSE_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not open and card_tooltip != null:
		card_tooltip.hide_tooltip()

func _hand_step(n: int, expanded: bool) -> float:
	if n <= 1:
		return 0.0
	if not expanded:
		return CARD_WIDTH * COLLAPSED_SCALE * COLLAPSED_STEP_FRAC
	var vp_w = get_viewport().get_visible_rect().size.x
	var max_total = vp_w * 0.6
	return minf(CARD_WIDTH * EXPANDED_SCALE + EXPANDED_STEP_PAD, (max_total - CARD_WIDTH * EXPANDED_SCALE) / float(n - 1))

func _mouse_in_hand_zone() -> bool:
	var n = cards_root.get_child_count()
	if n == 0 or is_dragging:
		return false
	var vp = get_viewport().get_visible_rect().size
	var m = get_viewport().get_mouse_position()
	var open = _expand_target > 0.5
	var step = _hand_step(n, open)
	var half_w = (step * (n - 1) + CARD_WIDTH * (EXPANDED_SCALE if open else COLLAPSED_SCALE)) * 0.5 + 24.0
	var zone_h = (CARD_HEIGHT * EXPANDED_SCALE + 48.0) if open else (CARD_HEIGHT * COLLAPSED_SCALE + 40.0)
	return absf(m.x - vp.x * 0.5) <= half_w and m.y >= vp.y - zone_h

# Retângulo (coordenadas de viewport) que envolve a mão AGORA, acompanhando a
# animação de abrir/fechar (as cartas crescem ao passar o mouse). Usado pelo
# destaque do tutorial, que precisa crescer junto com elas.
func get_hand_rect(pad: float = 14.0) -> Rect2:
	var n = cards_root.get_child_count() if cards_root != null else 0
	if n == 0:
		return Rect2()
	var vp = get_viewport().get_visible_rect().size
	var step = lerpf(_hand_step(n, false), _hand_step(n, true), _expand)
	var sc = lerpf(COLLAPSED_SCALE, EXPANDED_SCALE, _expand)
	var w = step * float(n - 1) + CARD_WIDTH * sc
	var h = CARD_HEIGHT * sc + HOVER_LIFT * _expand
	var bottom = vp.y - BOTTOM_MARGIN
	return Rect2(vp.x * 0.5 - w * 0.5 - pad, bottom - h - pad, w + pad * 2.0, h + pad * 2.0 - 4.0)

func _apply_layout(delta: float) -> void:
	var n = cards_root.get_child_count()
	if n == 0:
		return
	var vp = get_viewport().get_visible_rect().size
	var step = lerpf(_hand_step(n, false), _hand_step(n, true), _expand)
	var sc = lerpf(COLLAPSED_SCALE / EXPANDED_SCALE, 1.0, _expand)
	var cx = vp.x * 0.5
	var bottom = vp.y - BOTTOM_MARGIN
	for i in range(n):
		var w = cards_root.get_child(i) as Control
		var lift: float = w.get_meta("lift", 0.0)
		var lift_target = HOVER_LIFT * _expand if (i == _hover_idx and _expand > 0.5 and not is_dragging) else 0.0
		lift = lerpf(lift, lift_target, clampf(delta * 16.0, 0.0, 1.0))
		w.set_meta("lift", lift)
		var local = (float(i) - float(n - 1) * 0.5) * step
		w.pivot_offset = Vector2(WIDGET_W * 0.5, WIDGET_H)
		w.scale = Vector2(sc, sc)
		w.position = Vector2(cx + local - WIDGET_W * 0.5, bottom - WIDGET_H - lift)
		w.z_index = 10 if i == _hover_idx else 0

func refresh_hand() -> void:
	_cleanup_drag_state()
	selected_card_idx = -1
	if card_tooltip:
		card_tooltip.hide_tooltip()

	var previous_count = previous_hand_count
	var new_count = deck_mgr.hand.size() if deck_mgr != null else 0
	previous_hand_count = new_count

	_hover_idx = -1
	_tooltip_idx = -1
	for child in cards_root.get_children():
		cards_root.remove_child(child)
		child.queue_free()

	if deck_mgr == null:
		return

	var new_widgets: Array[Control] = []
	for i in range(deck_mgr.hand.size()):
		var card = deck_mgr.hand[i]
		var card_widget = _create_card_widget(card, i)
		cards_root.add_child(card_widget)

		if i >= previous_count:
			card_widget.modulate.a = 0.0
			new_widgets.append(card_widget)

	if not new_widgets.is_empty():
		_process_draw_animations(new_widgets)

func _process_draw_animations(widgets: Array[Control]) -> void:
	await get_tree().process_frame
	for i in range(widgets.size()):
		var target_widget = widgets[i]
		if is_instance_valid(target_widget):
			_animate_draw_fly_in(target_widget, i * 0.12)

func _animate_draw_fly_in(target_widget: Control, delay: float) -> void:
	var start_pos = hud_bar_ref.get_draw_pile_global_pos() if hud_bar_ref != null else (Vector2(40.0, 400.0))

	var card_visual = target_widget.get_child(0) as ActionCardVisual
	var card_ref = card_visual.card if card_visual != null else null

	var flying_card = ActionCardVisual.new(card_ref, false)
	flying_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flying_card)
	flying_card.global_position = start_pos
	flying_card.scale = Vector2(0.60, 0.60)

	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(target_widget):
		flying_card.queue_free()
		return

	# Destino = posição/escala atuais da carta na mão (recolhida ou aberta).
	var end_pos = target_widget.get_global_transform().origin
	var end_scale = target_widget.scale * EXPANDED_SCALE
	var tween = create_tween().set_parallel(true)
	tween.tween_property(flying_card, "global_position", end_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying_card, "scale", end_scale, 0.35)

	await tween.finished
	flying_card.play_flip_reveal()
	await flying_card.flipped_face_up
	flying_card.queue_free()

	if is_instance_valid(target_widget):
		target_widget.modulate.a = 1.0

func _create_card_widget(card: ActionCard, idx: int) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(WIDGET_W, WIDGET_H)
	container.size = Vector2(WIDGET_W, WIDGET_H)
	# Sem isso, o HBoxContainer da mão pode esticar o container no eixo
	# cruzado (vertical) pra preencher a altura da fileira — o que achatava
	# a carta e transformava os círculos/ornamentos da borda em elipses.
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var visual = ActionCardVisual.new(card, true, EXPANDED_SCALE)
	container.add_child(visual)
	CardVisualBase.bind_tilt(container, visual)

	# Moldura de seleção: mesmo tamanho da carta, adicionada DEPOIS (desenha
	# por cima). Como o preenchimento é transparente, só a linha da borda
	# aparece — nunca fica escondida atrás da carta, ao contrário de antes
	# quando ela ficava embaixo (por trás) do sprite opaco da carta.
	var border_bg = PanelContainer.new()
	border_bg.name = "BorderBg"
	border_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border_bg)
	_update_card_border(border_bg, idx == selected_card_idx)

	container.mouse_entered.connect(func():
		_hover_idx = idx
		pass # o tooltip é mostrado por _update_tooltip() quando a mão termina de abrir
	)

	container.mouse_exited.connect(func():
		if _hover_idx == idx:
			_hover_idx = -1
	)

	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_potential_card = card
				drag_potential_idx = idx
				drag_origin_ctrl = container
				drag_start_mouse_pos = event.global_position
			else:
				if not is_dragging and drag_potential_card != null:
					_handle_card_click(idx, card)
				drag_potential_card = null
				drag_potential_idx = -1
				drag_origin_ctrl = null
	)

	return container

func _update_card_border(container: PanelContainer, is_selected: bool) -> void:
	var border_col = Color(1.0, 0.85, 0.2, 1.0) if is_selected else Color(0.3, 0.75, 1.0, 0.0)
	var bg_col = Color(0.0, 0.0, 0.0, 0.0)
	var style = PixelUI.make_bevel_card(bg_col, border_col)
	style.draw_center = false
	container.add_theme_stylebox_override("panel", style)

func _handle_card_click(idx: int, card: ActionCard) -> void:
	if selected_card_idx == idx:
		cancel_selection()
		return

	selected_card_idx = idx
	_refresh_all_card_borders()
	card_clicked_for_target.emit(card, idx)

func _refresh_all_card_borders() -> void:
	var children = cards_root.get_children()
	for i in range(children.size()):
		var border_bg = children[i].get_node_or_null("BorderBg") as PanelContainer
		if border_bg:
			_update_card_border(border_bg, i == selected_card_idx)

func _input(event: InputEvent) -> void:
	if drag_potential_card != null and not is_dragging:
		if event is InputEventMouseMotion:
			if event.global_position.distance_to(drag_start_mouse_pos) > DRAG_THRESHOLD:
				if card_tooltip:
					card_tooltip.hide_tooltip()
				_start_dragging(drag_potential_card, drag_potential_idx, drag_origin_ctrl)

	if is_dragging:
		if event is InputEventMouseMotion and drag_preview_control:
			drag_preview_control.global_position = event.position - drag_offset

			var vp_h = get_viewport().get_visible_rect().size.y
			var hand_y = vp_h - (CARD_HEIGHT + 24.0)
			var board_y = vp_h * 0.45
			var t = clampf(inverse_lerp(hand_y, board_y, event.position.y), 0.0, 1.0)

			var cur_scale = lerpf(1.0, 0.55, t)
			drag_preview_control.scale = Vector2(cur_scale, cur_scale)
			drag_preview_control.modulate.a = lerpf(0.95, 0.40, t)

		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var drop_pos = event.position
			var card = drag_potential_card
			var idx = drag_potential_idx
			_cleanup_drag_state()
			card_drag_released.emit(card, idx, drop_pos)

		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_selection()

func _start_dragging(card: ActionCard, idx: int, origin_ctrl: Control) -> void:
	is_dragging = true
	selected_card_idx = idx
	_refresh_all_card_borders()

	if origin_ctrl:
		origin_ctrl.modulate = Color(1.0, 1.0, 1.0, 0.25)

	drag_preview_control = ActionCardVisual.new(card, true)
	drag_preview_control.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	add_child(drag_preview_control)

	drag_offset = Vector2(CARD_WIDTH, CARD_HEIGHT) / 2.0
	drag_preview_control.global_position = drag_start_mouse_pos - drag_offset

	card_drag_started.emit(card, idx)

func _cleanup_drag_state() -> void:
	if drag_preview_control:
		drag_preview_control.queue_free()
		drag_preview_control = null

	is_dragging = false
	drag_potential_card = null
	drag_potential_idx = -1
	drag_origin_ctrl = null

	for child in cards_root.get_children():
		child.modulate = Color.WHITE

func cancel_selection(notify: bool = true) -> void:
	if selected_card_idx == -1 and not is_dragging and drag_potential_card == null:
		return

	_cleanup_drag_state()
	selected_card_idx = -1
	_refresh_all_card_borders()

	if card_tooltip:
		card_tooltip.hide_tooltip()

	if notify:
		card_selection_cancelled.emit()
