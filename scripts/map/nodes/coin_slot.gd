class_name CoinSlot
extends Control

# Palco da moeda na Mesa de Apostas: um medalhão de feltro com aro dourado
# onde a moeda cai, e as DUAS peças de verdade (branca e preta) nas laterais,
# que são os lados que o jogador pode chamar. Na hora de chamar as peças
# pulsam; com a moeda no ar, o centro fica livre pra ela.

const GOLD := Color(1.0, 0.82, 0.25)
const FELT := Color("#1d2a3a")
const FELT_L := Color("#2a3d55")

signal piece_clicked(white: bool)

var show_center: bool = true
var clickable: bool = false:
	set(v):
		clickable = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		_hover = -1
var _hover: int = -1   # 0 = branca, 1 = preta
var pulse_pieces: bool = false
var _t: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = false

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()

const PIECE_D: float = 120.0

func _radius() -> float:
	return GRID * PX * 0.5

func _piece_pos(white: bool) -> Vector2:
	var off: float = _radius() + 150.0
	return size / 2.0 + Vector2(-off if white else off, 0.0)

func _piece_at(p: Vector2) -> int:
	for i in range(2):
		if p.distance_to(_piece_pos(i == 0)) <= PIECE_D * 0.62:
			return i
	return -1

func _gui_input(event: InputEvent) -> void:
	if not clickable:
		return
	if event is InputEventMouseMotion:
		var h: int = _piece_at(event.position)
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i: int = _piece_at(event.position)
		if i >= 0:
			accept_event()
			piece_clicked.emit(i == 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1

# Medalhão em pixel art de verdade (mesma linguagem da Roleta): imagem GRID x GRID
# com filtro nearest — aro dourado de pedra com luz do alto-esquerda, feltro
# ameixa em xadrez (tema de damas) e um círculo central onde a moeda pousa.
const INK := Color("#241a2b")
const PLUM_D := Color("#3a2b41")
const PLUM_M := Color("#5a4561")
const PLUM_L := Color("#7c6489")
const CREAM := Color("#efe6cf")
const CREAM_D := Color("#cfc3a6")
const GOLD_C := Color("#d9a441")
const GOLD_D := Color("#9a6f2a")
const GRID: int = 60
const PX: int = 5
var _tex: ImageTexture = null

func _build_medal() -> void:
	var img := Image.create(GRID, GRID, false, Image.FORMAT_RGBA8)
	var c: float = GRID / 2.0
	var R: float = c - 0.5
	for y in range(GRID):
		for x in range(GRID):
			var dx: float = x + 0.5 - c
			var dy: float = y + 0.5 - c
			var r: float = sqrt(dx * dx + dy * dy)
			if r > R:
				continue
			var phi: float = atan2(dx, -dy)
			var lit: float = (cos(phi) - sin(phi)) * 0.7071
			var bay: int = [[0, 2], [3, 1]][y & 1][x & 1]
			var col: Color
			if r > R - 1.5:
				col = INK
			elif r > R - 6.5:
				col = GOLD_C
				if lit > 0.35:
					col = CREAM_D if (r > R - 3.5 and bay < 2) else GOLD_C
				elif lit < -0.25:
					col = GOLD_D
				if absf(r - (R - 5.5)) < 0.5:
					col = GOLD_D
			elif r > R - 8.0:
				col = INK
			else:
				# Feltro em xadrez 6x6 + vinheta em dither.
				var chk: bool = ((x / 6) + (y / 6)) % 2 == 0
				col = PLUM_M if chk else PLUM_D
				if r > R - 12.0 and bay < 2:
					col = col.darkened(0.25)
				# Pouso central: anel de tinta e miolo mais claro.
				if absf(r - 13.0) < 0.75:
					col = INK
				elif r < 12.2:
					col = PLUM_L if chk else PLUM_M
					if r > 9.5 and bay < 2:
						col = col.darkened(0.2)
			img.set_pixel(x, y, col)
	_tex = ImageTexture.create_from_image(img)

func _snap(v: float) -> float:
	return roundf(v / PX) * PX

func _pixel_ring(center: Vector2, rad: float, col: Color, thick: int = 1) -> void:
	var steps: int = int(rad * 1.6)
	for i in range(steps):
		var a: float = TAU * float(i) / float(steps)
		var p := Vector2(_snap(center.x + cos(a) * rad), _snap(center.y + sin(a) * rad))
		draw_rect(Rect2(p - Vector2(PX, PX) * 0.5, Vector2(PX * thick, PX * thick)), col)

func _draw() -> void:
	if _tex == null:
		_build_medal()
	var c := Vector2(_snap(size.x / 2.0), _snap(size.y / 2.0))
	var r: float = _radius()
	var side: float = GRID * PX
	# Sombra pontilhada + corpo do medalhão.
	draw_texture_rect(_tex, Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side)), false)
	# Lâmpadas do aro: correm em volta (pixels quadrados).
	var rl: float = side / 2.0 - 3.5 * PX
	for i in range(20):
		var a: float = float(i) * TAU / 20.0
		var on: bool = (i + int(_t * 5.0)) % 3 == 0
		var p := Vector2(_snap(c.x + cos(a) * rl), _snap(c.y + sin(a) * rl))
		draw_rect(Rect2(p - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), CREAM if on else GOLD_D)
	# Quando a moeda está livre pra cair, o anel central pisca de leve.
	if show_center and int(_t * 2.0) % 2 == 0:
		_pixel_ring(c, 13.0 * PX, Color(CREAM, 0.55))
	# As duas peças que podem ser chamadas, uma de cada lado do medalhão.
	var bob: float = _snap(3.0 * sin(_t * 3.0)) if clickable else 0.0
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	for i in range(2):
		var w: bool = i == 0
		var scl: float = 1.0
		if clickable:
			scl += (0.08 if pulse > 0.5 else 0.0) + (0.14 if _hover == i else 0.0)
		var pos: Vector2 = _piece_pos(w) + Vector2(0, bob if w else -bob)
		_piece(PieceSkin.team_texture(Board.WHITE if w else Board.BLACK, false), pos, PIECE_D * scl, PieceSkin.word(w),
			PieceSkin.team_color(Board.WHITE if w else Board.BLACK).lerp(CREAM, 0.35), clickable and _hover == i)

func _piece(tex: Texture2D, p: Vector2, d: float, label: String, col: Color, hot: bool = false) -> void:
	p = Vector2(_snap(p.x), _snap(p.y))
	# Sombra pontilhada embaixo.
	for i in range(8):
		var sx: float = _snap(p.x - d * 0.34 + i * d * 0.097)
		draw_rect(Rect2(Vector2(sx, _snap(p.y + d * 0.5 + 2.0)), Vector2(PX, PX)), Color(0, 0, 0, 0.35))
	if tex != null:
		draw_texture_rect(tex, Rect2(p - Vector2(d, d) * 0.5, Vector2(d, d)), false)
	_pixel_ring(p, d * 0.5 + 8.0, INK, 1)
	_pixel_ring(p, d * 0.5 + 8.0 + PX, CREAM if hot else GOLD_C, 1)
	var font: Font = ThemeDB.fallback_font
	var ty: float = p.y + d * 0.5 + 44.0
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(font, Vector2(p.x - 80, ty) + o, label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 26, INK)
	draw_string(font, Vector2(p.x - 80, ty), label, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 26, col)
