class_name TurnIndicatorView
extends Node2D

## Indicador de vez em pixel art: uma plaquinha ao lado do tabuleiro com dois
## encaixes, o do adversário em cima e o seu embaixo, ligados por um trilho.
## O encaixe de quem joga fica aceso (moldura dourada com cantos em degrau e
## brilhinhos piscando); o outro fica apagado. Nada se
## move: a troca é só a luz passando de um encaixe para o outro.

const FADE_SPEED: float = 5.0
const SETTLE_SECS: float = 0.18
const U: float = 3.0                         # 1 "pixel" da arte = 3 px de tela

const C_OUTLINE := Color8(31, 22, 29)        # #1f161d
const C_PLATE := Color8(46, 34, 44)          # fundo da placa
const C_PLATE_HI := Color8(74, 58, 70)       # brilho da placa
const C_DIM := Color8(90, 72, 85)            # moldura apagada
const C_GOLD := Color8(217, 162, 58)         # #d9a23a
const C_GOLD_HI := Color8(240, 210, 122)     # #f0d27a
const C_GOLD_LO := Color8(150, 96, 28)

var host
var _alpha: float = 0.0
var _light: float = 1.0                      # 1 = seu encaixe aceso, 0 = do adversário
var _shown_mine: bool = true
var _pending_t: float = 0.0
var _started: bool = false
var _t: float = 0.0

func setup(p_host) -> void:
	host = p_host
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if host == null or host.board == null:
		return
	_t += delta
	var vis: bool = not host.is_starting_match
	_alpha = move_toward(_alpha, 1.0 if vis else 0.0, delta * 3.0)
	if vis:
		var mine: bool = host.current_turn == host.human_team
		if not _started:
			_started = true
			_shown_mine = mine
			_light = 1.0 if mine else 0.0
		elif mine != _shown_mine:
			_pending_t += delta
			if _pending_t >= SETTLE_SECS:
				_shown_mine = mine
				_pending_t = 0.0
		else:
			_pending_t = 0.0
	_light = move_toward(_light, 1.0 if _shown_mine else 0.0, delta * FADE_SPEED)
	queue_redraw()

func _r(x: float) -> float:
	return roundf(x / U) * U

func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(_r(x), _r(y), _r(w), _r(h)), c)

# Moldura quadrada com os cantos em degrau (sem curvas: tudo em blocos de U).
func _frame(cx: float, cy: float, size: float, col: Color, hi: Color, lo: Color) -> void:
	var s: float = _r(size)
	var x: float = _r(cx - s / 2.0)
	var y: float = _r(cy - s / 2.0)
	var t: float = U
	# contorno escuro por fora
	_px(x + U * 2, y - U, s - U * 4, U, C_OUTLINE)
	_px(x + U * 2, y + s, s - U * 4, U, C_OUTLINE)
	_px(x - U, y + U * 2, U, s - U * 4, C_OUTLINE)
	_px(x + s, y + U * 2, U, s - U * 4, C_OUTLINE)
	_px(x + U, y, U, U, C_OUTLINE)
	_px(x + s - U * 2, y, U, U, C_OUTLINE)
	_px(x, y + U, U, U, C_OUTLINE)
	_px(x + s - U, y + U, U, U, C_OUTLINE)
	_px(x + U, y + s - U, U, U, C_OUTLINE)
	_px(x + s - U * 2, y + s - U, U, U, C_OUTLINE)
	_px(x, y + s - U * 2, U, U, C_OUTLINE)
	_px(x + s - U, y + s - U * 2, U, U, C_OUTLINE)
	# miolo
	_px(x + U, y + U, s - U * 2, s - U * 2, C_PLATE)
	# moldura: claro em cima/esquerda, escuro embaixo/direita
	_px(x + U * 2, y, s - U * 4, t, hi)
	_px(x, y + U * 2, t, s - U * 4, hi)
	_px(x + U * 2, y + s - t, s - U * 4, t, lo)
	_px(x + s - t, y + U * 2, t, s - U * 4, lo)
	_px(x + U, y + U, U, U, hi)
	_px(x + s - U * 2, y + U, U, U, col)
	_px(x + U, y + s - U * 2, U, U, col)
	_px(x + s - U * 2, y + s - U * 2, U, U, lo)
	# fio interno da cor principal, nos quatro lados (o miolo fica simétrico e
	# a peça, no meio dele, fica centralizada de verdade)
	_px(x + U * 2, y + U, s - U * 4, U, col)
	_px(x + U, y + U * 2, U, s - U * 4, col)
	_px(x + U * 2, y + s - U * 2, s - U * 4, U, col)
	_px(x + s - U * 2, y + U * 2, U, s - U * 4, col)

# Setinha em degraus apontando para a esquerda (para o tabuleiro).
func _arrow(tip_x: float, cy: float, col: Color, hi: Color) -> void:
	for i in range(4):
		var h: float = U * float(1 + i * 2)
		_px(tip_x + U * float(i), cy - h / 2.0, U, h, C_OUTLINE)
	for i in range(3):
		var h2: float = U * float(1 + i * 2)
		_px(tip_x + U * float(i + 1), cy - h2 / 2.0, U, h2, col if i > 0 else hi)

func _draw() -> void:
	if _alpha <= 0.01:
		return
	modulate.a = _alpha
	var cs: float = host.cell_size
	# Peça no tamanho nativo do sprite (32 px, sem ampliar quebrado: os pixels
	# ficam todos iguais) e encaixe com um número PAR de blocos de U, para o
	# meio do encaixe cair exatamente no centro da peça.
	var piece: float = 32.0
	var box: float = U * 18.0
	# no vão entre a moldura do tabuleiro e o painel de Leis
	var x: float = _r(host.board_offset.x + float(host.board.cols) * cs + 81.0)
	var y_top: float = _r(host.board_offset.y + cs * 0.5)
	var y_bot: float = _r(host.board_offset.y + float(host.board.rows) * cs - cs * 0.5)
	# trilho: corrente de elos entre os dois encaixes
	var yy: float = y_top + box / 2.0 + U * 2.0
	var k: int = 0
	while yy < y_bot - box / 2.0 - U * 2.0:
		_px(x - U, yy, U * 2.0, U * 2.0, C_OUTLINE)
		_px(x - U, yy, U, U, C_DIM if k % 2 == 0 else C_PLATE_HI)
		yy += U * 4.0
		k += 1
	var enemy_team: int = Board.BLACK if host.human_team == Board.WHITE else Board.WHITE
	_slot(x, y_top, box, piece, enemy_team, 1.0 - _light)
	_slot(x, y_bot, box, piece, host.human_team, _light)

func _slot(cx: float, cy: float, box: float, piece: float, team: int, on: float) -> void:
	var lit: bool = on > 0.5
	var col: Color = C_DIM.lerp(C_GOLD, on)
	var hi: Color = C_PLATE_HI.lerp(C_GOLD_HI, on)
	var lo: Color = C_OUTLINE.lerp(C_GOLD_LO, on)
	_frame(cx, cy, box, col, hi, lo)
	var tex: Texture2D = PieceSkin.team_texture(team, false)
	if tex != null:
		var dim: float = lerpf(0.42, 1.0, on)
		var ts: Vector2 = tex.get_size() * (piece / 32.0)
		var r := Rect2((Vector2(cx, cy) - ts / 2.0).round(), ts)
		draw_texture_rect(tex, r, false, Color(dim, dim, dim, lerpf(0.6, 1.0, on)))
	# brilhinhos nos cantos do encaixe aceso (piscam em degraus, sem suavizar)
	if lit:
		var blink: bool = int(_t * 2.0) % 2 == 0
		var s: float = box / 2.0 + U * 3.0
		var c2: Color = C_GOLD_HI if blink else C_GOLD
		_px(cx - s, cy - s, U, U, c2)
		_px(cx + s - U, cy + s - U, U, U, c2)
		_px(cx + s - U, cy - s, U, U, C_GOLD if blink else C_GOLD_HI)
		_px(cx - s, cy + s - U, U, U, C_GOLD if blink else C_GOLD_HI)
