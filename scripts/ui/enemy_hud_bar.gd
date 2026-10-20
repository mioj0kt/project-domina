class_name EnemyHudBar
extends CanvasLayer

# Espelho da HUDBar do lado direito da tela, representando o "lado do
# inimigo": Leis reais concedidas à IA (ver main._enemy_rules, geradas em
# main.gd conforme a dificuldade do duelo) + pilhas de baralho decorativas
# em cima (sem nenhuma mecânica real de cartas pro inimigo ainda — é só
# visual, pra simetria com a HUD do jogador).

var rule_tooltip: RuleCardTooltip
var card_tooltip: ActionCardTooltip
var side_container: VBoxContainer
var slot_containers: Array[Control] = []
var law_board: LawBoard
var _current_rules: Array[RuleCard] = []

var deck_mgr_ref: CardDeckManager
var draw_deck_stack: Control
var discard_deck_stack: Control
var _discard_widget: Control
var _viewer: CanvasLayer
var _viewer_grid: GridContainer
var _viewer_title: Label
var _viewer_empty: Label
var _viewer_tooltip: ActionCardTooltip

# Mesmas medidas do quadro de Leis do jogador (HUDBar.DECK_PANEL_H / PANEL_W).
const BOARD_H: float = HUDBar.DECK_PANEL_H
const PANEL_W: float = HUDBar.PANEL_W
# Pilhas (compra/descarte) do inimigo: cartas maiores que o antigo 0.6, e a
# linha das pilhas fica ABAIXO do quadro de leis (em cima ela ficava cortada
# pela borda da tela).
const ENEMY_BADGE_TINT: Color = Color(1.0, 0.45, 0.4)
const PILE_SCALE: float = 0.9
const PILE_W: float = 150.0
const PILE_H: float = 206.0
# Visualizador do descarte (clique na pilha): cartas em tamanho legível.
const VIEW_CARD_SCALE: float = 1.5
const VIEW_COLUMNS: int = 6

func _init() -> void:
	# Mesma camada da HUD do jogador (80): abaixo da mão (85), senão o quadro
	# de leis inimigo cobre as cartas da mão quando ela abre.
	layer = 80
	_build_side_panel()

# Alinha o topo do quadro de leis inimigo com o do jogador (mesma altura na tela).
func align_board_with(reference_board: Control) -> void:
	_align_ref = reference_board
	_realign_board()
	if not get_viewport().size_changed.is_connected(_realign_board):
		get_viewport().size_changed.connect(_realign_board)

var _align_ref: Control = null

func _realign_board() -> void:
	if _align_ref == null or not is_instance_valid(_align_ref) or law_board == null:
		return
	# Espera o layout dos containers assentar antes de medir.
	await get_tree().process_frame
	await get_tree().process_frame
	if _align_ref == null or not is_instance_valid(_align_ref):
		return
	var delta: float = _align_ref.global_position.y - law_board.global_position.y
	if absf(delta) > 0.5:
		side_container.offset_top += delta

func setup_deck_manager(deck_mgr: CardDeckManager) -> void:
	deck_mgr_ref = deck_mgr
	deck_mgr_ref.hand_updated.connect(update_pile_visual_stacks)
	update_pile_visual_stacks()

# Centro real (em coordenadas globais de tela) da pilha de descarte — usado
# pela animação da carta que a IA acabou de jogar, pra ela "pousar" no
# lugar certo em vez de só sumir.
func get_discard_pile_global_position() -> Vector2:
	if discard_deck_stack == null:
		return Vector2.ZERO
	return discard_deck_stack.global_position + discard_deck_stack.size / 2.0

func _build_side_panel() -> void:
	var root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)

	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	side_container = VBoxContainer.new()
	side_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_container.add_theme_constant_override("separation", 14)

	side_container.anchor_left = 1.0
	side_container.anchor_right = 1.0
	# Vertical: centrado como a HUD do jogador; a altura exata do quadro de leis
	# é igualada à do jogador em align_board_with() (as duas colunas têm
	# conteúdos diferentes acima/abaixo do quadro).
	side_container.anchor_top = 0.5
	side_container.anchor_bottom = 0.5
	side_container.grow_vertical = Control.GROW_DIRECTION_END
	side_container.offset_left = -(40.0 + PANEL_W)
	side_container.offset_right = -40.0
	side_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root_ctrl.add_child(side_container)

	# -------------------------------------------------------------------
	# 1. TÍTULO
	# -------------------------------------------------------------------
	var title_lbl = Label.new()
	title_lbl.text = "LEIS INIMIGAS"
	title_lbl.custom_minimum_size = Vector2(PANEL_W, 42)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	title_lbl.add_theme_stylebox_override("normal", PixelUI.make_hud_panel("painel_partida", 6, 1))
	side_container.add_child(title_lbl)

	# -------------------------------------------------------------------
	# 2. SLOTS 3x2 DE LEIS DA IA
	# -------------------------------------------------------------------
	var board_row = HBoxContainer.new()
	board_row.custom_minimum_size = Vector2(PANEL_W, BOARD_H)
	board_row.alignment = BoxContainer.ALIGNMENT_CENTER
	board_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_container.add_child(board_row)

	# Mesmo quadro do jogador, com leve tom avermelhado pra diferenciar.
	law_board = LawBoard.new(BOARD_H, Color(1.0, 0.82, 0.82))

	board_row.add_child(law_board)

	slot_containers.clear()
	for i in range(law_board.slots.size()):
		var slot = law_board.slots[i]
		slot.mouse_entered.connect(_on_rule_slot_hovered.bind(i))
		slot.mouse_exited.connect(_on_rule_slot_unhovered)
		slot_containers.append(slot)

	# -------------------------------------------------------------------
	# 3. PILHAS DE BARALHO (compra/descarte), abaixo do quadro de leis — mesmo verso de carta real
	# (sprite se existir, senão o mesmo fallback procedural) que a HUD do
	# jogador usa, sem texto identificando qual é qual.
	# -------------------------------------------------------------------
	var piles_hbox = HBoxContainer.new()
	piles_hbox.custom_minimum_size = Vector2(PANEL_W, PILE_H)
	piles_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	piles_hbox.add_theme_constant_override("separation", 16)
	piles_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_container.add_child(piles_hbox)

	var draw_pile_widget = _create_pile_display()
	piles_hbox.add_child(draw_pile_widget)
	draw_deck_stack = draw_pile_widget.get_node("StackContainer")

	var discard_pile_widget = _create_pile_display("icone_descarte")
	piles_hbox.add_child(discard_pile_widget)
	discard_deck_stack = discard_pile_widget.get_node("StackContainer")
	_setup_discard_click(discard_pile_widget)

func _create_pile_display(icon_file: String = "") -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(PILE_W, PILE_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stack_container = Control.new()
	stack_container.name = "StackContainer"
	stack_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stack_container)

	# Selo do descarte (mesmo ícone da HUD do jogador, avermelhado). Só aparece
	# com cartas na pilha.
	if icon_file != "":
		var badge = PixelUI.make_hud_icon(icon_file, 32.0)
		badge.position = Vector2(-6, -8)
		badge.size = Vector2(32, 32)
		badge.z_index = 5
		badge.name = "Badge"
		badge.modulate = ENEMY_BADGE_TINT
		badge.visible = false
		root.add_child(badge)

	return root

func update_pile_visual_stacks() -> void:
	if deck_mgr_ref == null:
		return

	for c in draw_deck_stack.get_children():
		c.queue_free()
	var draw_count = deck_mgr_ref.get_draw_count()
	for i in range(mini(5, draw_count)):
		var card_ref: ActionCard = deck_mgr_ref.draw_pile[i] if i < deck_mgr_ref.draw_pile.size() else null
		draw_deck_stack.add_child(_create_mini_card_back(card_ref, i * -3.0))

	for c in discard_deck_stack.get_children():
		c.queue_free()
	var discard_count = deck_mgr_ref.get_discard_count()
	for i in range(mini(5, discard_count)):
		var card_idx = (discard_count - mini(5, discard_count)) + i
		var card_ref: ActionCard = deck_mgr_ref.discard_pile[card_idx] if card_idx < deck_mgr_ref.discard_pile.size() else null
		discard_deck_stack.add_child(_create_discard_card_face(card_ref, i * -3.0))
	if _discard_widget != null and _discard_widget.has_node("Badge"):
		_discard_widget.get_node("Badge").visible = discard_count > 0

# Verso da carta real (sprite se existir pra essa raridade, senão o mesmo
# fallback procedural) — mesmo padrão que a HUD do jogador usa. Como é
# mostrado de costas, não revela qual carta é, só a raridade pela cor.
func _create_mini_card_back(card: ActionCard, y_offset: float) -> Control:
	var visual = ActionCardVisual.new(card if card != null else ActionCard.new(), false, PILE_SCALE)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.position = Vector2(8.0, 14.0 + y_offset)
	return visual

# Pilha de descarte: a carta já foi revelada ao jogador quando a IA a jogou
# (ver AICardRevealView), então mostrar a frente aqui não vaza informação
# nova — só ajuda a relembrar qual foi.
func _create_discard_card_face(card: ActionCard, y_offset: float) -> Control:
	if card == null:
		return _create_mini_card_back(card, y_offset)

	var visual = ActionCardVisual.new(card, true, PILE_SCALE)
	# PASS: o hover continua funcionando e o clique chega no widget da pilha
	# (que abre o visualizador do descarte).
	visual.mouse_filter = Control.MOUSE_FILTER_PASS
	visual.position = Vector2(8.0, 14.0 + y_offset)

	visual.mouse_entered.connect(func():
		if card_tooltip:
			# Tooltip abre pra ESQUERDA, já que essa HUD fica na direita da tela.
			var tip_pos = visual.global_position - Vector2(280.0, 0.0)
			card_tooltip.show_tooltip(card, tip_pos)
	)
	visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)

	return visual

# Chamado uma vez por duelo (as Leis da IA são fixas pro duelo inteiro, não
# mudam durante a partida como as do jogador).
func refresh(enemy_rules: Array[RuleCard]) -> void:
	_current_rules = enemy_rules

	for i in range(6):
		if i >= slot_containers.size():
			continue
		var slot = slot_containers[i]
		for child in slot.get_children():
			child.queue_free()

		if i < enemy_rules.size():
			var rule: RuleCard = enemy_rules[i]
			var mini_visual = RuleCardVisual.new(rule, null, true, law_board.slot_size / RuleCardVisual.CARD_SIZE)
			mini_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(mini_visual)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_rule_slot_hovered(idx: int) -> void:
	if rule_tooltip == null or idx >= _current_rules.size():
		return
	var slot = slot_containers[idx]
	# Tooltip abre pra ESQUERDA do slot, já que essa HUD fica na direita da tela.
	var screen_pos = slot.global_position - Vector2(280.0, 0.0)
	rule_tooltip.show_tooltip(_current_rules[idx], screen_pos)

func _on_rule_slot_unhovered() -> void:
	if rule_tooltip != null:
		rule_tooltip.hide_tooltip()

# Game juice: o slot desta Lei treme/brilha porque ela acabou de agir.
# Devolve false se a Lei não está neste quadro.
func flash_rule(rule_id: String) -> bool:
	for i in range(_current_rules.size()):
		if _current_rules[i].id == rule_id:
			law_board.flash_slot(i, RuleCard.get_category_color(_current_rules[i].category))
			return true
	return false


# ---------------------------------------------------------------------------
# Visualizador do descarte inimigo (clique na pilha)
# ---------------------------------------------------------------------------

func _setup_discard_click(widget: Control) -> void:
	_discard_widget = widget
	widget.mouse_filter = Control.MOUSE_FILTER_STOP
	widget.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	widget.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			open_discard_viewer()
	)
	widget.mouse_entered.connect(func(): widget.modulate = Color(1.12, 1.12, 1.12))
	widget.mouse_exited.connect(func(): widget.modulate = Color.WHITE)

func open_discard_viewer() -> void:
	if _viewer == null:
		_build_viewer()
	if card_tooltip:
		card_tooltip.hide_tooltip()
	_fill_viewer()
	_viewer.visible = true

func close_discard_viewer() -> void:
	if _viewer == null:
		return
	_viewer_tooltip.hide_tooltip()
	_viewer.visible = false

func _input(event: InputEvent) -> void:
	if _viewer != null and _viewer.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_discard_viewer()
		get_viewport().set_input_as_handled()

func _build_viewer() -> void:
	_viewer = CanvasLayer.new()
	_viewer.layer = 96
	_viewer.visible = false
	add_child(_viewer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.84)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close_discard_viewer()
	)
	_viewer.add_child(dim)

	_viewer_tooltip = ActionCardTooltip.new()
	_viewer.add_child(_viewer_tooltip)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(center)

	var panel := PanelContainer.new()
	var card_w: float = ActionCardVisual.CARD_WIDTH * VIEW_CARD_SCALE
	panel.custom_minimum_size = Vector2(VIEW_COLUMNS * (card_w + 16.0) + 96.0, 860)
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.08, 0.09, 0.13, 0.98), Color(1.0, 0.45, 0.4), 28))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	_viewer_title = Label.new()
	_viewer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewer_title.add_theme_font_size_override("font_size", 38)
	_viewer_title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	_viewer_title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	_viewer_title.add_theme_constant_override("outline_size", 10)
	header.add_child(_viewer_title)
	var close_btn := Button.new()
	close_btn.text = "FECHAR"
	close_btn.custom_minimum_size = Vector2(180, 48)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(close_discard_viewer)
	header.add_child(close_btn)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color(0.42, 0.25, 0.28, 0.85)
	vbox.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var scroll_center := CenterContainer.new()
	scroll_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_center)

	_viewer_grid = GridContainer.new()
	_viewer_grid.columns = VIEW_COLUMNS
	_viewer_grid.add_theme_constant_override("h_separation", 16)
	_viewer_grid.add_theme_constant_override("v_separation", 16)
	scroll_center.add_child(_viewer_grid)

	_viewer_empty = Label.new()
	_viewer_empty.text = "O inimigo ainda não descartou nenhuma carta."
	_viewer_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_viewer_empty.add_theme_font_size_override("font_size", 26)
	_viewer_empty.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	_viewer_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewer_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_viewer_empty)

# Mais recente primeiro.
func _fill_viewer() -> void:
	for c in _viewer_grid.get_children():
		c.queue_free()
	var pile: Array = deck_mgr_ref.discard_pile if deck_mgr_ref != null else []
	_viewer_title.text = "DESCARTE INIMIGO (%d)" % pile.size()
	_viewer_empty.visible = pile.is_empty()
	var cw: float = ActionCardVisual.CARD_WIDTH * VIEW_CARD_SCALE
	var ch: float = ActionCardVisual.CARD_HEIGHT * VIEW_CARD_SCALE
	for i in range(pile.size() - 1, -1, -1):
		var card: ActionCard = pile[i]
		if card == null:
			continue
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(cw, ch)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var visual := ActionCardVisual.new(card, true, VIEW_CARD_SCALE)
		visual.mouse_filter = Control.MOUSE_FILTER_STOP
		visual.mouse_entered.connect(func():
			_viewer_tooltip.show_tooltip(card, visual.global_position + Vector2(cw + 8.0, 0.0))
		)
		visual.mouse_exited.connect(func(): _viewer_tooltip.hide_tooltip())
		slot.add_child(visual)
		_viewer_grid.add_child(slot)
