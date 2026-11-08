class_name ArcanoView
extends Control

# Nó "Arcano" do mapa: um acervo de CARTAS (o irmão do Altar de Leis). Ao entrar,
# sorteia um de três formatos de escolha:
#   UMA     : 3 cartas na mesa, leva 1.
#   DUAS    : 5 cartas na mesa, leva 2.
#   DUPLA   : 3 duplas (6 cartas), leva 1 dupla inteira (as 2 cartas dela).
# Tudo grátis, uma vez por visita. Se o inventário não comportar o que foi
# escolhido, o jogador descarta cartas do baralho antes de levar.
# Mesmo esqueleto do AltarView: fundo de bioma, HUD, inventário e tooltips.

const MAP_SCENE_PATH: String = "res://scenes/map_view.tscn"
const OFFER_SCALE: float = 1.15         # duplas
const SINGLE_SCALE: float = 1.55        # 1 entre 3 (cartas maiores)
const TWO_SCALE: float = 1.3            # 2 entre 5
const DONE_SCALE: float = 1.5
const DECK_SCALE: float = 0.5
const BODY_SIZE: Vector2 = Vector2(1366, 405)
const MAX_TEXT_H: float = 190.0
const MIN_TEXT_FONT: int = 22
const CHOICE_W: float = 450.0

const C_GOLD := Color("#d9a441")
const C_GREEN := Color(0.3, 0.9, 0.4)
const C_RED := Color(0.9, 0.35, 0.35)

enum Mode { PICK_ONE, PICK_TWO, PICK_PAIR }
enum Stage { OFFERS, DISCARD, DONE }

# Pesos do sorteio de formato.
const MODE_WEIGHTS: Dictionary = {Mode.PICK_ONE: 40, Mode.PICK_TWO: 30, Mode.PICK_PAIR: 30}

var hud_bar: HUDBar
var inventory_ui: InventoryUI
var card_tooltip: ActionCardTooltip

var text_label: Label
var body: VBoxContainer
var leave_btn: Button

var mode: int = Mode.PICK_ONE
var stage: int = Stage.OFFERS
var used: bool = false

var offers: Array[ActionCard] = []        # cartas na mesa (PAIR: 2 por dupla, em sequência)
var selected: Array[ActionCard] = []      # PICK_TWO: marcadas
var pending: Array[ActionCard] = []       # cartas escolhidas esperando vaga
var to_discard: Array[ActionCard] = []    # baralho: marcadas para descartar
var _confirm_btn: Button = null

func _ready() -> void:
	_setup_ui()
	_roll_offers()
	_show_offers()

# ==========================================
# UI base (mesma estrutura do AltarView)
# ==========================================
func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ArcanoUILayer"
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

	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 470)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.1, 0.14, 0.97), Color(0.35, 0.6, 0.85), 18))
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(BODY_SIZE.x, 0)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	var title := Label.new()
	title.text = "ARCANO DAS CARTAS"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	head.add_child(title)

	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.custom_minimum_size = Vector2(BODY_SIZE.x - 40, 0)
	text_label.add_theme_font_size_override("font_size", 40)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(text_label)

	body = VBoxContainer.new()
	body.custom_minimum_size = BODY_SIZE
	body.add_theme_constant_override("separation", 10)
	box.add_child(body)

	leave_btn = Button.new()
	leave_btn.text = "DEIXAR O ARCANO"
	leave_btn.custom_minimum_size = Vector2(CHOICE_W, 72)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.add_theme_font_size_override("font_size", 32)
	PixelUI.skin_button(leave_btn, Color(0.4, 0.7, 0.9), "", "icone_mapa")
	leave_btn.pressed.connect(func(): SceneTransition.go(MAP_SCENE_PATH))
	box.add_child(leave_btn)

# Texto com quebra manual + fonte que encolhe se for longo (mesma regra do Altar).
func _set_text(text: String) -> void:
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var width := text_label.custom_minimum_size.x
	var font: Font = text_label.get_theme_font("font")
	var font_size := 40
	var wrapped := _wrap(font, text, width, font_size)
	while font_size > MIN_TEXT_FONT and font.get_multiline_string_size(wrapped, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).y > MAX_TEXT_H:
		font_size -= 2
		wrapped = _wrap(font, text, width, font_size)
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.text = wrapped

func _wrap(font: Font, text: String, width: float, font_size: int) -> String:
	var out: Array[String] = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)

func _clear_body() -> void:
	if card_tooltip != null:
		card_tooltip.hide_tooltip()
	_confirm_btn = null
	for c in body.get_children():
		c.queue_free()

func _small_button(text: String, accent: Color, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 56)
	b.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(b, accent)
	return b

# Carta com tooltip no hover.
func _card_widget(card: ActionCard, scale_f: float, face_up: bool = true) -> ActionCardVisual:
	var vis := ActionCardVisual.new(card, face_up, scale_f)
	vis.mouse_filter = Control.MOUSE_FILTER_STOP
	vis.mouse_entered.connect(func():
		if card_tooltip != null:
			card_tooltip.show_tooltip(card, vis.global_position + Vector2(ActionCardVisual.CARD_WIDTH * scale_f / 2.0, 0.0)))
	vis.mouse_exited.connect(func():
		if card_tooltip != null:
			card_tooltip.hide_tooltip())
	return vis

# ==========================================
# Sorteio
# ==========================================
func _roll_offers() -> void:
	var pool: Array[ActionCard] = LootTables.get_player_action_cards()
	# Formato sorteado por peso, respeitando o tamanho do pool.
	var options: Array = []
	for m in MODE_WEIGHTS:
		var need: int = 3 if m == Mode.PICK_ONE else (5 if m == Mode.PICK_TWO else 6)
		if m == Mode.PICK_ONE or pool.size() >= need:
			options.append(m)
	var total := 0
	for m in options:
		total += int(MODE_WEIGHTS[m])
	var roll := randi() % total
	mode = Mode.PICK_ONE
	for m in options:
		roll -= int(MODE_WEIGHTS[m])
		if roll < 0:
			mode = m
			break
	var n: int = 3 if mode == Mode.PICK_ONE else (5 if mode == Mode.PICK_TWO else 6)
	offers = LootTables.pick_weighted_actions(pool, n)

# ==========================================
# Etapa: ofertas
# ==========================================
func _show_offers() -> void:
	stage = Stage.OFFERS
	selected.clear()
	_clear_body()
	if offers.is_empty():
		_set_text("O Arcano está vazio. Você já conhece todas as Cartas disponíveis.")
		return
	match mode:
		Mode.PICK_ONE:
			_set_text("Escolha 1 entre %d cartas." % offers.size())
			_build_single()
		Mode.PICK_TWO:
			_update_two_text()
			_build_double()
		Mode.PICK_PAIR:
			_set_text("Escolha 1 entre %d duplas. Você leva as duas cartas dela." % (floori(offers.size() / 2.0)))
			_build_pairs()

func _center_row(sep: int) -> HBoxContainer:
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", sep)
	center.add_child(row)
	return row

# --- 1 entre 3 ---
func _build_single() -> void:
	var row := _center_row(40)
	for i in range(offers.size()):
		var card: ActionCard = offers[i]
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 10)
		var vis := _card_widget(card, SINGLE_SCALE)
		holder.add_child(vis)
		var b := _small_button("LEVAR", C_GREEN, ActionCardVisual.CARD_WIDTH * SINGLE_SCALE)
		b.pressed.connect(func(): _choose([card]))
		holder.add_child(b)
		row.add_child(holder)
		vis.play_flip_reveal(0.12 + i * 0.14)

# --- 2 entre 5 ---
func _update_two_text() -> void:
	_set_text("Escolha 2 entre %d cartas.  (%d/2)" % [offers.size(), selected.size()])

func _build_double() -> void:
	var row := _center_row(22)
	var buttons: Array = []
	for i in range(offers.size()):
		var card: ActionCard = offers[i]
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 10)
		var vis := _card_widget(card, TWO_SCALE)
		holder.add_child(vis)
		var b := _small_button("ESCOLHER", C_GREEN, ActionCardVisual.CARD_WIDTH * TWO_SCALE)
		b.pressed.connect(func():
			if selected.has(card):
				selected.erase(card)
			elif selected.size() < 2:
				selected.append(card)
			_refresh_double(buttons)
			_update_two_text())
		buttons.append({"btn": b, "card": card, "vis": vis})
		holder.add_child(b)
		row.add_child(holder)
		vis.play_flip_reveal(0.1 + i * 0.1)
	_confirm_btn = _small_button("LEVAR AS 2 ESCOLHIDAS", C_GOLD, 420)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.pressed.connect(func(): _choose(selected.duplicate()))
	body.add_child(_confirm_btn)
	_refresh_double(buttons)

func _refresh_double(buttons: Array) -> void:
	for e in buttons:
		var b: Button = e["btn"]
		var on: bool = selected.has(e["card"])
		b.text = "ESCOLHIDA" if on else "ESCOLHER"
		PixelUI.skin_button(b, C_GOLD if on else C_GREEN)
		b.disabled = (not on) and selected.size() >= 2
		var vis: Control = e["vis"]
		vis.modulate = Color(1.0, 1.0, 1.0) if on or selected.size() < 2 else Color(0.6, 0.6, 0.65)
	if _confirm_btn != null:
		_confirm_btn.disabled = selected.size() != 2

# --- 1 dupla entre 3 ---
func _build_pairs() -> void:
	var row := _center_row(26)
	for p in range(floori(offers.size() / 2.0)):
		var a: ActionCard = offers[p * 2]
		var b2: ActionCard = offers[p * 2 + 1]
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.13, 0.12, 0.2, 0.95), Color(0.35, 0.6, 0.85), 10))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		frame.add_child(col)
		var cards := HBoxContainer.new()
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		cards.add_theme_constant_override("separation", 12)
		col.add_child(cards)
		var va := _card_widget(a, OFFER_SCALE)
		var vb := _card_widget(b2, OFFER_SCALE)
		cards.add_child(va)
		cards.add_child(vb)
		var btn := _small_button("LEVAR", C_GREEN, ActionCardVisual.CARD_WIDTH * OFFER_SCALE * 2.0 + 12.0)
		btn.pressed.connect(func(): _choose([a, b2]))
		col.add_child(btn)
		row.add_child(frame)
		va.play_flip_reveal(0.1 + p * 0.16)
		vb.play_flip_reveal(0.16 + p * 0.16)

# ==========================================
# Escolha -> vaga no baralho -> entrega
# ==========================================
func _choose(cards: Array) -> void:
	pending.clear()
	for c in cards:
		pending.append(c)
	var need: int = RunManager.player_deck.size() + pending.size() - RunManager.MAX_PLAYER_DECK_SIZE
	if need > 0:
		_show_discard(need)
	else:
		_deliver()

# Inventário sem espaço: o jogador marca `need` cartas do baralho para descartar.
func _show_discard(need: int) -> void:
	stage = Stage.DISCARD
	to_discard.clear()
	_clear_body()
	_set_text("Inventário cheio! Descarte %d carta(s) para levar: %s." % [need, _names(pending)])
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	scroll.add_child(flow)
	var tiles: Array = []
	for card in RunManager.player_deck:
		var vis := _card_widget(card, DECK_SCALE)
		var b := _small_button("DESCARTAR", C_RED, ActionCardVisual.CARD_WIDTH * DECK_SCALE)
		b.custom_minimum_size.y = 40
		b.add_theme_font_size_override("font_size", 16)
		var w := VBoxContainer.new()
		w.add_theme_constant_override("separation", 4)
		w.add_child(vis)
		w.add_child(b)
		flow.add_child(w)
		tiles.append({"btn": b, "card": card, "vis": vis})
		b.pressed.connect(func():
			if to_discard.has(card):
				to_discard.erase(card)
			elif to_discard.size() < need:
				to_discard.append(card)
			_refresh_discard(tiles, need))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 20)
	body.add_child(foot)
	var back := _small_button("VOLTAR", Color.WHITE, 220)
	back.pressed.connect(_show_offers)
	foot.add_child(back)
	_confirm_btn = _small_button("CONFIRMAR", C_GOLD, 320)
	_confirm_btn.pressed.connect(func():
		for c in to_discard:
			RunManager.player_deck.erase(c)
		_deliver())
	foot.add_child(_confirm_btn)
	_refresh_discard(tiles, need)

func _refresh_discard(tiles: Array, need: int) -> void:
	for e in tiles:
		var on: bool = to_discard.has(e["card"])
		var b: Button = e["btn"]
		b.text = "MARCADA" if on else "DESCARTAR"
		b.disabled = (not on) and to_discard.size() >= need
		var vis: Control = e["vis"]
		vis.modulate = Color(1.0, 0.45, 0.45) if on else Color.WHITE
	if _confirm_btn != null:
		_confirm_btn.disabled = to_discard.size() != need

func _names(cards: Array) -> String:
	var out: Array[String] = []
	for c in cards:
		out.append(c.name)
	return " e ".join(out)

func _deliver() -> void:
	stage = Stage.DONE
	used = true
	for c in pending:
		RunManager.add_card_to_deck(c)
	_clear_body()
	_set_text("O Arcano entrega: %s." % _names(pending))
	leave_btn.text = "SEGUIR VIAGEM"
	if hud_bar != null:
		hud_bar.refresh_deck()
	var row := _center_row(30)
	var vis_list: Array = []
	for i in range(pending.size()):
		var vis := _card_widget(pending[i], DONE_SCALE)
		row.add_child(vis)
		vis.play_flip_reveal(0.1 + i * 0.15)
		vis_list.append(vis)
	await get_tree().create_timer(0.4).timeout
	for vis in vis_list:
		if is_instance_valid(vis) and vis.is_inside_tree():
			Juice.sparkle(self, vis.global_position + vis.size * 0.5, 24)
			Juice.pulse(vis, 1.08, 0.3)
