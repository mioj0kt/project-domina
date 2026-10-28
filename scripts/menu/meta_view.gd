class_name MetaView
extends Control
# GRIMÓRIO: tela de meta-progressão (menu principal → GRIMÓRIO).
# Gasta COROAS em: desbloquear Leis/Cartas na loot pool, LEVAR itens na mochila
# da próxima run (preço por item, sobe a cada item levado).
# Tudo vive em MetaProgress (autoload); aqui é só a interface.

const MAIN_MENU_PATH: String = "res://main_menu.tscn"
const RULE_COLS: int = 4
const CARD_COLS: int = 6
const RULE_SCALE: float = 0.9
const CARD_SCALE: float = 1.25

const C_GOLD := Color(0.85, 0.64, 0.25)
const C_CREAM := Color(0.94, 0.9, 0.81)
const C_DIM := Color(0.6, 0.55, 0.65)
const C_GREEN := Color(0.36, 0.56, 0.31)
const C_RED := Color(0.72, 0.27, 0.29)
const RARITY_COLORS: Array[Color] = [
	Color(0.81, 0.76, 0.65), Color(0.25, 0.5, 0.6), Color(0.54, 0.36, 0.75), Color(0.85, 0.64, 0.25)]
const RARITY_NAMES: Array[String] = ["COMUM", "RARA", "ÉPICA", "LENDÁRIA"]

enum Tab { LEIS, CARTAS }
var _tab: int = Tab.LEIS

var _coroas_label: Label
var _coroas_panel: PanelContainer
var _tabs_row: HBoxContainer
var _scroll: ScrollContainer
var _side_panel: PanelContainer
var _tour: MetaTour
var _canvas: CanvasLayer
var _reveal: Control
var _help_btn: Button
var _tab_btns: Array[Button] = []
var _grid_holder: VBoxContainer
var _side_box: VBoxContainer
var _rule_tip: RuleCardTooltip
var _card_tip: ActionCardTooltip
var _msg_label: Label

func _ready() -> void:
	add_child(SpaceBackground.new())
	var canvas := CanvasLayer.new()
	_canvas = canvas
	add_child(canvas)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["left", "right"]:
		root.add_theme_constant_override("margin_" + m, 60)
	root.add_theme_constant_override("margin_top", 78)
	root.add_theme_constant_override("margin_bottom", 30)
	canvas.add_child(root)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	root.add_child(v)

	# --- Cabeçalho ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	var back := _btn("< VOLTAR", Color(0.8, 0.3, 0.35), Vector2(200, 56), 22)
	back.pressed.connect(_on_back)
	head.add_child(back)
	var title := Label.new()
	title.text = "GRIMÓRIO"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", C_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var coroas_panel := PanelContainer.new()
	_coroas_panel = coroas_panel
	coroas_panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.14, 0.1, 0.17, 0.97), C_GOLD, 10))
	coroas_panel.custom_minimum_size = Vector2(240, 56)
	head.add_child(coroas_panel)
	var coroas_row := HBoxContainer.new()
	coroas_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coroas_row.add_theme_constant_override("separation", 12)
	coroas_panel.add_child(coroas_row)
	coroas_row.add_child(PixelUI.make_hud_icon("icone_coroa", 32.0))
	_coroas_label = Label.new()
	_coroas_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coroas_label.add_theme_font_size_override("font_size", 28)
	_coroas_label.add_theme_color_override("font_color", C_GOLD)
	coroas_row.add_child(_coroas_label)

	# --- Abas ---
	var tabs := HBoxContainer.new()
	_tabs_row = tabs
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	var names := ["LEIS", "CARTAS"]
	for i in range(names.size()):
		var b := _btn(names[i], Color.WHITE, Vector2(200, 48), 22)
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_btns.append(b)
	_msg_label = Label.new()
	_msg_label.add_theme_font_size_override("font_size", 20)
	_msg_label.add_theme_color_override("font_color", C_CREAM)
	_msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tabs.add_child(_msg_label)

	# --- Corpo: lista (esq) + mochila (dir) ---
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PixelUI.style_scrollbar(scroll)
	# Janela de fundo (mesmo estilo do painel da mochila) atrás de leis/cartas.
	var window := PanelContainer.new()
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.14, 0.1, 0.17, 0.92), Color(0.49, 0.39, 0.54), 16))
	body.add_child(window)
	window.add_child(scroll)
	_grid_holder = VBoxContainer.new()
	_grid_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid_holder)

	var side := PanelContainer.new()
	_side_panel = side
	side.custom_minimum_size = Vector2(480, 0)
	side.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.14, 0.1, 0.17, 0.97), Color(0.49, 0.39, 0.54), 18))
	body.add_child(side)
	var side_v := VBoxContainer.new()
	side_v.add_theme_constant_override("separation", 12)
	side.add_child(side_v)
	_side_box = VBoxContainer.new()
	_side_box.add_theme_constant_override("separation", 10)
	side_v.add_child(_side_box)

	_rule_tip = RuleCardTooltip.new()
	add_child(_rule_tip)
	_card_tip = ActionCardTooltip.new()
	add_child(_card_tip)
	_build_help_button(canvas)
	_tour = MetaTour.new()
	_tour.target_provider = _tour_target
	_tour.tab_switcher = _set_tab
	_tour.finished.connect(_on_tour_finished)
	add_child(_tour)

	MetaProgress.changed.connect(_refresh)
	_refresh()
	# 1ª visita: o guia abre sozinho (depois de o layout assentar).
	if not MetaProgress.oficina_tour_seen:
		await get_tree().create_timer(0.5).timeout
		_tour.start()

# ---------------------------------------------------------------------
func _btn(text: String, accent: Color, min_size: Vector2, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.focus_mode = Control.FOCUS_NONE
	PixelUI.skin_button(b, accent)
	return b

func _set_tab(i: int) -> void:
	_tab = i
	_msg_label.text = ""
	_refresh()

func _say(t: String) -> void:
	_msg_label.text = t

func _on_back() -> void:
	SceneTransition.go(MAIN_MENU_PATH)

func _refresh() -> void:
	_coroas_label.text = str(MetaProgress.coroas)
	for i in range(_tab_btns.size()):
		PixelUI.skin_button(_tab_btns[i], C_GREEN if i == _tab else Color.WHITE)
	for c in _grid_holder.get_children():
		c.queue_free()
	match _tab:
		Tab.LEIS: _build_rules()
		Tab.CARTAS: _build_cards()
	_build_side()

func _new_grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 22)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_holder.add_child(g)
	return g

# Botão de preço/ação sob cada carta: ícone da Coroa + valor.
func _price_btn(text: String, width: float, accent: Color, disabled: bool = false, with_icon: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.focus_mode = Control.FOCUS_NONE
	PixelUI.skin_button(b, accent, "", "icone_coroa" if with_icon else "")
	b.disabled = disabled
	if not disabled:
		b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	return b

func _make_visual(item, is_rule: bool, scale_f: float) -> Control:
	var v: Control
	if is_rule:
		v = RuleCardVisual.new(item, _rule_tip, true, scale_f)
	else:
		v = ActionCardVisual.new(item, true, scale_f)
		v.mouse_entered.connect(func():
			_card_tip.show_tooltip(item, v.global_position + Vector2(ActionCardVisual.CARD_WIDTH * scale_f / 2.0, 0.0)))
		v.mouse_exited.connect(func(): _card_tip.hide_tooltip())
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	return v

# Carta/Lei LIBERADA + botão embaixo com o preço de LEVAR na próxima run (paga a
# cada run; sobe com cada item já na mochila). Na mochila: verde; clicar de
# novo devolve os Coroas.
func _item_tile(item, is_rule: bool, scale_f: float, width: float) -> Control:
	var id: String = item.id
	var t: String = "rule" if is_rule else "card"
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	var holder := CenterContainer.new()
	wrap.add_child(holder)
	var vis := _make_visual(item, is_rule, scale_f)
	holder.add_child(vis)
	var btn: Button
	if MetaProgress.bag_has(t, id):
		btn = _price_btn("NA MOCHILA", width, C_GREEN, false, false)
	else:
		var price: int = MetaProgress.carry_price(t, int(item.rarity))
		btn = _price_btn("LEVAR  %d" % price, width, Color(0.85, 0.64, 0.25), MetaProgress.coroas < price or MetaProgress.bag_count() >= MetaProgress.BAG_MAX)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_item_pressed.bind(id, is_rule))
	vis.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_item_pressed(id, is_rule))
	wrap.add_child(btn)
	return wrap

func _on_item_pressed(id: String, is_rule: bool) -> void:
	var t: String = "rule" if is_rule else "card"
	if MetaProgress.bag_has(t, id):
		MetaProgress.remove_from_bag(t, id)
		_say("Removido da mochila. Coroas devolvidas.")
	elif MetaProgress.bag_count() >= MetaProgress.BAG_MAX:
		_say("Mochila cheia (máx. %d itens)." % MetaProgress.BAG_MAX)
	elif not MetaProgress.add_to_bag(t, id):
		_say("Coroas insuficientes.")

func _section_title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", C_GOLD)
	return l

# ---- Baú (gacha) ----
var _chest_ref: Control = null   # painel do baú atual (alvo do guia)

# Painel do baú: baú animado (clicável) + chances por raridade + botão de abrir.
func _make_chest_panel(is_rule: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.12, 0.08, 0.15, 0.97), C_GOLD, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	panel.add_child(h)
	var remaining: int = MetaProgress.chest_remaining(is_rule)
	var price: int = MetaProgress.chest_price(is_rule)

	var fx := ChestFx.new()
	fx.kind = "leis" if is_rule else "cartas"
	fx.chest_scale = 1.0
	fx.custom_minimum_size = Vector2(330, 270)
	h.add_child(fx)
	if remaining <= 0:
		fx.modulate = Color(0.4, 0.38, 0.45)
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(info)
	var nm := Label.new()
	nm.text = "BAÚ DE LEIS" if is_rule else "BAÚ DE CARTAS"
	nm.add_theme_font_size_override("font_size", 34)
	nm.add_theme_color_override("font_color", C_GOLD)
	info.add_child(nm)
	var ds := Label.new()
	ds.text = ("Abra e descubra uma LEI nova!" if is_rule else "Abra e descubra uma CARTA nova. A raridade é sorteada!")
	ds.add_theme_font_size_override("font_size", 20)
	ds.add_theme_color_override("font_color", C_CREAM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(ds)

	# Chances efetivas (só entram as raridades que ainda têm algo bloqueado). Leis não mostram raridade (não é visível ao jogador).
	if not is_rule:
		var total_w := 0
		for r in range(4):
			if not MetaProgress.locked_of(is_rule, r).is_empty():
				total_w += MetaProgress.CHEST_ODDS[r]
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 10)
		info.add_child(chips)
		for r in range(4):
			var left: int = MetaProgress.locked_of(is_rule, r).size()
			var pct: float = 0.0 if left == 0 or total_w == 0 else 100.0 * float(MetaProgress.CHEST_ODDS[r]) / float(total_w)
			var chip := PanelContainer.new()
			var col: Color = RARITY_COLORS[r] if left > 0 else Color(0.3, 0.28, 0.33)
			chip.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.08, 0.06, 0.1, 0.95), col, 6))
			chips.add_child(chip)
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 0)
			chip.add_child(cv)
			var l1 := Label.new()
			l1.text = RARITY_NAMES[r]
			l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l1.add_theme_font_size_override("font_size", 15)
			l1.add_theme_color_override("font_color", col)
			cv.add_child(l1)
			var l2 := Label.new()
			l2.text = ("%s%%" % _fmt_pct(pct)) if left > 0 else "—"
			l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l2.add_theme_font_size_override("font_size", 22)
			l2.add_theme_color_override("font_color", C_CREAM if left > 0 else C_DIM)
			cv.add_child(l2)
			var l3 := Label.new()
			l3.text = "faltam %d" % left
			l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l3.add_theme_font_size_override("font_size", 13)
			l3.add_theme_color_override("font_color", C_DIM)
			cv.add_child(l3)

	var cnt := Label.new()
	cnt.text = ("%d %s ainda bloqueada%s" % [remaining, "Leis" if is_rule else "Cartas", "" if remaining == 1 else "s"]) if remaining > 0 else "TUDO DESBLOQUEADO!"
	cnt.add_theme_font_size_override("font_size", 18)
	cnt.add_theme_color_override("font_color", C_DIM if remaining > 0 else C_GREEN)
	info.add_child(cnt)
	if remaining > 0:
		var b := _price_btn("ABRIR  %d" % price, 220.0, Color(0.3, 0.9, 0.4), MetaProgress.coroas < price)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(_on_open_chest.bind(is_rule))
		info.add_child(b)
		fx.pressed.connect(_on_open_chest.bind(is_rule))
	_chest_ref = panel
	_grid_holder.add_child(panel)
	return panel

func _fmt_pct(p: float) -> String:
	return str(int(round(p))) if absf(p - round(p)) < 0.05 else "%.1f" % p

func _build_rules() -> void:
	_grid_holder.add_child(_section_title("BAÚ DE LEIS  (pague para sortear uma Lei bloqueada)"))
	_make_chest_panel(true)
	_grid_holder.add_child(_spacer(18))
	_grid_holder.add_child(_section_title("LEIS LIBERADAS"))
	var g := _new_grid(RULE_COLS)
	var rules: Array[RuleCard] = []
	for r in LootTables.get_all_rules():
		if MetaProgress.is_rule_unlocked(r.id):
			rules.append(r)
	rules.sort_custom(func(a, b): return int(a.rarity) < int(b.rarity))
	for r in rules:
		g.add_child(_item_tile(r, true, RULE_SCALE, RuleCardVisual.CARD_SIZE * RULE_SCALE))

func _build_cards() -> void:
	_grid_holder.add_child(_section_title("BAÚ DE CARTAS  (pague para sortear uma Carta bloqueada)"))
	_make_chest_panel(false)
	_grid_holder.add_child(_spacer(18))
	_grid_holder.add_child(_section_title("CARTAS LIBERADAS"))
	var g := _new_grid(CARD_COLS)
	var cards: Array[ActionCard] = []
	for c in LootTables.get_all_action_cards():
		if MetaProgress.is_card_unlocked(c.id):
			cards.append(c)
	cards.sort_custom(func(a, b): return int(a.rarity) < int(b.rarity))
	for c in cards:
		g.add_child(_item_tile(c, false, CARD_SCALE, ActionCardVisual.CARD_WIDTH * CARD_SCALE))

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _on_open_chest(is_rule: bool) -> void:
	if _reveal != null:
		return
	var res: Dictionary = MetaProgress.draw_chest(is_rule)
	if res.is_empty():
		_say("Coroas insuficientes.")
		return
	_show_chest_opening(String(res["id"]), is_rule, int(res["rarity"]))

# Sequência de abertura (baú + efeitos em código) e, no fim, a carta virando.
func _show_chest_opening(id: String, is_rule: bool, rarity: int) -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal = layer
	_canvas.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var fx := ChestFx.new()
	fx.idle_mode = false
	fx.kind = "leis" if is_rule else "cartas"
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fx)
	# cores de raridade do jogo são sóbrias; para os efeitos usa versões mais vivas
	# Leis: raridade invisível ao jogador -> efeitos dourados e de intensidade fixa.
	if is_rule:
		fx.play(1, _fx_color(3))
	else:
		fx.play(rarity, _fx_color(rarity))
	fx.opened.connect(func():
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(layer):
			_build_reveal_content(layer, id, is_rule, rarity))

func _fx_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.92, 0.88, 0.75)
		1: return Color(0.3, 0.7, 0.95)
		2: return Color(0.72, 0.4, 1.0)
		_: return Color(1.0, 0.8, 0.25)

func _build_reveal_content(layer: Control, id: String, is_rule: bool, rarity: int) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var fxc: Color = _fx_color(rarity)
	var rl := Label.new()
	rl.visible = not is_rule
	rl.text = RARITY_NAMES[rarity] + ("!" if rarity > 0 else "")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.add_theme_font_size_override("font_size", 40 + 8 * rarity)
	rl.add_theme_color_override("font_color", fxc)
	rl.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.07))
	rl.add_theme_constant_override("outline_size", 10)
	rl.pivot_offset = Vector2(160.0, 30.0)
	rl.scale = Vector2(0.2, 0.2)
	v.add_child(rl)
	var t := Label.new()
	t.text = "NOVA LEI DESBLOQUEADA!" if is_rule else "NOVA CARTA DESBLOQUEADA!"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", C_GOLD)
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.07))
	t.add_theme_constant_override("outline_size", 8)
	v.add_child(t)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(416, 400) if is_rule else Vector2(300, 428)
	v.add_child(holder)
	var vis: Control
	if is_rule:
		vis = RuleCardVisual.new(_find_rule(id), _rule_tip, false, 1.3)
	else:
		vis = ActionCardVisual.new(_find_card(id), false, 2.0)
	holder.add_child(vis)
	var hint := Label.new()
	hint.text = "Clique para continuar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", C_DIM)
	hint.modulate.a = 0.0
	v.add_child(hint)
	vis.play_flip_reveal(0.15)
	var pop := create_tween()
	pop.tween_property(rl, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(hint, "modulate:a", 1.0, 0.3)
	var armed := [false]
	tw.tween_callback(func(): armed[0] = true)
	layer.gui_input.connect(func(ev):
		if armed[0] and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			layer.queue_free()
			_reveal = null)

func _find_rule(id: String) -> RuleCard:
	for r in LootTables.get_all_rules():
		if r.id == id:
			return r
	return null

func _find_card(id: String) -> ActionCard:
	for c in LootTables.get_all_action_cards():
		if c.id == id:
			return c
	return null

func _rule_name(id: String) -> String:
	for r in LootTables.get_all_rules():
		if r.id == id:
			return r.name
	return id

func _card_name(id: String) -> String:
	for c in LootTables.get_all_action_cards():
		if c.id == id:
			return c.name
	return id

# --- Painel "MOCHILA" (itens que vão na próxima run) ---
func _build_side() -> void:
	for c in _side_box.get_children():
		c.queue_free()
	_side_box.add_child(_side_title("MOCHILA DA PRÓXIMA RUN  %d/%d" % [MetaProgress.bag_count(), MetaProgress.BAG_MAX]))
	if MetaProgress.bag.is_empty():
		var empty := _side_line("As coroas só são gastas de verdade quando aperta em jogar")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.6, 0.55, 0.65))
		_side_box.add_child(empty)
	for e in MetaProgress.bag:
		_side_box.add_child(_bag_row(e))
	var sep := ColorRect.new()
	sep.color = Color(0.49, 0.39, 0.54, 0.6)
	sep.custom_minimum_size = Vector2(0, 2)
	_side_box.add_child(sep)
	var paid := MetaProgress.bag_total_paid()
	var tot := HBoxContainer.new()
	tot.add_theme_constant_override("separation", 8)
	var tl := _side_line("TOTAL PAGO")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tot.add_child(tl)
	tot.add_child(PixelUI.make_hud_icon("icone_coroa", 28.0))
	var tv := _side_line(str(paid))
	tv.add_theme_color_override("font_color", C_GOLD)
	tot.add_child(tv)
	_side_box.add_child(tot)
	if not MetaProgress.bag.is_empty():
		var clear := _btn("ESVAZIAR (devolve %d)" % paid, Color(0.8, 0.3, 0.35), Vector2(0, 48), 20)
		clear.pressed.connect(func():
			MetaProgress.clear_bag()
			_say("Mochila esvaziada. Coroas devolvidas."))
		_side_box.add_child(clear)

func _bag_row(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var is_rule: bool = e["t"] == "rule"
	if not is_rule:
		var card := _find_card(e["id"])
		if card != null and card.icon_path != "" and ResourceLoader.exists(card.icon_path):
			var tr := TextureRect.new()
			tr.texture = load(card.icon_path)
			tr.custom_minimum_size = Vector2(40, 40)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(tr)
	else:
		var tag := _side_line("LEI")
		tag.add_theme_color_override("font_color", C_GOLD)
		row.add_child(tag)
	var nm := _side_line(_rule_name(e["id"]) if is_rule else _card_name(e["id"]))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	row.add_child(PixelUI.make_hud_icon("icone_coroa", 24.0))
	var pv := _side_line(str(int(e["paid"])))
	pv.add_theme_color_override("font_color", C_GOLD)
	row.add_child(pv)
	return row

func _side_title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", C_GOLD)
	return l

func _side_line(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", C_CREAM)
	return l

# ---------------------------------------------------------------------
# Guia do Grimório
# ---------------------------------------------------------------------
# Botão de informação (i) no canto superior direito, ao lado da engrenagem das Configurações.
func _build_help_button(canvas: CanvasLayer) -> void:
	_help_btn = Button.new()
	_help_btn.custom_minimum_size = Vector2(48, 48)
	_help_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_help_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help_btn.offset_right = -(14.0 + 48.0 + 10.0)
	_help_btn.offset_left = _help_btn.offset_right - 48.0
	_help_btn.offset_top = 14.0
	_help_btn.offset_bottom = 62.0
	_help_btn.focus_mode = Control.FOCUS_NONE
	_help_btn.tooltip_text = "Rever o guia do Grimório"
	_help_btn.add_theme_font_size_override("font_size", 32)
	_help_btn.add_theme_color_override("font_color", C_GOLD)
	_help_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.6))
	_help_btn.add_theme_stylebox_override("normal", PixelUI.make_pixel_panel(Color(0.14, 0.1, 0.17, 0.95), Color(0.49, 0.39, 0.54), 4))
	_help_btn.add_theme_stylebox_override("hover", PixelUI.make_pixel_panel(Color(0.23, 0.17, 0.25, 0.97), C_GOLD, 4))
	_help_btn.add_theme_stylebox_override("pressed", PixelUI.make_pixel_panel(Color(0.09, 0.06, 0.11, 0.97), C_GOLD, 4))
	_help_btn.pressed.connect(func(): _tour.start())
	# Ícone de informação (16x16 nativo, ampliado 2x sem filtro) centrado no botão.
	var q := TextureRect.new()
	q.texture = PixelUI.hud_texture("icone_informacao")
	q.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	q.stretch_mode = TextureRect.STRETCH_SCALE
	q.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.set_anchors_preset(Control.PRESET_CENTER)
	q.grow_horizontal = Control.GROW_DIRECTION_BOTH
	q.grow_vertical = Control.GROW_DIRECTION_BOTH
	q.offset_left = -16.0
	q.offset_right = 16.0
	q.offset_top = -16.0
	q.offset_bottom = 16.0
	_help_btn.add_child(q)
	canvas.add_child(_help_btn)

func _tour_target(id: String) -> Rect2:
	var c: Control = null
	match id:
		"coroas": c = _coroas_panel
		"tabs": c = _tabs_row
		"grid": c = _scroll
		"side": c = _side_panel
		"piles":
			if _chest_ref != null and is_instance_valid(_chest_ref) and _chest_ref.is_inside_tree():
				return _chest_ref.get_global_rect()
	return c.get_global_rect() if c != null else Rect2()

func _on_tour_finished() -> void:
	MetaProgress.mark_oficina_tour_seen()
