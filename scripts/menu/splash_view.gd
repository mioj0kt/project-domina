class_name SplashView
extends Control

# Abertura do jogo: logo animada da Wrong Moon Studios (GIF convertido em
# spritesheet pixel perfect, 320x180 nativo ampliado em escala inteira).
# Toca os frames com o tempo original do GIF, segura o último, faz fade out e
# vai para o menu. Clique / tecla pula (também com fade).

const NEXT_SCENE: String = "res://scenes/main_menu.tscn"
const SHEET_PATH: String = "res://assets/sprites/menu/splash/wrong_moon_sheet.png"

# Grade nativa do GIF (320x180) e recorte guardado na folha (só a área que muda).
const NATIVE_SIZE := Vector2(320, 180)
const CROP_POS := Vector2(99, 30)
const FRAME_SIZE := Vector2(122, 132)
const SHEET_COLS: int = 11

# Duração de cada frame, em ms (igual ao GIF original).
const FRAME_MS: Array[int] = [
	520, 360, 160, 120, 80, 120, 80, 80, 160, 720, 40, 40, 80, 400, 40, 40,
	40, 40, 40, 40, 40, 40, 80, 40, 40, 40, 40, 160, 40, 40, 40, 40,
	40, 40, 40, 40, 40, 80, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
	40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
	40, 40, 40, 80, 80, 80, 40, 160, 40, 40, 40, 40, 80, 40, 40, 40,
	80, 80, 80, 80, 80, 520]

# Quantos degraus de escala inteira a logo fica menor que a tela cheia (1080p: 6x -> 5x).
const LOGO_SCALE_STEPS_DOWN: float = 1.0
const HOLD_LAST_SEC: float = 1.0
const FADE_OUT_SEC: float = 0.8
const FADE_OUT_SKIP_SEC: float = 0.3
const FADE_IN_SEC: float = 0.25

var _sheet: Texture2D
var _frame: int = 0
var _elapsed_ms: float = 0.0
var _hold: float = 0.0
var _fade: float = 1.0          # 1 = tela preta
var _leaving: bool = false
var _fade_speed: float = 1.0 / FADE_IN_SEC
var _fade_target: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet = load(SHEET_PATH)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SettingsMenu.set_gear_visible(false)
	RenderingServer.set_default_clear_color(Color.BLACK)
	if _sheet == null:
		_finish()

func _exit_tree() -> void:
	SettingsMenu.set_gear_visible(true)

func _process(delta: float) -> void:
	if _leaving:
		_fade = move_toward(_fade, 1.0, delta * _fade_speed)
		if _fade >= 1.0:
			set_process(false)
			MainMenu.fade_in_pending = true
			get_tree().change_scene_to_file(NEXT_SCENE)
		queue_redraw()
		return
	_fade = move_toward(_fade, _fade_target, delta * _fade_speed)
	if _frame < FRAME_MS.size() - 1:
		_elapsed_ms += delta * 1000.0
		while _frame < FRAME_MS.size() - 1 and _elapsed_ms >= FRAME_MS[_frame]:
			_elapsed_ms -= FRAME_MS[_frame]
			_frame += 1
	else:
		_hold += delta
		if _hold >= HOLD_LAST_SEC:
			_finish(FADE_OUT_SEC)
	queue_redraw()

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

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _sheet == null:
		return
	# Escala inteira (pixel perfect): a grade 320x180 cabe em múltiplos exatos.
	var k: float = maxf(1.0, floorf(minf(size.x / NATIVE_SIZE.x, size.y / NATIVE_SIZE.y)) - LOGO_SCALE_STEPS_DOWN)
	var origin: Vector2 = ((size - NATIVE_SIZE * k) / 2.0).floor()
	var src := Rect2(Vector2(_frame % SHEET_COLS, _frame / SHEET_COLS) * FRAME_SIZE, FRAME_SIZE)
	var dst := Rect2(origin + CROP_POS * k, FRAME_SIZE * k)
	draw_texture_rect_region(_sheet, dst, src, Color(1, 1, 1, 1.0 - _fade))
