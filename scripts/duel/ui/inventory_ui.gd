class_name InventoryUI
extends CanvasLayer

enum Tab { LAWS, CARDS }

# Cartas de ação no inventário: ampliadas (150x214 nativo x escala), em 5 colunas.
const CARD_SLOT_SCALE: float = 2.0
const CARD_COLUMNS: int = 5
const LAW_COLUMNS: int = 3

var modal_panel: PanelContainer
var grid_container: GridContainer
var count_label: Label
var empty_label: Label
var title_lbl: Label
var tooltip: RuleCardTooltip
var card_tooltip: ActionCardTooltip
var laws_tab_btn: Button
var cards_tab_btn: Button
var current_tab: int = Tab.LAWS

func _ready() -> void:
	layer = 95
	visible = false

const SAFE_BOTTOM: float = 80.0

func setup() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg_overlay = ColorRect.new()
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_overlay.color = Color(0.02, 0.03, 0.05, 0.84)
	add_child(bg_overlay)

	# Tooltip dedicado para o inventário
	tooltip = RuleCardTooltip.new()
	add_child(tooltip)

	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Folga embaixo: em janelas cortadas pela barra de tarefas a borda de baixo
	# não pode sumir; o modal fica centrado na área de cima.
	center.offset_bottom = -SAFE_BOTTOM
	add_child(center)

	modal_panel = PanelContainer.new()
	modal_panel.custom_minimum_size = Vector2(1800, 920)
	modal_panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.08, 0.09, 0.13, 0.98), Color(0.28, 0.65, 1.0), 28))
	center.add_child(modal_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	modal_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Cabeçalho
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title_lbl_local = Label.new()
	title_lbl = title_lbl_local
	title_lbl.text = "GRIMÓRIO DE LEIS ATIVAS"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 40)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 10)
	header_hbox.add_child(title_lbl)

	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 26)
	count_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	header_hbox.add_child(count_label)

	# Abas pra alternar entre Leis e Cartas
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(tabs_hbox)

	laws_tab_btn = Button.new()
	laws_tab_btn.text = "LEIS"
	laws_tab_btn.custom_minimum_size = Vector2(180, 48)
	laws_tab_btn.add_theme_font_size_override("font_size", 20)
	laws_tab_btn.pressed.connect(func(): _switch_tab(Tab.LAWS))
	tabs_hbox.add_child(laws_tab_btn)

	cards_tab_btn = Button.new()
	cards_tab_btn.text = "CARTAS"
	cards_tab_btn.custom_minimum_size = Vector2(180, 48)
	cards_tab_btn.add_theme_font_size_override("font_size", 20)
	cards_tab_btn.pressed.connect(func(): _switch_tab(Tab.CARDS))
	tabs_hbox.add_child(cards_tab_btn)

	var divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color(0.25, 0.3, 0.42, 0.85)
	vbox.add_child(divider)

	# Área Central com Rolagem
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var scroll_center = CenterContainer.new()
	scroll_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_center)

	grid_container = GridContainer.new()
	grid_container.columns = 3
	grid_container.add_theme_constant_override("h_separation", 48)
	grid_container.add_theme_constant_override("v_separation", 32)
	scroll_center.add_child(grid_container)

	empty_label = Label.new()
	empty_label.text = "Nenhuma Lei ativa no momento.\nObtenha novas Leis vencendo Duelos Fortes ou no Mercado."
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	empty_label.add_theme_font_size_override("font_size", 24)
	empty_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	vbox.add_child(empty_label)

	# Rodapé
	var footer_hbox = HBoxContainer.new()
	vbox.add_child(footer_hbox)

	var tip_lbl_local = Label.new()
	tip_lbl_local.name = "TipLabel"
	tip_lbl_local.text = "Passe o cursor sobre uma Lei para ler seus efeitos • [TAB] ou [ESC] para fechar"
	tip_lbl_local.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_lbl_local.add_theme_font_size_override("font_size", 20)
	tip_lbl_local.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	footer_hbox.add_child(tip_lbl_local)

	var close_btn = Button.new()
	close_btn.text = "FECHAR"
	close_btn.custom_minimum_size = Vector2(160, 48)
	close_btn.add_theme_font_size_override("font_size", 22)
	PixelUI.skin_button(close_btn, Color(0.9, 0.25, 0.3), "", "icone_fechar")
	close_btn.pressed.connect(func():
		if tooltip:
			tooltip.hide_tooltip()
		if card_tooltip:
			card_tooltip.hide_tooltip()
		visible = false
	)
	footer_hbox.add_child(close_btn)

	_update_tab_styles()

func _switch_tab(tab: int) -> void:
	current_tab = tab
	_update_tab_styles()
	refresh_current_tab()

func _update_tab_styles() -> void:
	# Aba ativa = tinta verde; inativa = sprite neutro mais escuro.
	PixelUI.skin_button(laws_tab_btn, Color(0.4, 0.85, 0.45) if current_tab == Tab.LAWS else Color(0.35, 0.35, 0.4), "", "icone_leis")
	PixelUI.skin_button(cards_tab_btn, Color(0.4, 0.85, 0.45) if current_tab == Tab.CARDS else Color(0.35, 0.35, 0.4), "", "icone_cartas")

func toggle_visibility() -> void:
	visible = not visible
	if visible:
		refresh_current_tab()
	else:
		if tooltip:
			tooltip.hide_tooltip()
		if card_tooltip:
			card_tooltip.hide_tooltip()

# Abre o inventário já numa aba específica (usado pelo botão de monte de
# cartas na HUD, que deve abrir direto em "CARTAS").
func open_on_tab(tab: int) -> void:
	current_tab = tab
	_update_tab_styles()
	visible = true
	refresh_current_tab()

func refresh_current_tab() -> void:
	if current_tab == Tab.LAWS:
		refresh_laws()
	else:
		refresh_cards()

func refresh_laws() -> void:
	if tooltip:
		tooltip.hide_tooltip()
	if card_tooltip:
		card_tooltip.hide_tooltip()

	title_lbl.text = "GRIMÓRIO DE LEIS ATIVAS"
	var tip_node = modal_panel.find_child("TipLabel", true, false)
	if tip_node:
		tip_node.text = "Passe o cursor sobre uma Lei para ler seus efeitos • [TAB] ou [ESC] para fechar"

	for c in grid_container.get_children():
		c.queue_free()

	var rules = RunManager.active_rules if RunManager != null else []
	count_label.text = "LEIS: %d / 6" % rules.size()

	if rules.is_empty():
		empty_label.text = "Nenhuma Lei ativa no momento.\nObtenha novas Leis vencendo Duelos Fortes ou no Mercado."
		empty_label.visible = true
		grid_container.visible = false
		return

	empty_label.visible = false
	grid_container.visible = true
	grid_container.columns = LAW_COLUMNS
	grid_container.add_theme_constant_override("h_separation", 56)
	grid_container.add_theme_constant_override("v_separation", 24)

	for rule in rules:
		grid_container.add_child(_create_law_slot(rule))

func _create_law_slot(rule: RuleCard) -> Control:
	var wrapper = VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", 10)

	# Carta quadrada com sprite frontal exibido e hover conectado ao tooltip
	var card_visual = RuleCardVisual.new(rule, tooltip, true)
	wrapper.add_child(card_visual)

	# Botão para revogar/descartar lei do grimório
	var revoke_btn = Button.new()
	revoke_btn.text = "REVOGAR"
	revoke_btn.custom_minimum_size = Vector2(RuleCardVisual.CARD_SIZE, 38)
	revoke_btn.add_theme_font_size_override("font_size", 16)
	PixelUI.skin_button(revoke_btn, Color(0.85, 0.2, 0.25), "", "icone_descarte")
	revoke_btn.pressed.connect(func():
		if RunManager != null:
			RunManager.remove_rule(rule.id)
			refresh_laws()
	)
	# Tutorial: revogar leis fica bloqueado (evita quebrar a lição).
	if TutorialManager.is_active:
		revoke_btn.disabled = true
		revoke_btn.visible = false
	wrapper.add_child(revoke_btn)

	return wrapper

func refresh_cards() -> void:
	if tooltip:
		tooltip.hide_tooltip()
	if card_tooltip:
		card_tooltip.hide_tooltip()

	title_lbl.text = "INVENTARIO DE CARTAS"
	var tip_node = modal_panel.find_child("TipLabel", true, false)
	if tip_node:
		tip_node.text = "Passe o cursor sobre uma carta para ler seus efeitos • [TAB] ou [ESC] para fechar"

	for c in grid_container.get_children():
		c.queue_free()

	var cards = RunManager.player_deck if RunManager != null else []
	var max_size = RunManager.MAX_PLAYER_DECK_SIZE if RunManager != null else 20
	count_label.text = "CARTAS: %d / %d" % [cards.size(), max_size]

	if cards.is_empty():
		empty_label.text = "Nenhuma carta no inventario ainda.\nObtenha cartas vencendo Duelos, na Loja ou apostando."
		empty_label.visible = true
		grid_container.visible = false
		return

	empty_label.visible = false
	grid_container.visible = true
	grid_container.columns = CARD_COLUMNS
	grid_container.add_theme_constant_override("h_separation", 32)
	grid_container.add_theme_constant_override("v_separation", 28)

	for card in cards:
		grid_container.add_child(_create_card_slot(card))

func _create_card_slot(card: ActionCard) -> Control:
	var wrapper = VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", 10)

	var visual = ActionCardVisual.new(card, true, CARD_SLOT_SCALE)
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if card_tooltip:
			var tip_pos = visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0)
			card_tooltip.show_tooltip(card, tip_pos)
	)
	visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)
	wrapper.add_child(visual)

	return wrapper
