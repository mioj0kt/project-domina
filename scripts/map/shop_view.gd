class_name ShopView
extends Control

const MAP_SCENE_PATH = "res://map_view.tscn"
const TUTORIAL_MAP_SCENE_PATH = "res://tutorial_map_view.tscn"

# RuleCardVisual.CARD_SIZE cresceu bastante (320) pra ficar grande no quadro
# de leis do HUD; aqui as leis aparecem lado a lado num HBoxContainer, então
# em tamanho cheio ficam gigantes e estouram a tela. Essa escala traz de
# volta um tamanho de exibição razoável só pra loja.
const SHOP_CARD_SCALE: float = 0.85
# Escala das Cartas de Ação à venda (base 150x224).
const SHOP_ACTION_SCALE: float = 1.45

var hud_bar: HUDBar
var inventory_ui: InventoryUI
var rule_tooltip: RuleCardTooltip
var discard_modal: RuleDiscardModal
var pending_law_index: int = -1
var card_tooltip: ActionCardTooltip

var laws_for_sale: Array[RuleCard] = []
var cards_for_sale: Array[ActionCard] = []

var laws_container: HBoxContainer
var cards_container: HBoxContainer
var reroll_btn: Button
var remove_card_btn: Button

# As Leis só fazem a animação de virar na primeira vez que a loja abre;
# depois (reroll de Cartas, compras) são redesenhadas já viradas.
var _laws_revealed: bool = false
# Custos da Loja (sobem a cada uso): reroll de Cartas e remoção de Carta do baralho.
const REROLL_START_COST: int = 4
const REROLL_COST_STEP: int = 2
const REMOVE_START_COST: int = 8
const REMOVE_COST_STEP: int = 4
func _law_price(law: RuleCard) -> int:
	return RunManager.get_shop_price(law.cost) if RunManager != null else law.cost

func _card_price(card: ActionCard) -> int:
	return RunManager.get_shop_price(card.cost_gold) if RunManager != null else card.cost_gold

var card_reroll_cost: int = REROLL_START_COST
var remove_card_cost: int = REMOVE_START_COST

# Modal de Remoção de Carta
var tutorial_guide_view: TutorialGuideView
var leave_btn: Button
# Tutorial: enquanto o Guia fala (título + falas iniciais), a Loja fica travada.
var tutorial_intro_playing: bool = false
var remove_modal_layer: CanvasLayer
var remove_grid: HBoxContainer

func _ready() -> void:
	_generate_laws_stock()
	_reroll_cards_stock()
	_tutorial_ensure_law_gold()
	_setup_ui()
	if TutorialManager.is_active:
		_setup_tutorial()

# Tutorial: a Lei do estoque didático precisa SEMPRE caber no ouro do jogador
# (rede de segurança contra softlock se ele chegar aqui com pouco ouro).
func _tutorial_ensure_law_gold() -> void:
	if not TutorialManager.is_active or RunManager == null or laws_for_sale.is_empty():
		return
	if RunManager.gold < _law_price(laws_for_sale[0]):
		RunManager.gold = maxi(RunManager.gold, TutorialManager.TUTORIAL_GOLD)

# Tutorial: enquanto a Lei pedida não foi comprada, Cartas ficam travadas (gastar
# o ouro antes impediria de comprar a Lei). Reroll e Remover ficam travados no
# tutorial inteiro: só gastariam ouro que os objetivos precisam.
func _tutorial_cards_locked() -> bool:
	if not TutorialManager.is_active:
		return false
	for id in TutorialManager.SHOP_LAW_IDS:
		if not _tutorial_owns_rule(id):
			return true
	return false

func _tutorial_header_locked() -> bool:
	return TutorialManager.is_active

func _generate_laws_stock() -> void:
	laws_for_sale.clear()
	# Tutorial: a Loja vende só o que a lição precisa (estoque didático).
	if TutorialManager.is_active:
		for rule in LootTables.get_all_rules():
			if TutorialManager.SHOP_LAW_IDS.has(rule.id) and not _tutorial_owns_rule(rule.id):
				laws_for_sale.append(rule)
		return
	var owned_rule_ids: Array[String] = []
	if RunManager != null:
		for r in RunManager.active_rules:
			owned_rule_ids.append(r.id)

	laws_for_sale = LootTables.get_random_rules(3, owned_rule_ids)

func _tutorial_owns_rule(rule_id: String) -> bool:
	if RunManager == null:
		return false
	for r in RunManager.active_rules:
		if r.id == rule_id:
			return true
	return false

func _reroll_cards_stock() -> void:
	if TutorialManager.is_active:
		cards_for_sale.clear()
		for card in LootTables.get_all_action_cards():
			if TutorialManager.SHOP_CARD_IDS.has(card.id):
				cards_for_sale.append(card)
		return
	cards_for_sale = LootTables.get_random_action_cards(3)

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "ShopUILayer"
	canvas.layer = 70
	add_child(canvas)
	add_child(BiomeBackground.new())

	# Tooltips dedicados
	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)

	discard_modal = RuleDiscardModal.new()
	discard_modal.rule_replaced.connect(_on_law_replaced)
	add_child(discard_modal)

	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	hud_bar = HUDBar.new()
	canvas.add_child(hud_bar)
	hud_bar.open_laws_requested.connect(_toggle_inventory)

	inventory_ui = InventoryUI.new()
	canvas.add_child(inventory_ui)
	inventory_ui.setup()

	# Container principal com Centralização Absoluta
	var center_box = VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_box.offset_left = 60.0
	center_box.offset_right = -60.0
	center_box.offset_top = 26.0
	center_box.offset_bottom = -20.0
	center_box.add_theme_constant_override("separation", 12)
	center_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	canvas.add_child(center_box)

	# Cabeçalho Principal
	var header = Label.new()
	header.text = "MERCADO DO TABULEIRO"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 54)
	header.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	header.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	header.add_theme_constant_override("outline_size", 10)
	center_box.add_child(header)

	# -------------------------------------------------------------
	# SEÇÃO 1: LEIS PERMANENTES
	# -------------------------------------------------------------
	var laws_title = Label.new()
	laws_title.text = "― LEIS PERMANENTES ―"
	laws_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	laws_title.add_theme_font_size_override("font_size", 30)
	laws_title.add_theme_color_override("font_color", Color(0.5, 0.82, 1.0))
	center_box.add_child(laws_title)

	laws_container = HBoxContainer.new()
	laws_container.alignment = BoxContainer.ALIGNMENT_CENTER
	laws_container.add_theme_constant_override("separation", 36)
	center_box.add_child(laws_container)
	_render_laws_stock()

	# -------------------------------------------------------------
	# SEÇÃO 2: CARTAS TÁTICAS + BOTÕES REROLL E REMOVER
	# -------------------------------------------------------------
	var cards_header_hbox = HBoxContainer.new()
	cards_header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_header_hbox.add_theme_constant_override("separation", 24)
	center_box.add_child(cards_header_hbox)

	var cards_title = Label.new()
	cards_title.text = "― CARTAS DE AÇÃO (DECK) ―"
	cards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_title.add_theme_font_size_override("font_size", 30)
	cards_title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
	cards_header_hbox.add_child(cards_title)

	reroll_btn = Button.new()
	reroll_btn.custom_minimum_size = Vector2(250, 50)
	reroll_btn.add_theme_font_size_override("font_size", 22)
	reroll_btn.pressed.connect(_on_reroll_cards_pressed)
	cards_header_hbox.add_child(reroll_btn)

	remove_card_btn = Button.new()
	remove_card_btn.custom_minimum_size = Vector2(290, 50)
	remove_card_btn.add_theme_font_size_override("font_size", 22)
	remove_card_btn.pressed.connect(_on_remove_card_clicked)
	cards_header_hbox.add_child(remove_card_btn)

	_update_header_buttons_state()

	cards_container = HBoxContainer.new()
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 32)
	center_box.add_child(cards_container)
	_render_cards_stock()

	# Rodapé: Botão de saída
	var footer_box = HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_child(footer_box)

	leave_btn = Button.new()
	leave_btn.text = "CONTINUAR VIAGEM"
	leave_btn.custom_minimum_size = Vector2(340, 60)
	leave_btn.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(leave_btn, Color(0.4, 0.7, 0.9), "", "icone_mapa")
	leave_btn.pressed.connect(_on_leave_pressed)
	footer_box.add_child(leave_btn)

	_build_remove_modal_ui()

func _render_laws_stock() -> void:
	for child in laws_container.get_children():
		child.queue_free()

	for i in range(laws_for_sale.size()):
		var law = laws_for_sale[i]
		var law_widget = _create_law_item_ui(law, i)
		laws_container.add_child(law_widget)
	_laws_revealed = true

func _create_law_item_ui(law: RuleCard, index: int) -> Control:
	var wrapper = VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", 8)

	var card_visual = RuleCardVisual.new(law, rule_tooltip, _laws_revealed, SHOP_CARD_SCALE)
	wrapper.add_child(card_visual)

	var current_gold = RunManager.gold if RunManager != null else 0
	var can_afford = current_gold >= _law_price(law)
	var has_room = RunManager != null and RunManager.can_add_rule(law)

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(RuleCardVisual.CARD_SIZE * SHOP_CARD_SCALE, 52)
	# Sem espaço (limite/incompatibilidade): comprar abre a troca de Lei.
	buy_btn.text = "%d OURO" % _law_price(law) if has_room else "TROCAR · %d OURO" % _law_price(law)
	buy_btn.disabled = not can_afford
	buy_btn.add_theme_font_size_override("font_size", 22)

	if can_afford:
		PixelUI.skin_button(buy_btn, Color(0.3, 0.9, 0.4) if has_room else Color(0.95, 0.65, 0.25), "", "moeda_pequena")
		buy_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	else:
		PixelUI.skin_button(buy_btn, Color.WHITE, "", "moeda_pequena")
		buy_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))

	buy_btn.pressed.connect(_on_buy_law_pressed.bind(index))
	wrapper.add_child(buy_btn)

	if not _laws_revealed:
		card_visual.play_flip_reveal(0.1 + (index * 0.12))
	return wrapper

func _render_cards_stock() -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for i in range(cards_for_sale.size()):
		var card = cards_for_sale[i]
		var card_widget = _create_action_card_shop_item_ui(card, i)
		cards_container.add_child(card_widget)

func _create_action_card_shop_item_ui(card: ActionCard, index: int) -> Control:
	var wrapper = VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", 8)

	# Card visual com tamanho vertical proporcional (150x220)
	var card_visual = ActionCardVisual.new(card, true, SHOP_ACTION_SCALE)
	card_visual.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.add_child(card_visual)

	# Hover conectado ao ActionCardTooltip
	card_visual.mouse_entered.connect(func():
		if card_tooltip:
			var tip_pos = card_visual.global_position + Vector2(ActionCardVisual.CARD_WIDTH * SHOP_ACTION_SCALE / 2.0, 0.0)
			card_tooltip.show_tooltip(card, tip_pos)
	)
	card_visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)

	var current_gold = RunManager.gold if RunManager != null else 0
	var deck_full = RunManager != null and not RunManager.can_add_card_to_deck()
	var cards_locked: bool = _tutorial_cards_locked()
	var can_afford = current_gold >= _card_price(card) and not deck_full and not cards_locked

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(ActionCardVisual.CARD_WIDTH * SHOP_ACTION_SCALE, 52)
	buy_btn.text = "INVENTARIO CHEIO" if deck_full else ("COMPRE A LEI ANTES" if cards_locked else "%d OURO" % _card_price(card))
	buy_btn.disabled = not can_afford
	buy_btn.add_theme_font_size_override("font_size", 22)

	if can_afford:
		PixelUI.skin_button(buy_btn, Color(0.3, 0.9, 0.4), "", "moeda_pequena")
		buy_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	else:
		PixelUI.skin_button(buy_btn, Color.WHITE, "", "moeda_pequena")
		buy_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))

	buy_btn.pressed.connect(_on_buy_action_card_pressed.bind(index))
	wrapper.add_child(buy_btn)

	card_visual.play_flip_reveal(0.1 + (index * 0.12))
	return wrapper

func _update_header_buttons_state() -> void:
	var current_gold = RunManager.gold if RunManager != null else 0

	# 1. Reroll
	if reroll_btn != null:
		var can_reroll = current_gold >= card_reroll_cost and not _tutorial_header_locked()
		reroll_btn.text = "REROLL: %d OURO" % card_reroll_cost
		reroll_btn.disabled = not can_reroll
		if can_reroll:
			PixelUI.skin_button(reroll_btn, Color(1.0, 0.65, 0.2), "", "moeda_pequena")
			reroll_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
		else:
			PixelUI.skin_button(reroll_btn, Color.WHITE, "", "moeda_pequena")
			reroll_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))

	# 2. Remover Carta
	if remove_card_btn != null:
		var has_cards = RunManager != null and not RunManager.player_deck.is_empty()
		var can_remove = current_gold >= remove_card_cost and has_cards and not _tutorial_header_locked()
		remove_card_btn.text = "REMOVER: %d OURO" % remove_card_cost
		remove_card_btn.disabled = not can_remove
		if can_remove:
			PixelUI.skin_button(remove_card_btn, Color(0.95, 0.3, 0.35), "", "moeda_pequena")
			remove_card_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
		else:
			PixelUI.skin_button(remove_card_btn, Color.WHITE, "", "moeda_pequena")
			remove_card_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))

func _on_reroll_cards_pressed() -> void:
	if tutorial_intro_playing or _tutorial_header_locked():
		return
	if RunManager != null and RunManager.gold >= card_reroll_cost:
		RunManager.gold -= card_reroll_cost
		card_reroll_cost += REROLL_COST_STEP
		_reroll_cards_stock()
		_refresh_store_state()

func _on_buy_law_pressed(index: int) -> void:
	if tutorial_intro_playing:
		return
	if index < 0 or index >= laws_for_sale.size():
		return

	var law = laws_for_sale[index]
	if RunManager == null or RunManager.gold < _law_price(law):
		return
	if not RunManager.can_add_rule(law):
		# Limite de Leis: só cobra se o jogador revogar uma e a nova entrar.
		pending_law_index = index
		discard_modal.prompt_replace(law)
		return
	# Só cobra se a Lei realmente entrar.
	if RunManager.add_rule(law):
		RunManager.gold -= _law_price(law)
		RunManager.register_shop_purchase()
		laws_for_sale.remove_at(index)
		TutorialManager.report_event("shop_buy_law")
		if TutorialManager.is_active and hud_bar != null and hud_bar.is_laws_collapsed():
			_refresh_store_state()
			_tutorial_reveal_law_board()
			return
	_refresh_store_state()

func _on_law_replaced(_old: RuleCard, new_rule: RuleCard) -> void:
	var idx = laws_for_sale.find(new_rule)
	if idx >= 0:
		RunManager.gold -= _law_price(new_rule)
		RunManager.register_shop_purchase()
		laws_for_sale.remove_at(idx)
	pending_law_index = -1
	_refresh_store_state()

func _on_buy_action_card_pressed(index: int) -> void:
	if tutorial_intro_playing or _tutorial_cards_locked():
		return
	if index < 0 or index >= cards_for_sale.size():
		return

	var card = cards_for_sale[index]
	# Mesmo princípio: respeita o limite do inventário antes de cobrar.
	if RunManager != null and RunManager.gold >= _card_price(card) and RunManager.add_card_to_deck(card):
		RunManager.gold -= _card_price(card)
		RunManager.register_shop_purchase()
		cards_for_sale.remove_at(index)
		TutorialManager.report_event("shop_buy_card")
		if TutorialManager.is_active and hud_bar != null:
			hud_bar.tutorial_reveal_piles()
	_refresh_store_state()

func _refresh_store_state() -> void:
	if card_tooltip:
		card_tooltip.hide_tooltip()
	if rule_tooltip:
		rule_tooltip.hide_tooltip()

	if hud_bar:
		hud_bar.update_gold()
		hud_bar.refresh_deck()

	_update_header_buttons_state()
	_render_laws_stock()
	_render_cards_stock()

# =============================================================
# MODAL DE REMOÇÃO DE CARTA (PURGA DE DECK)
# =============================================================
func _build_remove_modal_ui() -> void:
	remove_modal_layer = CanvasLayer.new()
	remove_modal_layer.layer = 130
	remove_modal_layer.visible = false
	add_child(remove_modal_layer)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.90)
	remove_modal_layer.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	remove_modal_layer.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 600)
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.08, 0.1, 0.15, 0.98), Color(0.95, 0.35, 0.4), 24))
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	margin.add_child(vb)

	var title = Label.new()
	title.text = "REMOVER UMA CARTA DO DECK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	vb.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Selecione a carta que deseja destruir definitivamente do seu baralho:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92))
	vb.add_child(subtitle)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var scroll_center = CenterContainer.new()
	scroll_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_center)

	remove_grid = HBoxContainer.new()
	remove_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	remove_grid.add_theme_constant_override("separation", 24)
	scroll_center.add_child(remove_grid)

	var cancel_btn = Button.new()
	cancel_btn.text = "CANCELAR"
	cancel_btn.custom_minimum_size = Vector2(220, 46)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.add_theme_font_size_override("font_size", 20)
	PixelUI.skin_button(cancel_btn, Color(0.4, 0.45, 0.55), "", "icone_voltar")
	cancel_btn.pressed.connect(func():
		remove_modal_layer.visible = false
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)
	vb.add_child(cancel_btn)

func _on_remove_card_clicked() -> void:
	if tutorial_intro_playing or _tutorial_header_locked():
		return
	if RunManager == null or RunManager.gold < remove_card_cost:
		return

	for child in remove_grid.get_children():
		child.queue_free()

	for i in range(RunManager.player_deck.size()):
		var card = RunManager.player_deck[i]
		var item = _create_remove_card_slot(card, i)
		remove_grid.add_child(item)

	remove_modal_layer.visible = true

func _create_remove_card_slot(card: ActionCard, deck_idx: int) -> Control:
	var wrapper = VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", 10)

	var card_visual = ActionCardVisual.new(card, true)
	card_visual.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.add_child(card_visual)

	card_visual.mouse_entered.connect(func():
		if card_tooltip:
			var tip_pos = card_visual.global_position + Vector2(ActionCardVisual.CARD_WIDTH / 2.0, 0.0)
			card_tooltip.show_tooltip(card, tip_pos)
	)
	card_visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)

	var destroy_btn = Button.new()
	destroy_btn.text = "DESTRUIR"
	destroy_btn.custom_minimum_size = Vector2(ActionCardVisual.CARD_WIDTH, 40)
	destroy_btn.add_theme_font_size_override("font_size", 17)
	PixelUI.skin_button(destroy_btn, Color(0.95, 0.25, 0.3), "", "icone_descarte")
	destroy_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))

	destroy_btn.pressed.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
		RunManager.gold -= remove_card_cost
		remove_card_cost += REMOVE_COST_STEP # Escala de custo para remoções subsequentes
		RunManager.player_deck.remove_at(deck_idx)
		remove_modal_layer.visible = false
		_refresh_store_state()
	)
	wrapper.add_child(destroy_btn)

	return wrapper

func _toggle_inventory() -> void:
	if tutorial_intro_playing or (TutorialManager.is_active and hud_bar != null and hud_bar.is_laws_collapsed()):
		return
	if inventory_ui:
		inventory_ui.toggle_visibility()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if remove_modal_layer and remove_modal_layer.visible:
				remove_modal_layer.visible = false
				if card_tooltip:
					card_tooltip.hide_tooltip()
				get_viewport().set_input_as_handled()
			elif inventory_ui and inventory_ui.visible:
				inventory_ui.visible = false
				get_viewport().set_input_as_handled()

func _on_leave_pressed() -> void:
	if TutorialManager.is_active:
		if leave_btn != null:
			leave_btn.disabled = true
		if tutorial_guide_view != null:
			await tutorial_guide_view.play_sequence(TutorialManager.get_shop_done_lines())
		SceneTransition.go(TUTORIAL_MAP_SCENE_PATH)
		return
	SceneTransition.go(MAP_SCENE_PATH)

# =============================================================
# TUTORIAL (Lição 2)
# =============================================================
func _setup_tutorial() -> void:
	tutorial_guide_view = TutorialGuideView.new()
	tutorial_guide_view.spot_resolver = _tutorial_spot_rect
	add_child(tutorial_guide_view)
	inventory_ui.visibility_changed.connect(_on_tutorial_inventory_visibility)
	TutorialManager.objectives_completed.connect(_on_tutorial_objectives_completed)
	# Só dá para sair da Loja depois de cumprir os objetivos da lição.
	leave_btn.disabled = true
	# HUD enxuta: só o ouro. O quadro de Leis desce depois da 1ª Lei comprada.
	hud_bar.tutorial_collapse()
	# Mantém a altura da fileira de Leis mesmo depois de comprar (o layout
	# não "pula" e os destaques do Guia continuam no lugar).
	laws_container.custom_minimum_size = Vector2(0, RuleCardVisual.CARD_SIZE * SHOP_CARD_SCALE + 62.0)
	_run_tutorial_intro()

func _run_tutorial_intro() -> void:
	tutorial_intro_playing = true
	await get_tree().process_frame
	await get_tree().process_frame
	var step = TutorialManager.current_step
	await tutorial_guide_view.play_title_card(
		"LIÇÃO %d de %d" % [TutorialManager.get_lesson_number(step), TutorialManager.LESSON_COUNT],
		TutorialManager.get_lesson_title(step),
		TutorialManager.get_lesson_goal(step))
	await tutorial_guide_view.play_sequence(TutorialManager.get_shop_lines())
	tutorial_intro_playing = false
	TutorialManager.begin_objectives()

# Depois da 1ª Lei comprada: o quadro de Leis desce do alto da tela e o Guia
# explica. A Loja fica travada enquanto isso.
func _tutorial_reveal_law_board() -> void:
	tutorial_intro_playing = true
	await get_tree().create_timer(0.8).timeout   # dá tempo de ver o ouro diminuir
	await hud_bar.tutorial_reveal_laws()
	await get_tree().create_timer(0.25).timeout
	await tutorial_guide_view.play_sequence(TutorialManager.get_shop_law_board_lines())
	tutorial_intro_playing = false

func _on_tutorial_inventory_visibility() -> void:
	if inventory_ui.visible:
		TutorialManager.report_event("open_laws")
	else:
		TutorialManager.report_event("close_laws")

func _on_tutorial_objectives_completed() -> void:
	if leave_btn != null:
		leave_btn.disabled = false
		await get_tree().process_frame
		tutorial_guide_view.pulse_rect(_tutorial_spot_rect("shop_leave"), 5.0)

func _tutorial_spot_rect(id: String) -> Rect2:
	match id:
		"gold":
			# Painel inteiro do ouro (cresceu junto com a HUD).
			if hud_bar != null and hud_bar.gold_panel_ctrl != null:
				return hud_bar.gold_panel_ctrl.get_global_rect().grow(4.0)
		"law_board":
			if hud_bar != null and hud_bar.law_board != null:
				return Rect2(hud_bar.law_board.global_position, hud_bar.law_board.size)
		"laws_btn":
			if hud_bar != null and hud_bar.laws_btn != null:
				return hud_bar.laws_btn.get_global_rect().grow(4.0)
		"laws_row", "shop_buy_law":
			return _children_rect(laws_container).grow(8.0)
		"cards_row", "shop_buy_card":
			return _children_rect(cards_container).grow(8.0)
		"shop_tools":
			return Rect2(reroll_btn.global_position, Vector2(remove_card_btn.global_position.x + remove_card_btn.size.x - reroll_btn.global_position.x, reroll_btn.size.y)).grow(6.0)
		"shop_leave":
			if leave_btn != null:
				return leave_btn.get_global_rect().grow(6.0)
	return Rect2()

# União dos retângulos dos filhos (a caixa em si ocupa a largura toda).
func _children_rect(box: Control) -> Rect2:
	var r := Rect2()
	var first := true
	for ch in box.get_children():
		if ch is Control and not ch.is_queued_for_deletion():
			r = (ch as Control).get_global_rect() if first else r.merge((ch as Control).get_global_rect())
			first = false
	return r if not first else box.get_global_rect()
