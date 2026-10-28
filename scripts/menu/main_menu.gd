class_name MainMenu
extends Control

const MAP_SCENE_PATH: String = "res://map_view.tscn"
const META_SCENE_PATH: String = "res://meta_view.tscn"
const TUTORIAL_MAP_SCENE_PATH: String = "res://tutorial_map_view.tscn"

# A abertura (splash) liga isto antes de trocar de cena: o menu então surge
# do preto em vez de aparecer de uma vez.
static var fade_in_pending: bool = false
const FADE_IN_SEC: float = 0.9

func _ready() -> void:
	_setup_ui()
	if fade_in_pending:
		fade_in_pending = false
		_play_fade_in()

func _play_fade_in() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, FADE_IN_SEC)
	tw.tween_callback(layer.queue_free)

# Quanto o logo + botões sobem em relação ao centro da tela.
const MENU_RAISE_PX: float = 70.0

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "MenuUILayer"
	add_child(canvas)

	# Fundo: universo com estrelas (procedural, atrás de tudo).
	add_child(SpaceBackground.new())

	var center_box = VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.add_theme_constant_override("separation", 22)
	canvas.add_child(center_box)

	center_box.add_child(_make_logo())

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 30)
	center_box.add_child(spacer)

	var play_btn = _make_menu_button("JOGAR", Color(0.12, 0.22, 0.16), Color(0.3, 0.9, 0.4))
	play_btn.pressed.connect(_on_play_pressed)
	center_box.add_child(play_btn)

	var meta_btn = _make_menu_button("GRIMÓRIO", Color(0.2, 0.16, 0.08), Color(0.85, 0.64, 0.25))
	meta_btn.pressed.connect(_on_meta_pressed)
	center_box.add_child(meta_btn)

	var tutorial_btn = _make_menu_button("TUTORIAL", Color(0.12, 0.16, 0.24), Color(0.35, 0.7, 1.0))
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	center_box.add_child(tutorial_btn)

	var quit_btn = _make_menu_button("SAIR", Color(0.2, 0.1, 0.12), Color(0.8, 0.3, 0.35))
	quit_btn.pressed.connect(_on_quit_pressed)
	center_box.add_child(quit_btn)

	_add_version_label(canvas)
	_add_reset_button(canvas)

	# Espaçador no fim: como a caixa é centralizada, ele empurra o conjunto
	# (logo + botões) pra cima em MENU_RAISE_PX pixels. Ajuste aqui.
	var raise_spacer = Control.new()
	raise_spacer.custom_minimum_size = Vector2(10, MENU_RAISE_PX * 2.0)
	center_box.add_child(raise_spacer)

# Logo em pixel art: escolhe entre a versão grande (640x256) e a pequena (320x128)
# a que der o maior tamanho com ESCALA INTEIRA que caiba na tela (sem borrar).
func _make_logo() -> Control:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var max_w: float = vp.x * 0.7
	var max_h: float = vp.y * 0.36
	var best_tex: Texture2D = null
	var best_scale: int = 1
	var best_w: float = 0.0
	for path in ["res://assets/sprites/ui/logo_domina.png", "res://assets/sprites/ui/logo_domina_pequena.png"]:
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var k: int = maxi(1, int(minf(max_w / tex.get_width(), max_h / tex.get_height())))
		var w: float = tex.get_width() * k
		if w * k > 0 and w > best_w and tex.get_height() * k <= max_h * 1.05:
			best_tex = tex
			best_scale = k
			best_w = w
	if best_tex == null:
		var fallback = Label.new()
		fallback.text = "DOMINA"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 84)
		return fallback
	var logo = TextureRect.new()
	logo.texture = best_tex
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.custom_minimum_size = Vector2(best_tex.get_width() * best_scale, best_tex.get_height() * best_scale)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return logo

func _make_menu_button(text: String, _bg_color: Color, border_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(360, 68)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 28)
	PixelUI.skin_button(btn, border_color)
	return btn

# Versão do jogo (Project Settings > Application > Config > Version), discreta
# no canto inferior direito.
func _add_version_label(canvas: CanvasLayer) -> void:
	var v: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if v == "":
		return
	var lbl := Label.new()
	lbl.text = "v" + v
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.9, 0.81, 0.4))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl.offset_right = -16
	lbl.offset_bottom = -10
	canvas.add_child(lbl)

# Apagar progresso: botão discreto no canto inferior esquerdo. Dois cliques (o
# primeiro pede confirmação e desarma sozinho depois de alguns segundos). Zera
# TUDO do Grimório (coroas, desbloqueios, mochila, guias vistos) e recarrega
# o menu. Mantém as configurações de tela (user://settings.cfg).
var _reset_btn: Button = null
var _reset_armed: bool = false
var _reset_gen: int = 0

func _add_reset_button(canvas: CanvasLayer) -> void:
	_reset_btn = Button.new()
	_reset_btn.text = "APAGAR PROGRESSO"
	_reset_btn.custom_minimum_size = Vector2(330, 44)
	_reset_btn.add_theme_font_size_override("font_size", 21)
	_reset_btn.focus_mode = Control.FOCUS_NONE
	_reset_btn.modulate = Color(1, 1, 1, 0.55)
	PixelUI.skin_button(_reset_btn, Color(0.8, 0.3, 0.35))
	_reset_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_reset_btn.grow_horizontal = Control.GROW_DIRECTION_END
	_reset_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_reset_btn.offset_left = 16
	_reset_btn.offset_bottom = -12
	_reset_btn.pressed.connect(_on_reset_pressed)
	canvas.add_child(_reset_btn)

func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_gen += 1
		var gen := _reset_gen
		_reset_btn.text = "CLIQUE DE NOVO PARA APAGAR"
		_reset_btn.modulate = Color(1, 1, 1, 1)
		await get_tree().create_timer(4.0).timeout
		if gen == _reset_gen and is_instance_valid(_reset_btn):
			_reset_armed = false
			_reset_btn.text = "APAGAR PROGRESSO"
			_reset_btn.modulate = Color(1, 1, 1, 0.55)
		return
	_reset_gen += 1
	MetaProgress.reset_all()
	RunManager.start_new_run()  # descarta qualquer run em andamento
	get_tree().call_deferred("change_scene_to_file", "res://main_menu.tscn")

func _on_play_pressed() -> void:
	# Quem nunca concluiu o tutorial recebe um aviso antes da primeira run.
	if not MetaProgress.tutorial_done and not MetaProgress.tutorial_warned:
		_show_tutorial_warning()
		return
	_start_run()

func _start_run() -> void:
	if RunManager != null:
		RunManager.start_new_run()
		MetaProgress.consume_bag_into_run()
	SceneTransition.go(MAP_SCENE_PATH)

func _on_meta_pressed() -> void:
	SceneTransition.go(META_SCENE_PATH)

func _on_tutorial_pressed() -> void:
	if TutorialManager != null:
		TutorialManager.start_tutorial()
	SceneTransition.go(TUTORIAL_MAP_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()

# ---------------------------------------------------------------------
# Aviso "faça o tutorial antes" (só enquanto MetaProgress.tutorial_done = false)
# ---------------------------------------------------------------------
var _warn_layer: CanvasLayer = null

func _show_tutorial_warning() -> void:
	if _warn_layer != null:
		return
	_warn_layer = CanvasLayer.new()
	_warn_layer.layer = 150
	add_child(_warn_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_warn_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warn_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", PixelUI.make_dialogue_panel(Color(0.85, 0.64, 0.25), 22, 4))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	panel.add_child(v)

	var title := Label.new()
	title.text = "TEM CERTEZA?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.85, 0.64, 0.25))
	v.add_child(title)

	var msg := Label.new()
	msg.text = "Você ainda não concluiu o tutorial.\nRecomendo fortemente que o conclua antes da sua primeira jogatina."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", Color(0.94, 0.9, 0.81))
	v.add_child(msg)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)

	var tut_btn := _make_menu_button("FAZER O TUTORIAL", Color.BLACK, Color(0.35, 0.7, 1.0))
	tut_btn.custom_minimum_size = Vector2(330, 64)
	tut_btn.pressed.connect(func():
		_close_tutorial_warning()
		_on_tutorial_pressed())
	row.add_child(tut_btn)

	var play_btn := _make_menu_button("JOGAR MESMO ASSIM", Color.BLACK, Color(0.3, 0.9, 0.4))
	play_btn.custom_minimum_size = Vector2(330, 64)
	play_btn.pressed.connect(func():
		MetaProgress.mark_tutorial_warned()   # não pergunta de novo
		_close_tutorial_warning()
		_start_run())
	row.add_child(play_btn)

func _close_tutorial_warning() -> void:
	if _warn_layer != null:
		_warn_layer.queue_free()
		_warn_layer = null

func _unhandled_input(event: InputEvent) -> void:
	if _warn_layer != null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_tutorial_warning()
		get_viewport().set_input_as_handled()
