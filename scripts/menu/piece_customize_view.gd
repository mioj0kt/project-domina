class_name PieceCustomizeView
extends CanvasLayer

## "MINHA PEÇA" (menu inicial): o jogador escolhe a cor das suas peças e a cor
## da estrela da sua Dama. A peça do adversário não se escolhe.

signal closed

const C_GOLD := Color(0.85, 0.64, 0.25)
const C_CREAM := Color(0.94, 0.9, 0.81)

var _piece_prev: TextureRect
var _king_prev: TextureRect
var _name_label: Label
var _color_btns: Array[Button] = []
var _star_btns: Array[Button] = []

func _ready() -> void:
	layer = 150
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	panel.add_theme_stylebox_override("panel", PixelUI.make_dialogue_panel(C_GOLD, 26, 4))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	var title := Label.new()
	title.text = "MINHA PEÇA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", C_GOLD)
	v.add_child(title)

	# amostra grande: peça comum e Dama
	var prev := HBoxContainer.new()
	prev.alignment = BoxContainer.ALIGNMENT_CENTER
	prev.add_theme_constant_override("separation", 46)
	v.add_child(prev)
	_piece_prev = _preview()
	prev.add_child(_piece_prev)
	_king_prev = _preview()
	prev.add_child(_king_prev)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 26)
	_name_label.add_theme_color_override("font_color", C_CREAM)
	v.add_child(_name_label)

	v.add_child(_section("COR DA PEÇA"))
	var row := _row()
	v.add_child(row)
	for i in range(PieceSkin.SKINS.size()):
		var b := _swatch(PieceSkin.name_of(i))
		b.pressed.connect(_on_color.bind(i))
		row.add_child(b)
		_color_btns.append(b)

	v.add_child(_section("ESTRELA DA DAMA"))
	var row2 := _row()
	v.add_child(row2)
	for i in range(PieceSkin.STARS.size()):
		var b2 := _swatch(String(PieceSkin.STARS[i]["name"]))
		b2.pressed.connect(_on_star.bind(i))
		row2.add_child(b2)
		_star_btns.append(b2)


	var ok := Button.new()
	ok.text = "PRONTO"
	ok.custom_minimum_size = Vector2(300, 64)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.add_theme_font_size_override("font_size", 28)
	PixelUI.skin_button(ok, Color(0.3, 0.9, 0.4))
	ok.pressed.connect(close)
	v.add_child(ok)

	_refresh()

func _preview() -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(160, 160)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(C_CREAM, 0.75))
	return l

func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 10)
	return r

func _swatch(tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(68, 68)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return b

func _box(on: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color8(74, 58, 70) if on else Color8(20, 14, 20)
	st.border_color = C_GOLD if on else Color8(74, 58, 70)
	st.set_border_width_all(4 if on else 2)
	st.set_content_margin_all(6)
	return st

func _on_color(i: int) -> void:
	PieceSkin.set_player(i)
	_changed()

func _on_star(i: int) -> void:
	PieceSkin.set_star(i)
	_changed()

func _changed() -> void:
	Sfx.play("mover")
	SettingsMenu.save_now()
	_refresh()

func _refresh() -> void:
	_piece_prev.texture = PieceSkin.player_texture(false)
	_king_prev.texture = PieceSkin.player_texture(true)
	_name_label.text = "PEÇA %s  -  ESTRELA %s" % [PieceSkin.name_of(PieceSkin.player_idx), String(PieceSkin.STARS[PieceSkin.player_star]["name"])]
	for i in range(_color_btns.size()):
		_color_btns[i].icon = PieceSkin.texture(i, false)
		var st := _box(i == PieceSkin.player_idx)
		for k in ["normal", "hover", "pressed", "focus"]:
			_color_btns[i].add_theme_stylebox_override(k, st)
	for i in range(_star_btns.size()):
		_star_btns[i].icon = PieceSkin.king_texture(PieceSkin.player_idx, i)
		var st2 := _box(i == PieceSkin.player_star)
		for k in ["normal", "hover", "pressed", "focus"]:
			_star_btns[i].add_theme_stylebox_override(k, st2)

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
