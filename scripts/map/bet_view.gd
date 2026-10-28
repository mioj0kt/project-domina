class_name BetView
extends Control

const MAP_SCENE_PATH: String = "res://map_view.tscn"
const GOLD_WAGER_OPTIONS: Array[int] = [10, 25, 50]
# Equilíbrio da casa: a aposta máxima é metade do ouro (mas nunca menos que a
# menor opção), acertar paga +80% do valor apostado (vantagem leve da casa, em
# vez de 2x). Dá para apostar quantas vezes quiser na mesma visita.
const WAGER_MAX_FRACTION: float = 0.5
const WIN_PROFIT_RATIO: float = 0.8

static func max_wager_for(gold: int) -> int:
	return maxi(GOLD_WAGER_OPTIONS[0], int(floor(float(gold) * WAGER_MAX_FRACTION)))

static func win_profit(wager: int) -> int:
	return int(round(float(wager) * WIN_PROFIT_RATIO))
const PREVIEW_SCALE: float = 0.95
const COIN_RADIUS: float = 100.0

enum StakeType { GOLD, CARD, LAW }

var hud_bar: HUDBar
var inventory_ui: InventoryUI
var coin_flip_view: CoinFlipView
var casino_fx: CasinoFx
var table_panel: PanelContainer
var outer_box_ref: VBoxContainer
var header_ref: Label
var _time: float = 0.0
var card_tooltip: ActionCardTooltip
var rule_tooltip: RuleCardTooltip
var discard_modal: RuleDiscardModal
var gold_label: Label
var status_label: Label
var call_label: Label

var stake_box: VBoxContainer
var gold_wager_hbox: HBoxContainer
var special_stake_hbox: HBoxContainer
var gold_buttons: Array[Button] = []
var card_stake_btn: Button
var law_stake_btn: Button

var picker_box: VBoxContainer
var picker_title: Label
var picker_hbox: HBoxContainer
var picker_cancel_btn: Button

var preview_hbox: HBoxContainer
var coin_spacer: Control

var call_hbox: HBoxContainer
var white_call_btn: Button
var black_call_btn: Button

var leave_btn: Button
var step_panels: Array[PanelContainer] = []
var step_labels: Array[Label] = []
var coin_hint: Label
var tutorial_guide_view: TutorialGuideView

var current_stake_type: int = StakeType.GOLD
var current_gold_wager: int = 0
var current_staked_card: ActionCard = null
var current_staked_rule: RuleCard = null
var player_called_white: bool = true
var is_flipping: bool = false

func _ready() -> void:
	_setup_ui()
	if TutorialManager.is_active:
		_setup_tutorial()

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "BetUILayer"
	canvas.layer = 70
	add_child(canvas)

	add_child(BiomeBackground.new())

	hud_bar = HUDBar.new()
	canvas.add_child(hud_bar)
	hud_bar.open_laws_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.LAWS))
	hud_bar.open_cards_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.CARDS))

	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.setup()

	discard_modal = RuleDiscardModal.new()
	discard_modal.rule_replaced.connect(_on_reward_law_replaced)
	discard_modal.replacement_canceled.connect(_on_reward_law_declined)
	add_child(discard_modal)

	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)

	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	var outer_box = VBoxContainer.new()
	outer_box.set_anchors_preset(Control.PRESET_CENTER)
	outer_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	outer_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	outer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(outer_box)
	outer_box_ref = outer_box

	var panel = PanelContainer.new()
	table_panel = panel
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.1, 0.14, 0.97), Color(0.85, 0.68, 0.25), 22))
	outer_box.add_child(panel)

	var content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 12)
	content_box.custom_minimum_size = Vector2(960, 0)
	panel.add_child(content_box)

	var header = Label.new()
	header.text = "MESA DE APOSTAS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 64)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	header.add_theme_constant_override("outline_size", 8)
	content_box.add_child(header)
	header_ref = header

	# Trilha de 3 passos: deixa claro onde o jogador está e o que vem depois.
	var steps_row = HBoxContainer.new()
	steps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	steps_row.add_theme_constant_override("separation", 14)
	content_box.add_child(steps_row)
	var step_texts = ["1  ESCOLHA O QUE ARRISCAR", "2  CHAME UM LADO", "3  A MOEDA GIRA"]
	for i in range(step_texts.size()):
		if i > 0:
			var arrow = Label.new()
			arrow.text = ">"
			arrow.add_theme_font_size_override("font_size", 30)
			arrow.add_theme_color_override("font_color", Color(0.5, 0.52, 0.6))
			steps_row.add_child(arrow)
		var sp = PanelContainer.new()
		sp.custom_minimum_size = Vector2(270, 54)
		steps_row.add_child(sp)
		var sl = Label.new()
		sl.text = step_texts[i]
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.add_theme_font_size_override("font_size", 21)
		sp.add_child(sl)
		step_panels.append(sp)
		step_labels.append(sl)

	gold_label = Label.new()
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 36)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	content_box.add_child(gold_label)

	# Espaço reservado onde a moeda gira — a posição real dela é calculada
	# a partir do centro DESTE controle no momento do lance (não um valor
	# fixo de tela), então ela sempre cai exatamente aqui, nunca por cima
	# de texto.
	coin_spacer = Control.new()
	coin_spacer.custom_minimum_size = Vector2(10, 250)
	content_box.add_child(coin_spacer)
	coin_hint = Label.new()
	coin_hint.text = "?"
	coin_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_hint.add_theme_font_size_override("font_size", 160)
	coin_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.18))
	coin_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_spacer.add_child(coin_hint)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 32)
	status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	content_box.add_child(status_label)

	# Mostra a carta/lei em jogo (e depois do lance, a comparação
	# apostada -> ganha, ou a marca de perdida).
	preview_hbox = HBoxContainer.new()
	preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_hbox.add_theme_constant_override("separation", 24)
	content_box.add_child(preview_hbox)

	# --- Etapa 1: o que arriscar ---
	stake_box = VBoxContainer.new()
	stake_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stake_box.add_theme_constant_override("separation", 10)
	content_box.add_child(stake_box)

	var gold_stake_title = Label.new()
	gold_stake_title.text = "ARRISCAR OURO  -  acerte o lado e ganhe +80%  (máx. metade do seu ouro)"
	gold_stake_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_stake_title.add_theme_font_size_override("font_size", 26)
	gold_stake_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	stake_box.add_child(gold_stake_title)

	gold_wager_hbox = HBoxContainer.new()
	gold_wager_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_wager_hbox.add_theme_constant_override("separation", 24)
	stake_box.add_child(gold_wager_hbox)
	for amount in GOLD_WAGER_OPTIONS:
		var btn = Button.new()
		btn.text = "%d OURO" % amount
		btn.custom_minimum_size = Vector2(250, 90)
		btn.add_theme_font_size_override("font_size", 36)
		PixelUI.skin_button(btn, Color(0.4, 0.85, 0.45))
		btn.pressed.connect(_on_gold_stake_selected.bind(amount))
		gold_wager_hbox.add_child(btn)
		gold_buttons.append(btn)

	var special_title = Label.new()
	special_title.text = "OU ARRISQUE ALGO SEU por uma versão melhor"
	special_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_title.add_theme_font_size_override("font_size", 26)
	special_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	stake_box.add_child(special_title)

	special_stake_hbox = HBoxContainer.new()
	special_stake_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	special_stake_hbox.add_theme_constant_override("separation", 24)
	stake_box.add_child(special_stake_hbox)

	card_stake_btn = Button.new()
	card_stake_btn.text = "ESCOLHER UMA CARTA\npra arriscar"
	card_stake_btn.custom_minimum_size = Vector2(380, 90)
	card_stake_btn.add_theme_font_size_override("font_size", 25)
	PixelUI.skin_button(card_stake_btn, Color(0.6, 0.4, 0.85))
	card_stake_btn.pressed.connect(_open_card_picker)
	special_stake_hbox.add_child(card_stake_btn)

	law_stake_btn = Button.new()
	law_stake_btn.text = "ESCOLHER UMA LEI\npra arriscar"
	law_stake_btn.custom_minimum_size = Vector2(380, 90)
	law_stake_btn.add_theme_font_size_override("font_size", 25)
	PixelUI.skin_button(law_stake_btn, Color(0.3, 0.7, 0.9))
	law_stake_btn.pressed.connect(_open_law_picker)
	special_stake_hbox.add_child(law_stake_btn)

	# --- Etapa 1b: escolher QUAL carta/lei (aparece por cima da etapa 1) ---
	picker_box = VBoxContainer.new()
	picker_box.alignment = BoxContainer.ALIGNMENT_CENTER
	picker_box.add_theme_constant_override("separation", 10)
	picker_box.visible = false
	content_box.add_child(picker_box)

	picker_title = Label.new()
	picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picker_title.add_theme_font_size_override("font_size", 30)
	picker_title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	picker_box.add_child(picker_title)

	var picker_scroll = ScrollContainer.new()
	picker_scroll.custom_minimum_size = Vector2(1000, 280)
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	picker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker_box.add_child(picker_scroll)

	picker_hbox = HBoxContainer.new()
	picker_hbox.add_theme_constant_override("separation", 10)
	picker_scroll.add_child(picker_hbox)

	picker_cancel_btn = Button.new()
	picker_cancel_btn.text = "VOLTAR"
	picker_cancel_btn.custom_minimum_size = Vector2(220, 56)
	picker_cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picker_cancel_btn.add_theme_font_size_override("font_size", 24)
	PixelUI.skin_button(picker_cancel_btn, Color(0.4, 0.4, 0.45), "", "icone_voltar")
	picker_cancel_btn.pressed.connect(_close_picker)
	picker_box.add_child(picker_cancel_btn)

	# --- Etapa 2: chamar BRANCA ou PRETA (lados da moeda) ---
	call_label = Label.new()
	call_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	call_label.add_theme_font_size_override("font_size", 34)
	call_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	call_label.visible = false
	content_box.add_child(call_label)

	call_hbox = HBoxContainer.new()
	call_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	call_hbox.add_theme_constant_override("separation", 40)
	call_hbox.visible = false
	content_box.add_child(call_hbox)

	white_call_btn = Button.new()
	white_call_btn.text = "BRANCA"
	white_call_btn.custom_minimum_size = Vector2(320, 110)
	white_call_btn.add_theme_font_size_override("font_size", 42)
	PixelUI.skin_button(white_call_btn, Color(0.85, 0.85, 0.9))
	white_call_btn.pressed.connect(_on_call_selected.bind(true))
	call_hbox.add_child(white_call_btn)

	black_call_btn = Button.new()
	black_call_btn.text = "PRETA"
	black_call_btn.custom_minimum_size = Vector2(320, 110)
	black_call_btn.add_theme_font_size_override("font_size", 42)
	PixelUI.skin_button(black_call_btn, Color(0.2, 0.2, 0.28))
	black_call_btn.pressed.connect(_on_call_selected.bind(false))
	call_hbox.add_child(black_call_btn)

	leave_btn = Button.new()
	leave_btn.text = "IR EMBORA"
	leave_btn.custom_minimum_size = Vector2(340, 58)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.add_theme_font_size_override("font_size", 24)
	PixelUI.skin_button(leave_btn, Color(0.4, 0.7, 0.9), "", "icone_mapa")
	leave_btn.pressed.connect(_on_leave_pressed)
	content_box.add_child(leave_btn)

	# Efeitos de cassino (letreiro, holofote, celebração) — por baixo da moeda.
	casino_fx = CasinoFx.new()
	casino_fx.frame_target = table_panel
	casino_fx.spot_target = coin_spacer
	canvas.add_child(casino_fx)

	coin_flip_view = CoinFlipView.new()
	coin_flip_view.win_text = "BRANCA!"
	coin_flip_view.lose_text = "PRETA!"
	# Um lado é a peça comum branca, o outro a peça comum preta (padrão da moeda).
	coin_flip_view.flip_completed.connect(_on_flip_completed)
	# Precisa estar no MESMO CanvasLayer do resto da UI — senão o fundo
	# opaco (que fica numa camada diferente) desenha por cima da moeda.
	canvas.add_child(coin_flip_view)

	_refresh_gold_label()
	_update_stake_buttons_state()
	_set_step(0)

func _process(delta: float) -> void:
	_time += delta
	if header_ref != null:
		# letreiro neon: pulsa de leve
		var k: float = 0.86 + 0.14 * sin(_time * 3.0)
		header_ref.modulate = Color(k, k, k)
	if casino_fx != null:
		casino_fx.spinning = is_flipping

func _shake_table() -> void:
	if outer_box_ref == null:
		return
	var base: Vector2 = outer_box_ref.position
	var tw := create_tween()
	for i in range(7):
		var amp: float = 14.0 * (1.0 - float(i) / 7.0)
		tw.tween_property(outer_box_ref, "position:x", base.x + (amp if i % 2 == 0 else -amp), 0.045)
	tw.tween_property(outer_box_ref, "position:x", base.x, 0.05)

func _pop_status(won: bool) -> void:
	status_label.pivot_offset = status_label.size * 0.5
	status_label.scale = Vector2(0.6, 0.6)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35) if won else Color(1.0, 0.5, 0.5))
	var tw := create_tween()
	tw.tween_property(status_label, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_gold_label() -> void:
	var current_gold = RunManager.gold if RunManager != null else 0
	gold_label.text = "Ouro atual: %d" % current_gold

func _update_stake_buttons_state() -> void:
	var current_gold = RunManager.gold if RunManager != null else 0
	for i in range(gold_buttons.size()):
		var wager: int = GOLD_WAGER_OPTIONS[i]
		gold_buttons[i].disabled = is_flipping or current_gold < wager or wager > max_wager_for(current_gold)
		gold_buttons[i].text = "%d OURO" % wager

	var has_cards = RunManager != null and not RunManager.player_deck.is_empty()
	var has_rules = RunManager != null and not RunManager.active_rules.is_empty()
	card_stake_btn.disabled = is_flipping or not has_cards
	law_stake_btn.disabled = is_flipping or not has_rules

# ---------- Seletor de carta ----------

func _open_card_picker() -> void:
	if is_flipping or RunManager == null or RunManager.player_deck.is_empty():
		return
	picker_title.text = "Qual carta voce quer arriscar?"
	for child in picker_hbox.get_children():
		child.queue_free()
	for card in RunManager.player_deck:
		picker_hbox.add_child(_build_card_picker_item(card))
	stake_box.visible = false
	picker_box.visible = true

func _build_card_picker_item(card: ActionCard) -> Control:
	var visual = ActionCardVisual.new(card, true, PREVIEW_SCALE)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var btn = Button.new()
	btn.flat = true
	btn.custom_minimum_size = visual.custom_minimum_size
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", PixelUI.make_bevel_card(Color(1, 1, 1, 0.08), Color(1.0, 0.85, 0.3)))
	btn.add_child(visual)
	CardVisualBase.bind_tilt(btn, visual)
	btn.pressed.connect(_on_card_picked.bind(card))
	btn.mouse_entered.connect(func():
		if card_tooltip:
			var tip_pos = btn.global_position + Vector2(btn.custom_minimum_size.x / 2.0, 0.0)
			card_tooltip.show_tooltip(card, tip_pos)
	)
	btn.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)
	return btn

func _on_card_picked(card: ActionCard) -> void:
	current_stake_type = StakeType.CARD
	current_staked_card = card
	TutorialManager.report_event("bet_stake")
	_close_picker()
	_show_staked_preview()
	_go_to_call_phase()

# ---------- Seletor de lei ----------

func _open_law_picker() -> void:
	if is_flipping or RunManager == null or RunManager.active_rules.is_empty():
		return
	picker_title.text = "Qual lei voce quer arriscar?"
	for child in picker_hbox.get_children():
		child.queue_free()
	for rule in RunManager.active_rules:
		picker_hbox.add_child(_build_law_picker_item(rule))
	stake_box.visible = false
	picker_box.visible = true

func _build_law_picker_item(rule: RuleCard) -> Control:
	var visual = RuleCardVisual.new(rule, null, true, PREVIEW_SCALE)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var btn = Button.new()
	btn.flat = true
	btn.custom_minimum_size = visual.custom_minimum_size
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", PixelUI.make_bevel_card(Color(1, 1, 1, 0.08), Color(1.0, 0.85, 0.3)))
	btn.add_child(visual)
	CardVisualBase.bind_tilt(btn, visual)
	btn.pressed.connect(_on_law_picked.bind(rule))
	btn.mouse_entered.connect(func():
		if rule_tooltip:
			var tip_pos = btn.global_position + Vector2(btn.custom_minimum_size.x / 2.0, 0.0)
			rule_tooltip.show_tooltip(rule, tip_pos)
	)
	btn.mouse_exited.connect(func():
		if rule_tooltip:
			rule_tooltip.hide_tooltip()
	)
	return btn

func _on_law_picked(rule: RuleCard) -> void:
	current_stake_type = StakeType.LAW
	current_staked_rule = rule
	TutorialManager.report_event("bet_stake")
	_close_picker()
	_show_staked_preview()
	_go_to_call_phase()

func _close_picker() -> void:
	picker_box.visible = false
	stake_box.visible = true
	if card_tooltip:
		card_tooltip.hide_tooltip()
	if rule_tooltip:
		rule_tooltip.hide_tooltip()

# ---------- Fluxo comum ----------

func _on_gold_stake_selected(amount: int) -> void:
	if is_flipping or RunManager == null or RunManager.gold < amount or amount > max_wager_for(RunManager.gold):
		return
	current_stake_type = StakeType.GOLD
	current_gold_wager = amount
	TutorialManager.report_event("bet_stake")
	_show_staked_preview()
	_go_to_call_phase()

func _clear_preview() -> void:
	for child in preview_hbox.get_children():
		child.queue_free()

func _show_staked_preview() -> void:
	_clear_preview()
	match current_stake_type:
		StakeType.GOLD:
			status_label.text = "Em jogo: %d de ouro (acertou: +%d)." % [current_gold_wager, win_profit(current_gold_wager)]
		StakeType.CARD:
			status_label.text = "Em jogo:"
			preview_hbox.add_child(_labeled_card_visual("APOSTADA", current_staked_card, Color.WHITE))
		StakeType.LAW:
			status_label.text = "Em jogo:"
			preview_hbox.add_child(_labeled_law_visual("APOSTADA", current_staked_rule, Color.WHITE))

func _labeled_card_visual(caption: String, card: ActionCard, tint: Color) -> Control:
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(label)
	var visual = ActionCardVisual.new(card, true, PREVIEW_SCALE)
	visual.modulate = tint
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
	box.add_child(visual)
	return box

func _labeled_law_visual(caption: String, rule: RuleCard, tint: Color) -> Control:
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(label)
	var visual = RuleCardVisual.new(rule, null, true, PREVIEW_SCALE)
	visual.modulate = tint
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if rule_tooltip:
			var tip_pos = visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0)
			rule_tooltip.show_tooltip(rule, tip_pos)
	)
	visual.mouse_exited.connect(func():
		if rule_tooltip:
			rule_tooltip.hide_tooltip()
	)
	box.add_child(visual)
	return box

func _go_to_call_phase() -> void:
	stake_box.visible = false
	picker_box.visible = false
	call_label.text = "Qual lado vai cair?"
	call_label.visible = true
	call_hbox.visible = true
	_set_step(1)

func _on_call_selected(called_white: bool) -> void:
	if is_flipping:
		return
	is_flipping = true
	_set_step(2)
	player_called_white = called_white
	TutorialManager.report_event("bet_call")
	call_hbox.visible = false
	call_label.text = "Voce chamou %s..." % ("BRANCA" if called_white else "PRETA")
	leave_btn.disabled = true

	# Posição real do centro do espaço reservado, calculada agora (depois
	# do layout já estar todo montado) — garante que a moeda sempre cai
	# exatamente nesse vão reservado, nunca por cima de texto.
	# Offset extra pra baixo — o espaço reservado (coin_spacer) fica logo
	# abaixo do ouro atual, mas a moeda parecia alta demais ali; descendo
	# mais ela fica com mais respiro visual antes do texto de status.
	# Esconder os botões de chamada muda o tamanho do painel (e ele recentraliza):
	# espera o layout assentar para a moeda cair EXATAMENTE no centro do holofote.
	await get_tree().process_frame
	await get_tree().process_frame
	var coin_center = coin_spacer.global_position + coin_spacer.size / 2.0 + Vector2(0.0, 10.0)
	coin_flip_view.play_toss(coin_center, COIN_RADIUS)

func _get_better_rarity_card(min_rarity: int) -> ActionCard:
	var all_cards = LootTables.get_player_action_cards()
	var target_rarity = mini(min_rarity + 1, ActionCard.Rarity.LEGENDARY)
	var pool = all_cards.filter(func(c): return c.rarity == target_rarity)
	if pool.is_empty():
		pool = all_cards.filter(func(c): return c.rarity == min_rarity)
	if pool.is_empty():
		pool = LootTables.get_all_action_cards().filter(func(c): return c.rarity == min_rarity)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _get_better_rarity_rule(min_rarity: int, exclude_ids: Array[String]) -> RuleCard:
	var all_rules = LootTables.get_player_rules().filter(func(r): return not exclude_ids.has(r.id))
	var target_rarity = mini(min_rarity + 1, RuleCard.Rarity.LEGENDARY)
	var pool = all_rules.filter(func(r): return r.rarity == target_rarity)
	if pool.is_empty():
		pool = all_rules.filter(func(r): return r.rarity == min_rarity)
	if pool.is_empty():
		pool = LootTables.get_all_rules().filter(func(r): return not exclude_ids.has(r.id) and r.rarity == min_rarity)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _on_flip_completed(landed_white: bool) -> void:
	var bet_won = (landed_white == player_called_white)
	_clear_preview()

	if bet_won:
		match current_stake_type:
			StakeType.GOLD:
				var profit: int = win_profit(current_gold_wager)
				RunManager.add_gold(profit)
				status_label.text = "Acertou! Ganhou %d de ouro." % profit
			StakeType.CARD:
				var new_card = _get_better_rarity_card(current_staked_card.rarity)
				status_label.text = "Acertou! Ganhou uma carta melhor:"
				preview_hbox.add_child(_labeled_card_visual("APOSTADA", current_staked_card, Color.WHITE))
				var arrow = Label.new()
				arrow.text = "→"
				arrow.add_theme_font_size_override("font_size", 46)
				arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				preview_hbox.add_child(arrow)
				if new_card != null:
					if RunManager.add_card_to_deck(new_card):
						preview_hbox.add_child(_labeled_card_visual("GANHA", new_card, Color(1.2, 1.15, 0.85)))
					else:
						status_label.text = "Acertou! Mas seu inventario de cartas ja esta cheio (20/20)."
			StakeType.LAW:
				var owned_ids: Array[String] = []
				for r in RunManager.active_rules:
					owned_ids.append(r.id)
				var new_rule = _get_better_rarity_rule(current_staked_rule.rarity, owned_ids)
				status_label.text = "Acertou! Ganhou uma lei melhor:"
				preview_hbox.add_child(_labeled_law_visual("APOSTADA", current_staked_rule, Color.WHITE))
				var arrow2 = Label.new()
				arrow2.text = "→"
				arrow2.add_theme_font_size_override("font_size", 46)
				arrow2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				preview_hbox.add_child(arrow2)
				if new_rule != null:
					if RunManager.add_rule(new_rule):
						preview_hbox.add_child(_labeled_law_visual("GANHA", new_rule, Color(1.2, 1.15, 0.85)))
					else:
						# Limite de Leis: o jogador escolhe qual revogar.
						status_label.text = "Acertou! Suas leis estao lotadas: escolha qual revogar."
						discard_modal.prompt_replace(new_rule)
	else:
		match current_stake_type:
			StakeType.GOLD:
				RunManager.spend_gold(current_gold_wager)
				status_label.text = "Errou... perdeu %d de ouro." % current_gold_wager
			StakeType.CARD:
				status_label.text = "Errou... perdeu a carta apostada."
				preview_hbox.add_child(_labeled_card_visual("PERDIDA", current_staked_card, Color(1.0, 0.4, 0.4, 0.7)))
				RunManager.player_deck.erase(current_staked_card)
			StakeType.LAW:
				status_label.text = "Errou... perdeu a lei apostada."
				preview_hbox.add_child(_labeled_law_visual("PERDIDA", current_staked_rule, Color(1.0, 0.4, 0.4, 0.7)))
				RunManager.remove_rule(current_staked_rule.id)

	if hud_bar != null:
		hud_bar.update_gold()
	_refresh_gold_label()
	if casino_fx != null:
		casino_fx.celebrate(coin_spacer.global_position + coin_spacer.size / 2.0 + Vector2(0.0, 10.0), bet_won)
	_pop_status(bet_won)
	if not bet_won:
		_shake_table()

	current_staked_card = null
	current_staked_rule = null
	is_flipping = false
	_set_step(0)
	leave_btn.disabled = false
	TutorialManager.report_event("bet_resolved")
	call_label.visible = false
	# Sem limite de apostas por visita: a mesa reabre para a próxima. (No
	# tutorial continua sendo uma só, para a lição seguir adiante.)
	stake_box.visible = not TutorialManager.is_active
	_update_stake_buttons_state()

func _on_reward_law_replaced(_old: RuleCard, new_rule: RuleCard) -> void:
	status_label.text = "Acertou! Ganhou uma lei melhor:"
	preview_hbox.add_child(_labeled_law_visual("GANHA", new_rule, Color(1.2, 1.15, 0.85)))

func _on_reward_law_declined() -> void:
	status_label.text = "Acertou! Mas voce recusou a lei de recompensa."

func _on_leave_pressed() -> void:
	if is_flipping:
		return
	TutorialManager.report_event("bet_leave")
	var target = "res://tutorial_map_view.tscn" if TutorialManager.is_active else MAP_SCENE_PATH
	SceneTransition.go(target)

# =============================================================
# TUTORIAL (Lição 4)
# =============================================================
func _setup_tutorial() -> void:
	# Garante ouro para treinar a aposta, mesmo se a Loja gastou muito.
	if RunManager.gold < GOLD_WAGER_OPTIONS[0]:
		RunManager.gold = GOLD_WAGER_OPTIONS[0]
		_refresh_gold_label()
		hud_bar.update_gold()
		_update_stake_buttons_state()
	tutorial_guide_view = TutorialGuideView.new()
	tutorial_guide_view.spot_resolver = _tutorial_spot_rect
	add_child(tutorial_guide_view)
	# Só dá para sair depois de apostar e ver a moeda cair.
	leave_btn.disabled = true
	_run_tutorial_intro()

func _run_tutorial_intro() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var step = TutorialManager.current_step
	await tutorial_guide_view.play_title_card(
		"LIÇÃO %d de %d" % [TutorialManager.get_lesson_number(step), TutorialManager.LESSON_COUNT],
		TutorialManager.get_lesson_title(step),
		TutorialManager.get_lesson_goal(step))
	await tutorial_guide_view.play_sequence(TutorialManager.get_bet_intro_lines())
	TutorialManager.begin_objectives()

func _tutorial_spot_rect(id: String) -> Rect2:
	match id:
		"gold":
			return gold_label.get_global_rect().grow(8.0)
		"bet_gold":
			return gold_wager_hbox.get_global_rect().grow(8.0)
		"bet_special":
			return special_stake_hbox.get_global_rect().grow(8.0)
		"bet_call":
			return call_hbox.get_global_rect().grow(8.0)
		"bet_leave":
			return leave_btn.get_global_rect().grow(6.0)
	return Rect2()

# Destaca o passo atual da trilha (0 = escolher, 1 = chamar, 2 = moeda girando).
func _set_step(active: int) -> void:
	for i in range(step_panels.size()):
		var is_on: bool = i == active
		var border = Color(1.0, 0.85, 0.3) if is_on else Color(0.3, 0.32, 0.4)
		var fill = Color(0.42, 0.31, 0.06, 1.0) if is_on else Color(0.1, 0.11, 0.15, 0.9)
		step_panels[i].add_theme_stylebox_override("panel", PixelUI.make_flat_panel(fill, border, 8))
		step_labels[i].add_theme_color_override("font_color", Color(1.0, 0.95, 0.6) if is_on else Color(0.5, 0.52, 0.6))
	if coin_hint != null:
		coin_hint.visible = active != 2
