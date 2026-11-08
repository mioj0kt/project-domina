extends CanvasLayer
# Menu de configurações (autoload "SettingsMenu"): engrenagem fixa no canto
# superior direito de TODAS as cenas. Abre um painel com modo de tela,
# resolução e "sair para o menu". Salva em user://settings.cfg.
# Pausa o jogo enquanto aberto (a camada roda em PROCESS_MODE_ALWAYS).

const SAVE_PATH: String = "user://settings.cfg"
const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"
const GEAR_SIZE: float = 48.0
const GEAR_MARGIN: float = 14.0
const CLOSE_X_SIZE: float = 44.0
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const MODE_NAMES: Array[String] = ["JANELA", "JANELA TELA CHEIA", "TELA CHEIA"]

const C_GOLD := Color(0.85, 0.64, 0.25)
const C_CREAM := Color(0.94, 0.9, 0.81)

# 0 = janela, 1 = janela em tela cheia (sem borda), 2 = tela cheia (exclusiva)
var display_mode: int = 0
var resolution: Vector2i = Vector2i(1920, 1080)
var screen_fx: bool = true   # tremor de tela + hit-stop (Juice.screen_fx)
var _fx_btn: Button
# Volumes (0..1) por canal de áudio; ver Sfx.ensure_buses().
var volumes: Dictionary = {"Master": 1.0, "SFX": 1.0, "Music": 0.8}
const VOLUME_LABELS: Dictionary = {"Master": "VOLUME GERAL", "SFX": "EFEITOS SONOROS", "Music": "MÚSICA"}
var _vol_sliders: Dictionary = {}
var _vol_values: Dictionary = {}

var _close_x: Button
var _exit_sep: ColorRect
var _gear_btn: Button
var _backdrop: ColorRect
var _panel: PanelContainer
var _mode_btns: Array[Button] = []
var _res_label: Label
var _res_prev: Button
var _res_next: Button
var _exit_btn: Button
var _exit_armed: bool = false
var _res_list: Array[Vector2i] = []
var _apply_token: int = 0

func _ready() -> void:
	layer = 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Sliders pixel art em todo o jogo: mescla no tema do projeto (a janela raiz
	# sozinha não sobrepunha o tema customizado).
	var scroll_theme := PixelUI.make_scroll_theme()
	var project_theme := ThemeDB.get_project_theme()
	if project_theme != null:
		project_theme.merge_with(scroll_theme)
	else:
		get_tree().root.theme = scroll_theme
	Sfx.boot()
	_load_settings()
	_build_ui()
	_apply_display()

# ---------------------------------------------------------------------
# Persistência + aplicação
# ---------------------------------------------------------------------
func _load_settings() -> void:
	resolution = DisplayServer.window_get_size()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_sync_mode_from_window()
		_apply_volumes()
		return
	for k in volumes.keys():
		volumes[k] = clampf(float(cfg.get_value("audio", String(k), volumes[k])), 0.0, 1.0)
	_apply_volumes()
	display_mode = clampi(int(cfg.get_value("display", "mode", 0)), 0, 2)
	screen_fx = bool(cfg.get_value("display", "screen_fx", true))
	Juice.screen_fx = screen_fx
	var r = cfg.get_value("display", "resolution", resolution)
	if r is Vector2i:
		resolution = r

func _apply_volumes() -> void:
	for k in volumes.keys():
		Sfx.set_bus_volume(String(k), float(volumes[k]))

func _sync_mode_from_window() -> void:
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN: display_mode = 1
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: display_mode = 2
		_: display_mode = 0

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "mode", display_mode)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "screen_fx", screen_fx)
	for k in volumes.keys():
		cfg.set_value("audio", String(k), volumes[k])
	cfg.save(SAVE_PATH)

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# O modo precisa "assentar" antes de mexer no tamanho: espera um frame
	# entre as duas etapas (trocar de tela cheia para janela é assíncrono).
	var token := _apply_token + 1
	_apply_token = token
	match display_mode:
		0:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			await get_tree().process_frame
			await get_tree().process_frame
			if token != _apply_token:
				return
			DisplayServer.window_set_size(resolution)
			var screen := DisplayServer.window_get_current_screen()
			var origin := DisplayServer.screen_get_position(screen)
			var ssize := DisplayServer.screen_get_size(screen)
			@warning_ignore("integer_division")
			DisplayServer.window_set_position(origin + (ssize - resolution) / 2)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			# Em tela cheia exclusiva a resolução vale como o "modo de vídeo".
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			await get_tree().process_frame
			await get_tree().process_frame
			if token != _apply_token:
				return
			DisplayServer.window_set_size(resolution)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _available_resolutions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var screen_size := DisplayServer.screen_get_size()
	for r in RESOLUTIONS:
		if r.x <= screen_size.x and r.y <= screen_size.y:
			out.append(r)
	if not out.has(resolution):
		out.append(resolution)
		out.sort_custom(func(a, b): return a.x < b.x)
	return out

# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------
# A abertura (SplashView) esconde a engrenagem enquanto toca a logo.
func set_gear_visible(v: bool) -> void:
	if _gear_btn != null:
		_gear_btn.visible = v

func _build_ui() -> void:
	_gear_btn = Button.new()
	_gear_btn.custom_minimum_size = Vector2(GEAR_SIZE, GEAR_SIZE)
	_gear_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gear_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_gear_btn.offset_right = -GEAR_MARGIN
	_gear_btn.offset_top = GEAR_MARGIN
	_gear_btn.offset_left = -GEAR_MARGIN - GEAR_SIZE
	_gear_btn.offset_bottom = GEAR_MARGIN + GEAR_SIZE
	_gear_btn.focus_mode = Control.FOCUS_NONE
	_gear_btn.tooltip_text = "Configurações"
	_gear_btn.add_theme_stylebox_override("normal", PixelUI.make_pixel_panel(Color(0.14, 0.1, 0.17, 0.95), Color(0.49, 0.39, 0.54), 4))
	_gear_btn.add_theme_stylebox_override("hover", PixelUI.make_pixel_panel(Color(0.23, 0.17, 0.25, 0.97), C_GOLD, 4))
	_gear_btn.add_theme_stylebox_override("pressed", PixelUI.make_pixel_panel(Color(0.09, 0.06, 0.11, 0.97), C_GOLD, 4))
	_gear_btn.pressed.connect(toggle)
	add_child(_gear_btn)
	# Ícone do kit do HUD (16x16, ampliado 2x sem filtro).
	var icon := PixelUI.make_hud_icon("icone_configuracoes", 32.0)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	icon.offset_left = -16.0
	icon.offset_right = 16.0
	icon.offset_top = -18.0
	icon.offset_bottom = 14.0
	_gear_btn.add_child(icon)

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.05, 0.03, 0.07, 0.72)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", PixelUI.make_tooltip_panel(3, 18))   # mesmo fundo dos tooltips (tooltip_fundo.png)
	center.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 28)
	v.custom_minimum_size = Vector2(900, 0)
	_panel.add_child(v)

	var title := Label.new()
	title.text = "CONFIGURAÇÕES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", BW_WHITE)
	v.add_child(title)

	v.add_child(_section_label("MODO DE TELA"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 14)
	v.add_child(mode_row)
	for i in range(MODE_NAMES.size()):
		var b := Button.new()
		b.text = MODE_NAMES[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_mode_pressed.bind(i))
		mode_row.add_child(b)
		_mode_btns.append(b)

	v.add_child(_section_label("RESOLUÇÃO"))
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 14)
	v.add_child(res_row)
	_res_prev = _small_button("<")
	_res_prev.pressed.connect(_on_res_step.bind(-1))
	res_row.add_child(_res_prev)
	_res_label = Label.new()
	_res_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_res_label.add_theme_font_size_override("font_size", 36)
	_res_label.add_theme_color_override("font_color", BW_WHITE)
	res_row.add_child(_res_label)
	_res_next = _small_button(">")
	_res_next.pressed.connect(_on_res_step.bind(1))
	res_row.add_child(_res_next)

	v.add_child(_section_label("ÁUDIO"))
	for k in ["Master", "SFX", "Music"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		v.add_child(row)
		var name_l := Label.new()
		name_l.text = String(VOLUME_LABELS[k])
		name_l.custom_minimum_size = Vector2(300, 0)
		name_l.add_theme_font_size_override("font_size", 26)
		name_l.add_theme_color_override("font_color", BW_WHITE)
		row.add_child(name_l)
		var sl := PixelSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(volumes[k])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.focus_mode = Control.FOCUS_NONE
		row.add_child(sl)
		var val_l := Label.new()
		val_l.custom_minimum_size = Vector2(96, 0)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.add_theme_font_size_override("font_size", 26)
		val_l.add_theme_color_override("font_color", BW_WHITE)
		val_l.text = "%d%%" % roundi(float(volumes[k]) * 100.0)
		row.add_child(val_l)
		_vol_sliders[k] = sl
		_vol_values[k] = val_l
		sl.value_changed.connect(_on_volume_changed.bind(k))
		# Solta o slider de efeitos = toca um som de exemplo.
		if k == "SFX":
			sl.drag_ended.connect(func(_c): Sfx.play("mover"))

	v.add_child(_section_label("EFEITOS DE TELA (TREMOR E IMPACTO)"))
	_fx_btn = Button.new()
	_fx_btn.toggle_mode = true
	_fx_btn.custom_minimum_size = Vector2(0, 72)
	_fx_btn.add_theme_font_size_override("font_size", 28)
	_fx_btn.focus_mode = Control.FOCUS_NONE
	_fx_btn.pressed.connect(func():
		screen_fx = not screen_fx
		Juice.screen_fx = screen_fx
		_save_settings()
		_refresh())
	v.add_child(_fx_btn)

	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 21)
	hint.add_theme_color_override("font_color", BW_GRAY)
	v.add_child(hint)

	_exit_sep = ColorRect.new()
	var sep := _exit_sep
	sep.color = Color(BW_WHITE, 0.35)
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)

	_exit_btn = Button.new()
	_exit_btn.custom_minimum_size = Vector2(0, 76)
	_exit_btn.add_theme_font_size_override("font_size", 30)
	_exit_btn.focus_mode = Control.FOCUS_NONE
	_color_button(_exit_btn, C_RED)
	_exit_btn.pressed.connect(_on_exit_pressed)
	v.add_child(_exit_btn)

	# Fechar: "X" no canto superior direito da janela (posicionado depois do layout).
	_close_x = Button.new()
	_close_x.custom_minimum_size = Vector2(CLOSE_X_SIZE, CLOSE_X_SIZE)
	_close_x.size = Vector2(CLOSE_X_SIZE, CLOSE_X_SIZE)
	_close_x.focus_mode = Control.FOCUS_NONE
	_close_x.tooltip_text = "Fechar"
	PixelUI.skin_button(_close_x, C_RED, "", "icone_fechar")
	_close_x.pressed.connect(close)
	_backdrop.add_child(_close_x)
	_panel.item_rect_changed.connect(func(): call_deferred("_place_close_x"))
	_backdrop.visibility_changed.connect(_on_backdrop_visibility)

func _on_backdrop_visibility() -> void:
	if not _backdrop.visible:
		return
	# Espera o layout assentar (o painel só ganha tamanho depois de aparecer).
	await get_tree().process_frame
	await get_tree().process_frame
	_place_close_x()

func _place_close_x() -> void:
	if _close_x == null or _panel == null:
		return
	var r := _panel.get_global_rect()
	var xs: Vector2 = _close_x.get_combined_minimum_size().max(_close_x.size)   # o skin pode ser maior que CLOSE_X_SIZE
	_close_x.position = Vector2(r.end.x - xs.x - 20.0, r.position.y + 20.0) - _backdrop.global_position

# --- Visual preto e branco da janela de configurações ---
# Paleta tirada do ícone de X (icone_fechar.png): quase-preto e creme.
const BW_BLACK := Color8(20, 14, 20)
const BW_WHITE := Color8(247, 241, 226)
const BW_GRAY := Color8(207, 194, 160)
const BW_DIM := Color8(74, 58, 70)

func _bw_box(bg: Color, border: Color, border_w: int = 3, margin: int = 10) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(border_w)
	st.set_content_margin_all(margin)
	return st

# Botões: o mesmo skin (PixelUI.skin_button) do menu inicial, tingido pela cor.
func _color_button(b: Button, accent: Color, _on: bool = false) -> void:
	PixelUI.skin_button(b, accent)

const C_GREEN := Color(0.35, 0.8, 0.45)
const C_RED := Color(0.9, 0.32, 0.36)

func _section_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", BW_GRAY)
	return l

func _small_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(88, 72)
	b.add_theme_font_size_override("font_size", 34)
	b.focus_mode = Control.FOCUS_NONE
	_color_button(b, C_GOLD)
	return b

func _refresh() -> void:
	for i in range(_mode_btns.size()):
		var on := i == display_mode
		_mode_btns[i].button_pressed = on
		_color_button(_mode_btns[i], C_GREEN if on else Color.WHITE, on)
	_fx_btn.button_pressed = screen_fx
	_fx_btn.text = "LIGADOS" if screen_fx else "DESLIGADOS"
	_color_button(_fx_btn, C_GREEN if screen_fx else C_RED, screen_fx)
	_res_list = _available_resolutions()
	_res_label.text = "%d x %d" % [resolution.x, resolution.y]
	var idx := _res_list.find(resolution)
	var can_res := display_mode != 1  # janela sem borda usa a resolução da tela
	_res_prev.disabled = not can_res or idx <= 0
	_res_next.disabled = not can_res or idx >= _res_list.size() - 1
	_res_label.modulate = Color.WHITE if can_res else Color(1, 1, 1, 0.4)
	var hint: Label = _panel.find_child("Hint", true, false)
	hint.text = "Janela tela cheia usa a resolução do monitor." if display_mode == 1 else ""
	var in_menu := _in_main_menu()
	_exit_btn.visible = not in_menu
	_exit_sep.visible = not in_menu   # separador só existe para o botão de sair
	_exit_armed = false
	_exit_btn.text = "SAIR PARA O MENU"

func _in_main_menu() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == MAIN_MENU_PATH

# ---------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------
# ESC abre/fecha as configurações (telas que usam ESC para fechar algo
# marcam o evento como tratado antes, então não chega aqui).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _backdrop.visible:
		close()
	else:
		open()

func open() -> void:
	_refresh()
	_backdrop.visible = true
	get_tree().paused = true

func close() -> void:
	_backdrop.visible = false
	get_tree().paused = false

func _on_volume_changed(val: float, k: String) -> void:
	volumes[k] = val
	Sfx.set_bus_volume(k, val)
	(_vol_values[k] as Label).text = "%d%%" % roundi(val * 100.0)
	_save_settings()

func _on_mode_pressed(i: int) -> void:
	display_mode = i
	_apply_display()
	_save_settings()
	_refresh()

func _on_res_step(dir: int) -> void:
	var idx := _res_list.find(resolution)
	idx = clampi(idx + dir, 0, _res_list.size() - 1)
	resolution = _res_list[idx]
	_apply_display()
	_save_settings()
	_refresh()

func _on_exit_pressed() -> void:
	# Dois cliques: o primeiro pede confirmação (a run em andamento se perde).
	if not _exit_armed:
		_exit_armed = true
		_exit_btn.text = "CONFIRMAR SAÍDA?"
		return
	close()
	if TutorialManager != null and TutorialManager.is_active:
		TutorialManager.end_tutorial()
	else:
		MetaProgress.settle_run(false, false)  # abandonar a run também paga o que ela rendeu
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_PATH)
