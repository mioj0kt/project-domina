class_name RunOverView
extends Control
# Tela de FIM DE RUN (derrota ou Chefe derrotado): conta as Coroas ganhas de
# forma animada (ícone a ícone, com o total subindo) e oferece voltar ao menu
# ou ir direto ao Grimório. Lê MetaProgress.last_summary (preenchido por
# MetaProgress.settle_run). Clique em qualquer lugar pula a animação.

const MAIN_MENU_PATH: String = "res://main_menu.tscn"
const META_SCENE_PATH: String = "res://meta_view.tscn"
const MAX_ICONS_PER_ROW: int = 20

const C_GOLD := Color(0.85, 0.64, 0.25)
const C_CREAM := Color(0.94, 0.9, 0.81)
const C_RED := Color(0.72, 0.27, 0.29)

var _summary: Dictionary = {}
var _rows_box: VBoxContainer
var _total_label: Label
var _bank_label: Label
var _msg_label: Label
var _menu_btn: Button
var _meta_btn: Button
var _total_row: Control
var _tour: MetaTour
var _skip: bool = false
var _done: bool = false
var _fx: VictoryFx

func _ready() -> void:
	_summary = MetaProgress.last_summary.duplicate()
	if _summary.is_empty():
		_summary = {"won": false, "duels": 0, "strong": 0, "boss": false, "total": 0,
			"before": MetaProgress.coroas, "after": MetaProgress.coroas}
	add_child(SpaceBackground.new())
	_build_ui()
	_run_tally()

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	# Comemoração por código por trás do painel (vitória da run = Chefe caiu).
	_fx = VictoryFx.new()
	canvas.add_child(_fx)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var won: bool = bool(_summary["won"])
	var border: Color = C_GOLD if won else C_RED
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.12, 0.08, 0.15, 0.98), border, 26))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(980, 0)
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	var title := Label.new()
	title.text = "VOCÊ DOMINOU O TABULEIRO!" if won else "FIM DA RUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", C_GOLD if won else Color(0.95, 0.35, 0.38))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.07))
	title.add_theme_constant_override("outline_size", 8)
	v.add_child(title)
	title.pivot_offset = Vector2(490.0, 30.0)
	title.scale = Vector2(0.4, 0.4)
	var title_tw := create_tween()
	title_tw.tween_property(title, "scale", Vector2(1.12, 1.12) if won else Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_tw.tween_property(title, "scale", Vector2.ONE, 0.2)
	if won:
		_fx.start(true, Vector2(get_viewport_rect().size.x * 0.5, 120.0))

	var sub := Label.new()
	# Só a vitória tem subtítulo; na derrota o texto foi removido (e o espaço some junto).
	sub.text = "O Chefe caiu. Seus feitos rendem Coroas." if won else ""
	sub.visible = won
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", C_CREAM)
	v.add_child(sub)

	v.add_child(_divider())
	_build_run_summary(v)
	v.add_child(_divider())

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 12)
	_rows_box.custom_minimum_size = Vector2(0, 90)
	v.add_child(_rows_box)

	v.add_child(_divider())

	# Total dinâmico: ícone + "+N" subindo conforme as Coroas aparecem.
	var total_row := HBoxContainer.new()
	total_row.alignment = BoxContainer.ALIGNMENT_CENTER
	total_row.add_theme_constant_override("separation", 14)
	v.add_child(total_row)
	_total_row = total_row
	total_row.add_child(PixelUI.make_hud_icon("icone_coroa", 48.0))
	_total_label = Label.new()
	_total_label.text = "+0"
	_total_label.add_theme_font_size_override("font_size", 56)
	_total_label.add_theme_color_override("font_color", C_GOLD)
	total_row.add_child(_total_label)

	_bank_label = Label.new()
	_bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bank_label.add_theme_font_size_override("font_size", 22)
	_bank_label.add_theme_color_override("font_color", Color(0.81, 0.76, 0.65))
	_bank_label.text = "COROAS NO GRIMÓRIO: %d" % int(_summary["before"])
	v.add_child(_bank_label)

	_msg_label = Label.new()
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_label.add_theme_font_size_override("font_size", 20)
	_msg_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.65))
	_msg_label.custom_minimum_size = Vector2(0, 28)
	v.add_child(_msg_label)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	v.add_child(btns)
	_menu_btn = _make_btn("VOLTAR AO MENU", Color(0.8, 0.3, 0.35))
	_menu_btn.pressed.connect(func(): SceneTransition.go(MAIN_MENU_PATH))
	btns.add_child(_menu_btn)
	_meta_btn = _make_btn("IR AO GRIMÓRIO", Color(0.85, 0.64, 0.25))
	_meta_btn.pressed.connect(func(): SceneTransition.go(META_SCENE_PATH))
	btns.add_child(_meta_btn)
	_menu_btn.disabled = true
	_meta_btn.disabled = true

# Resumo da run: quadradinhos de estatística + as Leis e Cartas que o jogador levou.
func _build_run_summary(parent: VBoxContainer) -> void:
	var laws: Array = _summary.get("laws", [])
	var cards: Array = _summary.get("cards", [])
	var duels: int = int(_summary["duels"]) + int(_summary["strong"]) + (1 if bool(_summary["boss"]) else 0)

	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 14)
	parent.add_child(tiles)
	tiles.add_child(_stat_tile("VITÓRIAS", str(duels)))
	tiles.add_child(_stat_tile("DUELOS FORTES", str(int(_summary["strong"]))))
	tiles.add_child(_stat_tile("LEIS", str(laws.size())))
	tiles.add_child(_stat_tile("CARTAS", str(cards.size())))
	tiles.add_child(_stat_tile("OURO FINAL", str(int(_summary.get("gold", 0)))))

	parent.add_child(_chip_section("LEIS USADAS", laws))
	parent.add_child(_chip_section("CARTAS NO BARALHO", cards))

func _stat_tile(title: String, value: String) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", PixelUI.make_flat_panel(Color(0.17, 0.12, 0.21, 0.95), Color(0.49, 0.39, 0.54), 8))
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(160, 0)
	col.add_theme_constant_override("separation", 2)
	pc.add_child(col)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 36)
	val.add_theme_color_override("font_color", C_GOLD)
	col.add_child(val)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(0.81, 0.76, 0.65))
	col.add_child(t)
	return pc

func _chip_section(title: String, items: Array) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 18)
	h.add_theme_color_override("font_color", Color(0.81, 0.76, 0.65))
	box.add_child(h)
	if items.is_empty():
		var none := Label.new()
		none.text = "Nenhuma."
		none.add_theme_font_size_override("font_size", 18)
		none.add_theme_color_override("font_color", Color(0.6, 0.55, 0.65))
		box.add_child(none)
		return box
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	box.add_child(flow)
	for it in items:
		var col: Color = ActionCardVisual.get_rarity_color(int(it["rarity"]))
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", PixelUI.make_flat_panel(Color(0.12, 0.08, 0.15, 0.98), col, 6))
		var l := Label.new()
		l.text = str(it["name"])
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", col)
		chip.add_child(l)
		flow.add_child(chip)
	return box

func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.49, 0.39, 0.54, 0.6)
	d.custom_minimum_size = Vector2(0, 3)
	return d

func _make_btn(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 60)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	PixelUI.skin_button(b, accent)
	return b

func _input(event: InputEvent) -> void:
	if not _done and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip = true

# ---------------------------------------------------------------------
# Contagem animada
# ---------------------------------------------------------------------
func _rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var d: int = int(_summary["duels"])
	var s: int = int(_summary["strong"])
	rows.append({"label": "DUELOS VENCIDOS  x%d" % d, "amount": d * MetaProgress.COROAS_PER_DUEL})
	rows.append({"label": "DUELOS FORTES  x%d" % s, "amount": s * MetaProgress.COROAS_PER_STRONG})
	if bool(_summary["boss"]):
		rows.append({"label": "CHEFE DERROTADO", "amount": MetaProgress.COROAS_BOSS_WIN})
	return rows

func _wait(t: float) -> void:
	if not _skip:
		await get_tree().create_timer(t).timeout

func _run_tally() -> void:
	var running := 0
	await _wait(0.5)
	for item in _rows():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		_rows_box.add_child(row)

		var lbl := Label.new()
		lbl.text = item["label"]
		lbl.custom_minimum_size = Vector2(300, 0)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", C_CREAM)
		row.add_child(lbl)

		var icons := HBoxContainer.new()
		icons.add_theme_constant_override("separation", 2)
		icons.custom_minimum_size = Vector2(0, 32)
		icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(icons)

		var val := Label.new()
		val.text = "+0"
		val.custom_minimum_size = Vector2(70, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 22)
		val.add_theme_color_override("font_color", C_GOLD)
		row.add_child(val)

		var amount: int = item["amount"]
		var delay := 0.16
		for i in range(amount):
			running += 1
			val.text = "+%d" % (i + 1)
			_total_label.text = "+%d" % running
			_bank_label.text = "COROAS NO GRIMÓRIO: %d" % (int(_summary["before"]) + running)
			if i < MAX_ICONS_PER_ROW:
				var ic := PixelUI.make_hud_icon("icone_coroa", 32.0)
				icons.add_child(ic)
				ic.pivot_offset = Vector2(16, 16)
				if not _skip:
					ic.scale = Vector2(0.3, 0.3)
					create_tween().tween_property(ic, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if not _skip:
				_pulse_total()
				await get_tree().create_timer(delay).timeout
				if is_instance_valid(_total_label):
					_fx.pop_at(_total_label.global_position + Vector2(_total_label.size.x * 0.5, _total_label.size.y * 0.3), 1)
				delay = maxf(0.03, delay * 0.9)
		await _wait(0.2)

	# Fecha com os valores finais (também cobre o "pular").
	var total: int = int(_summary["total"])
	_total_label.text = "+%d" % total
	_bank_label.text = "COROAS NO GRIMÓRIO: %d" % int(_summary["after"])
	if total == 0:
		_msg_label.text = "Nenhuma Coroa desta vez. Vença duelos para ganhar Coroas!"
	else:
		_msg_label.text = "Gaste suas Coroas no Grimório para desbloquear Leis e Cartas."
	if total > 0:
		_total_label.pivot_offset = _total_label.size / 2.0
		_total_label.scale = Vector2(1.4, 1.4)
		create_tween().tween_property(_total_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_fx.pop_at(_total_label.global_position + _total_label.size * 0.5, 12 if bool(_summary["won"]) else 8)
	_done = true
	_menu_btn.disabled = false
	_meta_btn.disabled = false
	# 1ª tela de fim de run: mini guia das Coroas.
	if not MetaProgress.run_over_tour_seen:
		await get_tree().create_timer(0.6).timeout
		_start_tour()
		await _tour.finished
	# 1º Chefe derrotado: aviso de que a alpha termina aqui.
	if bool(_summary["won"]) and not MetaProgress.alpha_end_seen:
		await get_tree().create_timer(0.5).timeout
		_show_alpha_end()

# ---------------------------------------------------------------------
# Mini guia das Coroas (só na primeira vez; reaproveita o MetaTour do Grimório)
# ---------------------------------------------------------------------
func _start_tour() -> void:
	if _tour != null:
		return
	_tour = MetaTour.new()
	_tour.steps = [
		{"text": "Estas são as suas COROAS, a moeda do GRIMÓRIO. Diferente do ouro, elas NÃO somem quando a run acaba: ficam guardadas para sempre.",
			"target": "total", "place": "below", "tab": -1},
		{"text": "Você ganha Coroas jogando: %d por duelo vencido, %d por duelo forte e %d ao derrotar o Chefe. Elas valem mesmo se você perder ou desistir da run." % [MetaProgress.COROAS_PER_DUEL, MetaProgress.COROAS_PER_STRONG, MetaProgress.COROAS_BOSS_WIN],
			"target": "rows", "place": "below", "tab": -1},
		{"text": "No GRIMÓRIO você gasta as Coroas para desbloquear CARTAS e LEIS novas, que passam a aparecer nas suas próximas runs, e para levar peças já na largada. Dê uma passada por lá!",
			"target": "meta", "place": "above", "tab": -1},
	]
	_tour.target_provider = _tour_target
	_tour.finished.connect(_on_tour_finished)
	add_child(_tour)
	_tour.start()

func _tour_target(id: String) -> Rect2:
	match id:
		"total": return _total_row.get_global_rect()
		"rows": return _rows_box.get_global_rect()
		"meta": return _meta_btn.get_global_rect()
	return Rect2()

func _on_tour_finished() -> void:
	MetaProgress.mark_run_over_tour_seen()
	if _tour != null:
		_tour.queue_free()
		_tour = null

func _pulse_total() -> void:
	_total_label.pivot_offset = _total_label.size / 2.0
	_total_label.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(_total_label, "scale", Vector2.ONE, 0.1)

# ---------------------------------------------------------------------
# Fim da alpha (aparece uma única vez, ao derrotar o Chefe pela 1ª vez)
# ---------------------------------------------------------------------
func _show_alpha_end() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 150
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_dialogue_panel(C_GOLD, 26, 4))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(820, 0)
	v.add_theme_constant_override("separation", 22)
	panel.add_child(v)

	var title := Label.new()
	title.text = "FIM DA VERSÃO ALPHA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", C_GOLD)
	v.add_child(title)

	var msg := Label.new()
	msg.text = "Infelizmente esta é a versão alpha e a jornada termina por aqui.\n\nNo jogo final, a partir daqui você seguiria para novas ilhas com novos temas além da floresta, com chefes únicos e a dificuldade aumentando ainda mais.\n\nAlém de ter novas leis e cartas para desbloquear no grimório."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", C_CREAM)
	v.add_child(msg)

	var ok := _make_btn("ENTENDIDO", Color(0.3, 0.9, 0.4))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		MetaProgress.mark_alpha_end_seen()
		layer.queue_free())
	v.add_child(ok)
