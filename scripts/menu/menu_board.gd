class_name MenuBoard
extends Control
## Menu principal como uma ilha flutuante igual às do fundo: um tabuleiro
## (casas creme/ameixa do tutorial, rocha com borda dourada embaixo) em que cada
## linha é uma opção. As 3 colunas da esquerda são casas normais, por onde a
## peça do jogador anda pulando nas diagonais; o resto da linha é uma placa
## creme cravada no tabuleiro, com o nome da opção e um encaixe redondo na ponta.
## Mouse/foco numa placa: a peça anda até a linha dela. Clique: a peça pula para
## dentro do encaixe da placa e só então a ação roda.

signal arrived(row: int)
## A linha de destino mudou.
signal target_changed(row: int)

const PIX: float = 2.0                      # escala do pixel art (32 px de arte por casa)
const CELL: float = 32.0 * PIX              # 64 px
const WALK_COLS: int = 2                    # casas por onde a peça anda
const SLAB_COLS: int = 5                    # casa do encaixe + placa com o nome
const COLS: int = WALK_COLS + SLAB_COLS
const SKIN := BoardSkin.SKIN_TUTORIAL
const HOP_SEC: float = 0.16
const HOP_HEIGHT: float = 16.0
const BASE_DIR := "res://assets/sprites/mapa/ilha/tutorial/"
const FONT := preload("res://assets/fonts/m5x7.ttf")

const FX_SEC: float = 0.35
const C_OUT := Color("1f161d")
const C_TRAY := Color("2c2129")
const C_CREAM_HI := Color("f4ecd6")
const C_CREAM := Color("e4d9bc")
const C_CREAM_SH := Color("b9a983")
const C_PLUM := Color("3a2d37")
const C_GOLD := Color("f0d27a")
const C_GOLD_SH := Color("c99a3a")

var rows: int = 0
var _buttons: Array[Button] = []
var _hover_row: int = -1
var _cell := Vector2i(1, 0)                 # (coluna, linha) da peça; coluna WALK_COLS = encaixe da placa
var _pos := Vector2.ZERO                    # centro desenhado da peça (sem o pulo)
var _lift: float = 0.0
var _squash: float = 0.0
var _target_row: int = 0
var _walking: bool = false
var _busy: bool = false
var _rush: bool = false                     # 2º clique: a peça se teletransporta
var _acted: bool = false                    # a ação do clique já rodou
var _tw: Tween = null                       # pulo em andamento
var _fx: Array = []                         # lufadas do teletransporte: [posição, idade]
var _glow_row: int = 0
var _t: float = 0.0
var _frame: float = 0.0
var _base: Texture2D = null
var _new_rows: Dictionary = {}              # linhas com o selo "NOVO"
var _socket_tex: Dictionary = {}            # estado -> textura do encaixe


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = roundf(BoardSkin.get_frame_px(CELL, SKIN))


## Acrescenta uma opção (uma linha do tabuleiro). Devolve o botão invisível
## que cobre a placa (para tooltip, foco, etc.).
func add_option(text: String, action: Callable, disabled: bool = false) -> Button:
	var r: int = rows
	rows += 1
	custom_minimum_size = Vector2(COLS * CELL + _frame * 2.0, rows * CELL + _frame * 2.0)
	var b := Button.new()
	b.set_meta("no_piece", true)   # o tabuleiro já tem a peça dele (MenuPieceCursor ignora)
	b.text = text
	b.disabled = disabled
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 48)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0, 0, 0, 0))   # o texto é desenhado pela placa
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	var rect := _option_rect(r)
	b.position = rect.position
	b.size = rect.size
	add_child(b)
	_buttons.append(b)
	b.mouse_entered.connect(func() -> void:
		_hover_row = r
		if not b.disabled:
			go_to_row(r))
	b.mouse_exited.connect(func() -> void:
		if _hover_row == r:
			_hover_row = -1)
	b.focus_entered.connect(func() -> void: go_to_row(r))
	b.pressed.connect(func() -> void: press_row(r, action))
	return b


func _ready() -> void:
	_cell = Vector2i(_near_col(0), 0)
	_pos = _cell_center(_cell)
	_base = _make_base(int(round(custom_minimum_size.x / PIX)))


func _process(delta: float) -> void:
	_t += delta
	for f in _fx:
		f[1] += delta
	_fx = _fx.filter(func(f): return f[1] < FX_SEC)
	queue_redraw()


## Altura (px) da rocha pendurada embaixo do tabuleiro.
func base_height() -> float:
	return 96.0 * PIX


## Aviso "!" pulando na ponta da placa da linha r (ex.: Grimório com Coroas para gastar).
var _alerts: Dictionary = {}

func set_alert(r: int, on: bool = true) -> void:
	if on and not _alerts.has(r):
		var b := AlertBadge.new()
		add_child(b)
		var s := _slab_rect(r)
		b.position = Vector2(s.end.x - b.size.x - PIX * 6.0, s.position.y + (s.size.y - b.size.y) * 0.5 - PIX).round()
		_alerts[r] = b
	elif not on and _alerts.has(r):
		_alerts[r].queue_free()
		_alerts.erase(r)


## Marca a opção da linha r com um selo dourado "NOVO" na ponta da placa.
func set_new(r: int, on: bool = true) -> void:
	_new_rows[r] = on


# Placa com o nome: da 2ª casa da área das opções até o fim da linha (a 1ª
# casa é o encaixe da peça, cavado na bandeja).
func _slab_rect(r: int) -> Rect2:
	var x0: float = _frame + (WALK_COLS + 1) * CELL
	return Rect2(Vector2(x0, _frame + r * CELL + PIX * 2.0), Vector2((SLAB_COLS - 1) * CELL - PIX * 2.0, CELL - PIX * 4.0))


# Área clicável da opção: encaixe + placa.
func _option_rect(r: int) -> Rect2:
	var x0: float = _frame + WALK_COLS * CELL
	return Rect2(Vector2(x0, _frame + r * CELL), Vector2(SLAB_COLS * CELL, CELL))


func _socket_center(r: int) -> Vector2:
	return Vector2(_frame + (WALK_COLS + 0.5) * CELL, _frame + (r + 0.5) * CELL)


# Casa escura mais à direita do caminho na linha r. Escura = (r+c) ímpar.
func _near_col(r: int) -> int:
	for c in range(WALK_COLS - 1, -1, -1):
		if (r + c) % 2 == 1:
			return c
	return 0


func _cell_center(cell: Vector2i) -> Vector2:
	if cell.x >= WALK_COLS:
		return _socket_center(cell.y)
	return Vector2(_frame + (cell.x + 0.5) * CELL, _frame + (cell.y + 0.5) * CELL)


func _set_glow(r: int) -> void:
	if _glow_row != r:
		_glow_row = r
		target_changed.emit(r)


## Manda a peça andar até a linha r.
func go_to_row(r: int) -> void:
	if _busy:
		return
	_target_row = clampi(r, 0, rows - 1)
	_set_glow(_target_row)
	if not _walking:
		_walk()


## Clique: anda até a linha, pula para o encaixe da placa e chama `action`.
## Se a cena continuar (ex.: abriu uma janela por cima), a peça volta ao caminho.
## Clicar de novo enquanto a peça ainda está a caminho (duplo clique) faz ela
## se teletransportar direto para o encaixe, sem esperar a caminhada.
func press_row(r: int, action: Callable) -> void:
	if _busy:
		if not _acted and not _rush:
			_teleport()
		return
	_target_row = clampi(r, 0, rows - 1)
	_set_glow(_target_row)
	_busy = true
	_acted = false
	_rush = false
	var already: bool = not _walking and _cell == Vector2i(WALK_COLS, _target_row)
	if _walking:
		await arrived
	elif _cell.y != _target_row:
		_walk()
		await arrived
	# já está no encaixe desta opção: só um pulinho no lugar
	await _hop_to(Vector2i(WALK_COLS, _target_row), 1.0 if already else 1.5)
	if _rush:
		_fx.append([_pos, 0.0])
		Sfx.play("salto")
	_acted = true
	_rush = false
	if action.is_valid():
		action.call()
	# A peça fica no encaixe; só sai dele quando o mouse for para outra opção.
	_busy = false


func _walk() -> void:
	_walking = true
	# saindo do encaixe (indo para outra opção): volta primeiro para a casa do
	# caminho da mesma linha
	if _cell.x >= WALK_COLS and _cell.y != _target_row:
		await _hop_to(Vector2i(_near_col(_cell.y), _cell.y))
	while _cell.y != _target_row:
		var dr: int = 1 if _target_row > _cell.y else -1
		var want: int = _near_col(_target_row)
		var dc: int = 1 if want > _cell.x else -1
		if want == _cell.x:
			dc = 1 if _cell.x + 1 < WALK_COLS else -1
		var nc: int = _cell.x + dc
		if nc < 0 or nc >= WALK_COLS:
			nc = _cell.x - dc
		await _hop_to(Vector2i(nc, _cell.y + dr))
	_walking = false
	arrived.emit(_cell.y)


# Some de onde está (lufada dourada), termina na hora o pulo em andamento e os
# próximos pulos do caminho acontecem instantâneos (ver _hop_to).
func _teleport() -> void:
	_rush = true
	_fx.append([_pos - Vector2(0, _lift), 0.0])
	if _tw != null and _tw.is_valid() and _tw.is_running():
		_tw.custom_step(10.0)


func _hop_to(cell: Vector2i, height_mul: float = 1.0) -> void:
	var to: Vector2 = _cell_center(cell)
	if _rush:
		_cell = cell
		_pos = to
		_lift = 0.0
		_squash = 0.0
		return
	var from: Vector2 = _pos
	var dur: float = HOP_SEC * (1.0 if height_mul <= 1.0 else 1.5)
	_tw = create_tween()
	_tw.tween_method(func(k: float) -> void:
		_pos = from.lerp(to, k)
		_lift = sin(k * PI) * HOP_HEIGHT * height_mul
	, 0.0, 1.0, dur)
	await _tw.finished
	_cell = cell
	_pos = to
	_lift = 0.0
	if _rush:
		return
	Sfx.play("salto")
	_tw = create_tween()
	_tw.tween_method(func(k: float) -> void: _squash = sin(k * PI), 0.0, 1.0, 0.09)
	await _tw.finished
	_squash = 0.0


# Rocha da ilha na largura do tabuleiro (px de arte), com a arte da base do
# tutorial: ponta esquerda + faixas + ponta direita.
static func _make_base(w: int) -> Texture2D:
	var lp := BASE_DIR + "base_ponta_esq.png"
	var rp := BASE_DIR + "base_ponta_dir.png"
	if not (ResourceLoader.exists(lp) and ResourceLoader.exists(rp)):
		return null
	var L: Image = (load(lp) as Texture2D).get_image()
	var R: Image = (load(rp) as Texture2D).get_image()
	L.convert(Image.FORMAT_RGBA8)
	R.convert(Image.FORMAT_RGBA8)
	var h: int = L.get_height()
	var cw: int = L.get_width()
	w = maxi(w, cw * 2)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var x: int = cw
	var i: int = 0
	while x < w - cw:
		var sp := BASE_DIR + "base_faixa_%d.png" % (i % 4 + 1)
		var S: Image = (load(sp) as Texture2D).get_image()
		S.convert(Image.FORMAT_RGBA8)
		var take: int = mini(S.get_width(), w - cw - x)
		img.blit_rect(S, Rect2i(0, 0, take, h), Vector2i(x, 0))
		x += take
		i += 1
	img.blit_rect(L, Rect2i(0, 0, cw, h), Vector2i(0, 0))
	img.blit_rect(R, Rect2i(0, 0, cw, h), Vector2i(w - cw, 0))
	return ImageTexture.create_from_image(img)


# Encaixe da peça: um buraco com o MESMO contorno do sprite da peça (feito a
# partir do alfa dela), cavado na bandeja. Parede de cima na sombra, parede de
# baixo pegando luz, contorno escuro e uma borda (creme / dourada na opção
# ativa / cinza se bloqueada) em volta. A peça pousa encaixada nele.
func _socket(state: String) -> Texture2D:
	if _socket_tex.has(state):
		return _socket_tex[state]
	var src: Texture2D = PieceSkin.player_texture()
	if src == null:
		return null
	var im: Image = src.get_image()
	im.convert(Image.FORMAT_RGBA8)
	var sw: int = im.get_width()
	var sh: int = im.get_height()
	var pad: int = 2
	var w: int = sw + pad * 2
	var h: int = sh + pad * 2
	var m := PackedByteArray()
	m.resize(w * h)
	for y in sh:
		for x in sw:
			if im.get_pixel(x, y).a > 0.5:
				m[(y + pad) * w + x + pad] = 1
	var rim: Color = {"on": C_GOLD, "dis": Color("5c535e")}.get(state, C_CREAM_SH)
	var rim_hi: Color = {"on": Color("f8e6a0"), "dis": Color("6a616c")}.get(state, C_CREAM)
	var floor_c := Color("2c2129")
	var shadow_c := Color("170f16")
	var lit_c := Color("4a3a46") if state != "dis" else Color("3a3340")
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var at := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and m[y * w + x] == 1
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			if at.call(x, y):
				if not at.call(x, y - 1) or not at.call(x, y - 2) or not at.call(x, y - 3):
					c = shadow_c
				elif not at.call(x, y + 1):
					c = lit_c
				elif not at.call(x - 1, y) or not at.call(x - 2, y):
					c = shadow_c.lerp(floor_c, 0.5)
				else:
					c = floor_c
			elif at.call(x - 1, y) or at.call(x + 1, y) or at.call(x, y - 1) or at.call(x, y + 1):
				c = C_OUT
			else:
				var near := false
				for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					if at.call(x + d.x, y + d.y):
						near = true
						break
				if near:
					c = rim_hi if y * 2 < h else rim
			out.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(out)
	_socket_tex[state] = tex
	return tex


func _r(p: Vector2, s: Vector2, c: Color) -> void:
	draw_rect(Rect2(p, s), c)


func _draw() -> void:
	var off := Vector2(_frame, _frame)
	var board_h: float = rows * CELL + _frame * 2.0
	var u: float = PIX

	# Rocha da ilha (atrás, logo abaixo do tabuleiro), centrada.
	if _base != null:
		var bw: float = _base.get_width() * u
		draw_texture_rect(_base, Rect2(Vector2(roundf((size.x - bw) * 0.5 / u) * u, board_h - u * 2.0), _base.get_size() * u), false)

	BoardSkin.draw_frame(self, off, rows, COLS, CELL, Color.WHITE, SKIN)
	BoardSkin.draw_tiles(self, off, rows, WALK_COLS, CELL, Color.WHITE, Color.WHITE, SKIN)
	# Bandeja escura onde as placas ficam cravadas.
	_r(off + Vector2(WALK_COLS * CELL, 0), Vector2(SLAB_COLS * CELL, rows * CELL), C_TRAY)
	_r(off + Vector2(WALK_COLS * CELL, 0), Vector2(u, rows * CELL), C_OUT)

	for r in rows:
		_draw_slab(r)

	# Casa de destino no caminho: cantos dourados pulsando.
	var gc := Vector2i(_near_col(_glow_row), _glow_row)
	var gp := off + Vector2(gc) * CELL
	var a: float = 0.6 + 0.3 * sin(_t * 4.0)
	var col := Color(C_GOLD, a)
	var L: float = u * 6.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = gp + corner * (CELL - u) + Vector2(u, u) * (Vector2.ONE - corner * 2.0)
		var sx: float = -1.0 if corner.x > 0 else 1.0
		var sy: float = -1.0 if corner.y > 0 else 1.0
		_r(Vector2(minf(p.x, p.x + sx * L), p.y), Vector2(L, u), col)
		_r(Vector2(p.x, minf(p.y, p.y + sy * L)), Vector2(u, L), col)

	# Peça: sombra no chão + sprite (mesmo pixel do tabuleiro).
	var tex: Texture2D = PieceSkin.player_texture()
	var base: Vector2 = _pos.round()
	var air: float = clampf(_lift / HOP_HEIGHT, 0.0, 1.5)
	var sh_w: float = CELL * 0.36 * (1.0 - 0.25 * air)
	if _lift > 0.5:
		draw_set_transform(base + Vector2(0, CELL * 0.30), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, sh_w, Color(0, 0, 0, 0.35))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if tex != null:
		var sz := Vector2(tex.get_width(), tex.get_height()) * u
		sz = Vector2(sz.x * (1.0 + 0.10 * _squash), sz.y * (1.0 - 0.12 * _squash))
		var c := base - Vector2(0, roundf(_lift / u) * u)
		draw_texture_rect(tex, Rect2((c - sz * 0.5 + Vector2(0, sz.y * 0.06 * _squash)).round(), sz.round()), false)
	# Lufadas do teletransporte: anel de pixels dourados abrindo e 8 faíscas.
	for f in _fx:
		var k: float = f[1] / FX_SEC
		var fc := Color(C_GOLD, 1.0 - k)
		var rad: float = CELL * (0.35 + 0.5 * k)
		for i in 16:
			var ang: float = TAU * i / 16.0
			var q: Vector2 = f[0] + Vector2(cos(ang), sin(ang)) * rad
			_r((q / u).floor() * u, Vector2(u * 2.0, u * 2.0), fc)
		for i in 8:
			var ang2: float = TAU * (i + 0.5) / 8.0
			var q2: Vector2 = f[0] + Vector2(cos(ang2), sin(ang2)) * rad * 0.6 - Vector2(0, CELL * 0.3 * k)
			_r((q2 / u).floor() * u, Vector2(u * 2.0, u * 2.0), Color(1, 1, 1, 1.0 - k))


# Placa da opção, no mesmo estilo dos painéis do jogo: corpo ameixa em faixas,
# filete creme por dentro do contorno, espessura escura embaixo, um encaixe
# redondo na ponta esquerda (onde a peça pousa no clique) e o nome em creme.
# A opção ativa acende: corpo mais claro, filete e nome dourados.
func _draw_slab(r: int) -> void:
	var u: float = PIX
	var s := _slab_rect(r)
	var p := s.position
	var w := s.size.x
	var h := s.size.y
	var b: Button = _buttons[r]
	var dis: bool = b.disabled
	var on: bool = r == _glow_row and not dis
	var hover: bool = r == _hover_row and not dis and not on
	var bands: Array = [Color("5a4855"), Color("4a3a46"), Color("43343f")]
	var line: Color = Color("8f7f5c")
	var line_hi: Color = Color("b9a983")
	if on:
		bands = [Color("6e5868"), Color("5c4857"), Color("51404c")]
		var a: float = 0.8 + 0.2 * sin(_t * 4.0)
		line = Color(C_GOLD_SH, 1.0).lerp(C_GOLD, a)
		line_hi = C_GOLD
	elif hover:
		bands = [Color("63505e"), Color("52414e"), Color("4a3a46")]
		line_hi = C_CREAM
	elif dis:
		bands = [Color("3e3540"), Color("362e38"), Color("312a33")]
		line = Color("4f4650")
		line_hi = Color("5c535e")
	# contorno com cantos cortados
	_r(p + Vector2(u, 0), Vector2(w - u * 2.0, h), C_OUT)
	_r(p + Vector2(0, u), Vector2(w, h - u * 2.0), C_OUT)
	# espessura embaixo
	_r(p + Vector2(u, h - u * 4.0), Vector2(w - u * 2.0, u * 3.0), Color("2a2029"))
	# corpo em faixas
	var body_h: float = h - u * 5.0
	var y: float = p.y + u
	var cuts: Array = [0.0, 0.3, 0.7, 1.0]
	for i in 3:
		var y0: float = p.y + u + roundf(body_h * cuts[i] / u) * u
		var y1: float = p.y + u + roundf(body_h * cuts[i + 1] / u) * u
		_r(Vector2(p.x + u, y0), Vector2(w - u * 2.0, y1 - y0), bands[i])
	# filete (luz em cima e na esquerda)
	_r(p + Vector2(u * 2.0, u * 2.0), Vector2(w - u * 4.0, u), line_hi)
	_r(p + Vector2(u * 2.0, u * 2.0), Vector2(u, body_h - u * 2.0), line_hi)
	_r(p + Vector2(u * 2.0, u + body_h - u * 2.0), Vector2(w - u * 4.0, u), line)
	_r(p + Vector2(w - u * 3.0, u * 2.0), Vector2(u, body_h - u * 2.0), line)
	# encaixe da peça (na casa à esquerda da placa)
	var stex := _socket("on" if on else ("dis" if dis else "idle"))
	if stex != null:
		var sc := _socket_center(r)
		var ssz := stex.get_size() * u
		draw_texture_rect(stex, Rect2((sc - ssz * 0.5).round(), ssz), false)
	# nome
	var fs: int = 48
	var txt: String = b.text
	var tx: float = p.x + u * 7.0
	var ty: float = p.y + u + body_h * 0.5 + (FONT.get_ascent(fs) - FONT.get_descent(fs)) * 0.5 - u
	var tc: Color = C_CREAM
	if on:
		tc = Color("f8e6a0")
	elif dis:
		tc = Color("6a616c")
	draw_string(FONT, Vector2(roundf(tx), roundf(ty) + u * 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_OUT)
	draw_string(FONT, Vector2(roundf(tx), roundf(ty)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	if _new_rows.get(r, false) and not dis:
		var nfs: int = 24
		var nt := "NOVO"
		var nw: float = FONT.get_string_size(nt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		var bw: float = roundf((nw + u * 8.0) / u) * u
		var bh: float = u * 11.0
		var bp := Vector2(p.x + w - bw - u * 5.0, p.y + roundf((body_h - bh) * 0.5 / u) * u + u)
		var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
		_r(bp + Vector2(u, 0), Vector2(bw - u * 2.0, bh), C_OUT)
		_r(bp + Vector2(0, u), Vector2(bw, bh - u * 2.0), C_OUT)
		_r(bp + Vector2(u, u), Vector2(bw - u * 2.0, bh - u * 2.0), C_GOLD_SH.lerp(C_GOLD, pulse))
		var nty: float = bp.y + bh * 0.5 + (FONT.get_ascent(nfs) - FONT.get_descent(nfs)) * 0.5
		draw_string(FONT, Vector2(roundf(bp.x + (bw - nw) * 0.5), roundf(nty)), nt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, C_OUT)
