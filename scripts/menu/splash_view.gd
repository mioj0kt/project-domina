class_name SplashView
extends Control

# Abertura do jogo: vídeo da Wrong Moon Studios (com som). Entra com fade, toca
# até o fim, segura o último quadro um instante, faz fade out e vai para o menu.
# Clique / tecla pula (também com fade).

const NEXT_SCENE: String = "res://scenes/main_menu.tscn"
const VIDEO_PATH: String = "res://assets/video/wrong_moon_intro.ogv"

const HOLD_LAST_SEC: float = 0.8
const FADE_OUT_SEC: float = 0.8
const FADE_OUT_SKIP_SEC: float = 0.3
const FADE_IN_SEC: float = 0.25

var _player: VideoStreamPlayer
var _shade: ColorRect
var _hold: float = 0.0
var _ended: bool = false
var _leaving: bool = false
var _fade: float = 1.0          # 1 = tela preta
var _fade_speed: float = 1.0 / FADE_IN_SEC
var _fade_target: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	SettingsMenu.set_gear_visible(false)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var stream: VideoStream = load(VIDEO_PATH) as VideoStream
	if stream == null:
		_finish()
		return
	_player = VideoStreamPlayer.new()
	_player.stream = stream
	_player.expand = true
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(func(): _ended = true)
	add_child(_player)
	_player.play()
	# Cortina preta por cima: faz o fade in / fade out.
	_shade = ColorRect.new()
	_shade.color = Color.BLACK
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

func _exit_tree() -> void:
	SettingsMenu.set_gear_visible(true)

func _process(delta: float) -> void:
	if _shade != null:
		_shade.color.a = _fade
	if _leaving:
		_fade = move_toward(_fade, 1.0, delta * _fade_speed)
		if _player != null:
			_player.volume_db = linear_to_db(maxf(1.0 - _fade, 0.001))
		if _fade >= 1.0:
			set_process(false)
			if _player != null:
				_player.stop()
			MainMenu.fade_in_pending = true
			get_tree().change_scene_to_file(NEXT_SCENE)
		return
	_fade = move_toward(_fade, _fade_target, delta * _fade_speed)
	if _ended:
		_hold += delta
		if _hold >= HOLD_LAST_SEC:
			_finish(FADE_OUT_SEC)

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_finish(FADE_OUT_SKIP_SEC)

func _gui_input(event: InputEvent) -> void:
	if not _leaving and event is InputEventMouseButton and event.pressed:
		_finish(FADE_OUT_SKIP_SEC)

func _finish(fade_sec: float = 0.01) -> void:
	if _leaving:
		return
	_leaving = true
	_fade_speed = 1.0 / maxf(fade_sec, 0.01)
