class_name HUDBar
extends CanvasLayer

signal open_laws_requested()
signal open_cards_requested()

# Aumentado de novo (104 -> 140 -> 180 -> 186) junto com RuleCardVisual.
# CARD_SIZE (180 -> 240 -> 320). Coube mais um pouco depois de apertar o
# v_separation da grade (ver _build_side_panel) — ainda cabe dentro do
# DECK_PANEL_H/PANEL_W atuais sem esticar o quadro de madeira de novo.
# Quadro de Leis (LawBoard): altura fixa; a largura sai da proporção do
# sprite (370:527). Os slots (≈178 px) vêm do próprio LawBoard.
const DECK_PANEL_H: float = 610.0
const PANEL_W: float = 440.0
# Linha do topo (Leis + Ouro): botões grandes, sprites ampliados 2x.
const TOP_BTN_H: float = 52.0

var gold_label: Label
var gold_panel_ctrl: Control   # painel inteiro do ouro (para destaques do tutorial)
var laws_btn: Button
var rule_tooltip: RuleCardTooltip
var side_container: VBoxContainer
var slot_containers: Array[Control] = []
var law_board: LawBoard
var _current_rules: Array[RuleCard] = []

# Pilhas Visuais integradas
var deck_mgr_ref: CardDeckManager
var draw_pile_widget: Control
var discard_pile_widget: Control
var draw_deck_stack: Control
var discard_deck_stack: Control
var cards_count_label: Label

func _ready() -> void:
	layer = 80
	_build_side_panel()

	if RunManager != null and not RunManager.rules_updated.is_connected(refresh_deck):
		RunManager.rules_updated.connect(refresh_deck)

func setup_deck_manager(deck_mgr: CardDeckManager) -> void:
	deck_mgr_ref = deck_mgr
	deck_mgr_ref.hand_updated.connect(update_pile_visual_stacks)
	deck_mgr_ref.card_played.connect(_on_card_played_animation)
	update_pile_visual_stacks()

func _build_side_panel() -> void:
	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)

	var root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	side_container = VBoxContainer.new()
	side_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_container.add_theme_constant_override("separation", 14)

	# Ancorado no meio-esquerdo da tela
	side_container.anchor_left = 0.0
	side_container.anchor_right = 0.0
	side_container.anchor_top = 0.5
	side_container.anchor_bottom = 0.5
	side_container.offset_left = 40.0
	side_container.offset_right = 40.0 + PANEL_W
	side_container.grow_horizontal = Control.GROW_DIRECTION_END
	side_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	root_ctrl.add_child(side_container)

	# -------------------------------------------------------------------
	# 1. TOPO: Botão Leis (TAB) + Painel de Ouro lado a lado, cada um com
	# metade da largura (dividindo a mesma linha) e metade da altura de
	# antes — a pedido do usuário, pra ocupar bem menos espaço no HUD.
	# -------------------------------------------------------------------
	const TOP_ROW_SEPARATION: float = 10.0
	var top_row = HBoxContainer.new()
	@warning_ignore("narrowing_conversion")
	top_row.add_theme_constant_override("separation", TOP_ROW_SEPARATION)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_container.add_child(top_row)

	# Botão de Leis e painel de ouro mais estreitos que o quadro, centralizados.
	var half_w = (PANEL_W - TOP_ROW_SEPARATION) * 0.5
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.custom_minimum_size = Vector2(PANEL_W, 0)

	laws_btn = Button.new()
	laws_btn.text = "LEIS (TAB)"
	laws_btn.custom_minimum_size = Vector2(half_w, TOP_BTN_H)
	laws_btn.add_theme_font_size_override("font_size", 24)
	# Botão com o painel "leis" (ícone à esquerda); hover/pressed só mudam o brilho.
	var laws_style = PixelUI.make_hud_icon_panel("painel_leis", 30, 2)
	var laws_hover = PixelUI.make_hud_icon_panel("painel_leis", 30, 2, Color(1.25, 1.2, 1.1))
	var laws_pressed = PixelUI.make_hud_icon_panel("painel_leis", 30, 2, Color(0.8, 0.8, 0.8))
	laws_btn.add_theme_stylebox_override("normal", laws_style)
	laws_btn.add_theme_stylebox_override("hover", laws_hover)
	laws_btn.add_theme_stylebox_override("pressed", laws_pressed)
	laws_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	laws_btn.add_theme_color_override("font_color", Color(0.96, 0.89, 0.72))
	laws_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.65))
	laws_btn.pressed.connect(func(): open_laws_requested.emit())
	top_row.add_child(laws_btn)
	# Ícone no slot da esquerda do painel (o sprite vem vazio ali).
	var laws_icon = PixelUI.make_hud_icon("icone_leis", 32.0)
	laws_icon.position = Vector2(14, (TOP_BTN_H - 32.0) * 0.5)
	laws_icon.size = Vector2(32, 32)
	laws_btn.add_child(laws_icon)

	var gold_panel = PanelContainer.new()
	gold_panel.custom_minimum_size = Vector2(half_w, TOP_BTN_H)
	gold_panel.add_theme_stylebox_override("panel", PixelUI.make_hud_icon_panel("painel_dinheiro", 30, 2))
	# O painel (PanelContainer) estica filhos; o ícone vai num Control por fora,
	# na mesma posição do ícone do botão de Leis (slot à esquerda do sprite).
	var gold_wrap = Control.new()
	gold_wrap.custom_minimum_size = Vector2(half_w, TOP_BTN_H)
	gold_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_panel_ctrl = gold_wrap
	top_row.add_child(gold_wrap)
	gold_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	gold_wrap.add_child(gold_panel)
	var gold_icon = PixelUI.make_hud_icon("icone_dinheiro", 32.0)
	gold_icon.position = Vector2(14, (TOP_BTN_H - 32.0) * 0.5)
	gold_icon.size = Vector2(32, 32)
	gold_wrap.add_child(gold_icon)

	var gold_hbox = HBoxContainer.new()
	gold_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_panel.add_child(gold_hbox)

	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_hbox.add_child(gold_label)
	update_gold()

	# -------------------------------------------------------------------
	# 2. SLOTS 3x2 DE LEIS — painel com fundo de madeira, cada slot mostra
	# a carta de Lei real (RuleCardVisual, já virada de frente) em miniatura,
	# igual ao espelho do lado inimigo (enemy_hud_bar.gd).
	# -------------------------------------------------------------------
	var board_row = HBoxContainer.new()
	board_row.custom_minimum_size = Vector2(PANEL_W, DECK_PANEL_H)
	board_row.alignment = BoxContainer.ALIGNMENT_CENTER
	board_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_container.add_child(board_row)

	law_board = LawBoard.new(DECK_PANEL_H)
	board_row.add_child(law_board)

	slot_containers.clear()
	for i in range(law_board.slots.size()):
		var slot = law_board.slots[i]
		slot.mouse_entered.connect(_on_rule_slot_hovered.bind(i))
		slot.mouse_exited.connect(_on_rule_slot_unhovered)
		slot_containers.append(slot)

	refresh_deck()

	# -------------------------------------------------------------------
	# 3. PILHAS VISUAIS (COMPRA E DESCARTE) - Abaixo do Ouro sem colisão
	# A pilha de compra também funciona como acesso ao inventário de cartas
	# fora de batalha: clicável, e mostra um contador quando não há duelo
	# ativo (ver refresh_cards_inventory_count()).
	# -------------------------------------------------------------------
	var piles_hbox = HBoxContainer.new()
	piles_hbox.custom_minimum_size = Vector2(PANEL_W, 140)
	piles_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	piles_hbox.add_theme_constant_override("separation", 16)
	piles_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_container.add_child(piles_hbox)

	draw_pile_widget = _create_pile_display("icone_deck")
	draw_pile_widget.mouse_filter = Control.MOUSE_FILTER_STOP
	draw_pile_widget.gui_input.connect(_on_draw_pile_gui_input)
	piles_hbox.add_child(draw_pile_widget)
	draw_deck_stack = draw_pile_widget.get_node("StackContainer")

	cards_count_label = Label.new()
	cards_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cards_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cards_count_label.add_theme_font_size_override("font_size", 22)
	cards_count_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	cards_count_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	cards_count_label.add_theme_constant_override("outline_size", 5)
	cards_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_pile_widget.add_child(cards_count_label)

	discard_pile_widget = _create_pile_display("icone_descarte")
	# O selo do descarte só aparece quando há cartas na pilha.
	discard_pile_widget.get_node("Badge").visible = false
	piles_hbox.add_child(discard_pile_widget)
	discard_deck_stack = discard_pile_widget.get_node("StackContainer")

	refresh_cards_inventory_count()

func _create_pile_display(icon_file: String = "") -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(105, 140)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stack_container = Control.new()
	stack_container.name = "StackContainer"
	stack_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stack_container)

	# Selo com o ícone da pilha (compra/descarte) no canto superior esquerdo.
	if icon_file != "":
		var badge = PixelUI.make_hud_icon(icon_file, 32.0)
		badge.position = Vector2(-6, -8)
		badge.size = Vector2(32, 32)
		badge.z_index = 5
		badge.name = "Badge"
		root.add_child(badge)

	return root

func _on_draw_pile_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_cards_requested.emit()

# Fora de batalha (deck_mgr_ref nulo) não existe uma pilha de compra de
# verdade ainda (o duelo não começou), mas o jogador quer ver o inventário
# persistente (RunManager.player_deck) como uma pilha de cartas viradas pra
# baixo mesmo assim — não só o número "X/20" sozinho. Mostra até 5 costas de
# carta empilhadas (mesmo visual/limite de update_pile_visual_stacks) com o
# contador sobreposto por cima, igual a um "badge".
func refresh_cards_inventory_count() -> void:
	if cards_count_label == null:
		return
	if deck_mgr_ref != null:
		cards_count_label.visible = false
		return

	var deck: Array[ActionCard] = RunManager.player_deck if RunManager != null else []
	var count = deck.size()
	var max_size = RunManager.MAX_PLAYER_DECK_SIZE if RunManager != null else count
	cards_count_label.visible = true
	cards_count_label.text = "%d/%d" % [count, max_size]

	if draw_deck_stack == null:
		return
	_set_pile_badge(draw_pile_widget, count > 0)

	for c in draw_deck_stack.get_children():
		c.queue_free()

	var cards_visible = mini(5, count)
	for i in range(cards_visible):
		# Mesma lógica de update_pile_visual_stacks: desenha da base até o
		# topo, empilhando as últimas cartas do array por cima.
		var card_idx = (count - cards_visible) + i
		var card_ref: ActionCard = deck[card_idx] if card_idx < deck.size() else null
		var card_back = _create_mini_card_back(card_ref, i * -3.0)
		draw_deck_stack.add_child(card_back)

func update_pile_visual_stacks() -> void:
	if deck_mgr_ref == null:
		return

	if cards_count_label != null:
		cards_count_label.visible = false

	# -----------------------------------------------------------------
	# 1. PILHA DE COMPRA (Draw Pile)
	# -----------------------------------------------------------------
	for c in draw_deck_stack.get_children():
		c.queue_free()

	var draw_count = deck_mgr_ref.get_draw_count()
	_set_pile_badge(draw_pile_widget, draw_count > 0)
	var draw_cards_visible = mini(5, draw_count)

	# Desenhamos da base até o topo (o topo é adicionado por último, ficando na frente)
	for i in range(draw_cards_visible):
		# Pega das cartas mais abaixo até chegar na do topo
		var card_idx = (draw_count - draw_cards_visible) + i
		var card_ref: ActionCard = deck_mgr_ref.draw_pile[card_idx] if card_idx < deck_mgr_ref.draw_pile.size() else null

		# i representa a altura física (cartas superiores sobem levemente no eixo Y)
		var card_back = _create_mini_card_back(card_ref, i * -3.0)
		draw_deck_stack.add_child(card_back)

	# -----------------------------------------------------------------
	# 2. PILHA DE DESCARTE (Discard Pile - LIFO)
	# -----------------------------------------------------------------
	for c in discard_deck_stack.get_children():
		c.queue_free()

	var discard_count = deck_mgr_ref.get_discard_count()
	var discard_cards_visible = mini(5, discard_count)

	# A última carta descartada (discard_pile.back()) deve ser o topo da pilha
	for i in range(discard_cards_visible):
		# Começa nas cartas descartadas anteriormente e termina na mais recente
		var card_idx = (discard_count - discard_cards_visible) + i
		var card_ref: ActionCard = deck_mgr_ref.discard_pile[card_idx] if card_idx < deck_mgr_ref.discard_pile.size() else null

		# A última adicionada terá o maior z-index visual e ficará no topo da pilha
		var card_back = _create_mini_card_back(card_ref, i * -3.0)
		discard_deck_stack.add_child(card_back)

	_set_pile_badge(discard_pile_widget, discard_count > 0)

# Selo (ícone) da pilha: só aparece quando há cartas nela.
func _set_pile_badge(pile: Control, has_cards: bool) -> void:
	if pile != null and pile.has_node("Badge"):
		pile.get_node("Badge").visible = has_cards

func _create_mini_card_back(card: ActionCard, y_offset: float) -> Control:
	var visual = ActionCardVisual.new(card, false)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.scale = Vector2(0.60, 0.60)
	visual.position = Vector2(5.0, 10.0 + y_offset)
	return visual

func get_draw_pile_global_pos() -> Vector2:
	if draw_pile_widget:
		return draw_pile_widget.global_position + Vector2(10.0, 10.0)
	return Vector2.ZERO

func get_discard_pile_global_pos() -> Vector2:
	if discard_pile_widget:
		return discard_pile_widget.global_position + Vector2(10.0, 10.0)
	return Vector2.ZERO

func _on_card_played_animation(card: ActionCard) -> void:
	var fly_card = ActionCardVisual.new(card, true)
	add_child(fly_card)
	fly_card.global_position = get_viewport().get_mouse_position() - (Vector2(ActionCardVisual.CARD_WIDTH, ActionCardVisual.CARD_HEIGHT) / 2.0)

	var target_pos = get_discard_pile_global_pos()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(fly_card, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fly_card, "scale", Vector2(0.60, 0.60), 0.35)
	tween.tween_property(fly_card, "modulate:a", 0.6, 0.35)

	await tween.finished
	fly_card.queue_free()
	update_pile_visual_stacks()

func refresh_deck() -> void:
	var active_rules: Array[RuleCard] = RunManager.active_rules if RunManager != null else []
	_current_rules = active_rules

	for i in range(6):
		if i >= slot_containers.size():
			continue
		var slot = slot_containers[i]
		for child in slot.get_children():
			child.queue_free()

		if i < active_rules.size():
			var rule: RuleCard = active_rules[i]
			# Constrói a carta JÁ no tamanho final do slot (via display_scale),
			# em vez de montar em RuleCardVisual.CARD_SIZE (320) inteiro e
			# encolher depois com Control.scale. Encolher por transform pega o
			# texto já desenhado grande e o amassa pra caber, o que borra as
			# letras; construindo pequeno direto, a fonte é rasterizada no
			# tamanho de exibição de verdade — sai nítida.
			var target_scale = law_board.slot_size / RuleCardVisual.CARD_SIZE
			var mini_visual = RuleCardVisual.new(rule, null, true, target_scale)
			mini_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mini_visual.position = Vector2.ZERO
			slot.add_child(mini_visual)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			# Sem quadrado vazio: slot fica sem conteúdo nenhum, só o
			# quadro de fundo aparecendo por trás, e sem hover/tooltip
			# já que não há nada pra mostrar.
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

var _shown_gold: int = -1
var _gold_tween: Tween

func update_gold() -> void:
	var g = RunManager.gold if RunManager != null else 0
	if gold_label == null:
		return
	# Primeira chamada (ou HUD fora da árvore): só mostra, sem animar.
	if _shown_gold < 0 or not gold_label.is_inside_tree():
		_shown_gold = g
		gold_label.text = "%d" % g
		return
	var delta: int = g - _shown_gold
	if delta == 0:
		gold_label.text = "%d" % g
		return
	var from_v: int = _shown_gold
	_shown_gold = g
	if _gold_tween != null and _gold_tween.is_valid():
		_gold_tween.kill()
	# Contador "rola" até o novo valor (mais rápido quanto menor a diferença).
	_gold_tween = gold_label.create_tween()
	_gold_tween.tween_method(func(v: float): gold_label.text = "%d" % int(round(v)),
		float(from_v), float(g), clampf(0.25 + absf(delta) * 0.004, 0.25, 0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var anchor: Control = gold_panel_ctrl if gold_panel_ctrl != null else gold_label
	Juice.pulse(anchor, 1.12 if delta > 0 else 1.06)
	var up: bool = delta > 0
	Juice.flash_modulate(gold_label, Color(0.6, 1.0, 0.6) if up else Color(1.0, 0.5, 0.5), 0.5)
	var pos: Vector2 = gold_label.global_position + Vector2(gold_label.size.x * 0.5, -6.0)
	Juice.float_text(self, ("+%d" if up else "%d") % delta, pos, Color(0.65, 1.0, 0.55) if up else Color(1.0, 0.5, 0.45), 28)
	if up:
		Juice.burst(self, gold_label.global_position + Vector2(-20, 14), Juice.C_GOLD, mini(6 + delta, 16), 130.0, 0.5, 3.0, 260.0, 120.0)

func _on_rule_slot_hovered(idx: int) -> void:
	if rule_tooltip == null or idx >= _current_rules.size():
		return
	var slot = slot_containers[idx]
	var screen_pos = slot.global_position + Vector2(slot.size.x + 18.0, 0.0)
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
