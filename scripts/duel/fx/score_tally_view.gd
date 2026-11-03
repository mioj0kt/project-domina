class_name ScoreTallyView
extends Node2D

# Contagem visual de pontos no fim da Morte Súbita: percorre o tabuleiro peça
# por peça (primeiro as do jogador, depois as do inimigo), solta um "+1" (peça
# comum) ou "+3" (Dama) sobre cada uma e soma nos placares do topo do tabuleiro.

const COMMON_VALUE: int = 1
const KING_VALUE: int = 3
const MAX_COUNT_TIME: float = 3.2   # teto da contagem inteira (muitas peças aceleram)
const HOLD_TIME: float = 1.1        # pausa com o resultado final na tela

const COL_COMMON := Color(0.94, 0.90, 0.81)
const COL_KING := Color(1.0, 0.82, 0.30)
const COL_HUMAN := Color(0.55, 0.85, 0.60)
const COL_AI := Color(0.95, 0.45, 0.45)

class Pop:
	var pos: Vector2
	var text: String
	var color: Color
	var big: bool
	var t: float = 0.0

var is_animating: bool = false
var _skip: bool = false   # clique durante a contagem: mostra o placar final de uma vez

var _pops: Array[Pop] = []
var _rings: Array = []   # [pos, t, color]
var _human_score: int = 0
var _ai_score: int = 0
var _cell: float = 64.0
var _score_anchor: Vector2 = Vector2.ZERO
var _human_bump: float = 0.0
var _ai_bump: float = 0.0
var _show_scores: bool = false

func _ready() -> void:
	z_index = 60

# Clique (ou Espaço/Enter) durante a contagem pula direto pro resultado.
func _input(event: InputEvent) -> void:
	if not is_animating or _skip:
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var keyed: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if clicked or keyed:
		_skip = true
		get_viewport().set_input_as_handled()

func _sleep(t: float) -> void:
	if not _skip:
		await get_tree().create_timer(t).timeout

func _process(delta: float) -> void:
	if not is_animating and _pops.is_empty() and _rings.is_empty():
		return
	for p in _pops:
		p.t += delta
	_pops = _pops.filter(func(p): return p.t < 0.9)
	for r in _rings:
		r[1] += delta
	_rings = _rings.filter(func(r): return r[1] < 0.5)
	_human_bump = maxf(0.0, _human_bump - delta * 4.0)
	_ai_bump = maxf(0.0, _ai_bump - delta * 4.0)
	queue_redraw()

# Devolve {"human": int, "ai": int}.
func play(board: Board, board_offset: Vector2, cell_size: float, human_team: int, ai_team: int) -> Dictionary:
	is_animating = true
	_skip = false
	_cell = cell_size
	_human_score = 0
	_ai_score = 0
	_show_scores = true
	_score_anchor = board_offset + Vector2(board.cols * cell_size * 0.5, -22.0)

	var mine: Array = []
	var theirs: Array = []
	for r in range(board.rows):
		for c in range(board.cols):
			var piece = board.grid[r][c]
			if piece == Board.EMPTY:
				continue
			if piece.owner_team == human_team:
				mine.append([Vector2i(c, r), piece])
			elif piece.owner_team == ai_team:
				theirs.append([Vector2i(c, r), piece])

	var total: int = mine.size() + theirs.size()
	var step: float = clampf(MAX_COUNT_TIME / maxf(total, 1.0), 0.05, 0.22)
	await _sleep(0.35)

	for entry in mine:
		await _count_piece(entry[0], entry[1], board_offset, true, step)
	await _sleep(0.15)
	for entry in theirs:
		await _count_piece(entry[0], entry[1], board_offset, false, step)

	# Pulou a contagem: o placar final fica só um instante na tela.
	await get_tree().create_timer(0.6 if _skip else HOLD_TIME).timeout
	_show_scores = false
	is_animating = false
	_pops.clear()
	_rings.clear()
	queue_redraw()
	return {"human": _human_score, "ai": _ai_score}

func _count_piece(cell: Vector2i, piece: BoardPiece, board_offset: Vector2, is_human: bool, step: float) -> void:
	var king: bool = piece.is_king
	var value: int = KING_VALUE if king else COMMON_VALUE
	if _skip:
		# Pulando: soma direto, sem "+1"/anéis nem espera.
		if is_human:
			_human_score += value
		else:
			_ai_score += value
		queue_redraw()
		return
	var center = board_offset + Vector2(cell.x * _cell + _cell * 0.5, cell.y * _cell + _cell * 0.5)
	var p = Pop.new()
	p.pos = center
	p.text = "+%d" % value
	p.color = COL_KING if king else COL_COMMON
	p.big = king
	_pops.append(p)
	_rings.append([center, 0.0, p.color])
	if is_human:
		_human_score += value
		_human_bump = 1.0
	else:
		_ai_score += value
		_ai_bump = 1.0
	queue_redraw()
	await _sleep(step * (1.8 if king else 1.0))

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for r in _rings:
		var k: float = r[1] / 0.5
		var col: Color = r[2]
		col.a = (1.0 - k) * 0.9
		draw_arc(r[0], _cell * (0.25 + 0.4 * k), 0.0, TAU, 28, col, 3.0)
	for p in _pops:
		var k: float = p.t / 0.9
		# sobe, com um "pulo" de escala no começo, e some no final
		var rise: float = -_cell * 0.15 - _cell * 0.55 * (1.0 - pow(1.0 - k, 2.0))
		var pulse: float = 1.0 + 0.5 * maxf(0.0, 1.0 - p.t / 0.18)
		var fs: int = int(round((_cell * (0.46 if p.big else 0.34)) * pulse))
		var alpha: float = clampf((1.0 - k) * 2.0, 0.0, 1.0)
		var pos: Vector2 = p.pos + Vector2(-_cell * 0.5, rise + fs * 0.35)
		draw_string(font, pos + Vector2(2, 2), p.text, HORIZONTAL_ALIGNMENT_CENTER, _cell, fs, Color(0.1, 0.06, 0.12, alpha))
		var c: Color = p.color
		c.a = alpha
		draw_string(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, _cell, fs, c)
	if _show_scores:
		_draw_scores(font)

func _draw_scores(font: Font) -> void:
	var w: float = 300.0
	var h: float = 46.0
	var rect = Rect2(_score_anchor - Vector2(w * 0.5, h), Vector2(w, h))
	draw_rect(rect, Color(0.14, 0.10, 0.17, 0.95))
	draw_rect(rect, Color(0.85, 0.64, 0.25), false, 2.0)
	var mid_y: float = rect.position.y + h * 0.5 + 9.0
	draw_string(font, Vector2(rect.position.x, mid_y), "x", HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(0.8, 0.7, 0.6))
	var hs: int = int(round(32.0 * (1.0 + 0.35 * _human_bump)))
	var as_: int = int(round(32.0 * (1.0 + 0.35 * _ai_bump)))
	draw_string(font, Vector2(rect.position.x, mid_y + 4), "VOCÊ  %d" % _human_score, HORIZONTAL_ALIGNMENT_CENTER, w * 0.46, hs, COL_HUMAN)
	draw_string(font, Vector2(rect.position.x + w * 0.54, mid_y + 4), "%d  INIMIGO" % _ai_score, HORIZONTAL_ALIGNMENT_CENTER, w * 0.46, as_, COL_AI)
