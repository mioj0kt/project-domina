class_name ScoreTallyView
extends Node2D

# Contagem visual de pontos no fim da Morte Súbita: percorre o tabuleiro peça
# por peça (primeiro as do jogador, depois as do inimigo), solta um "+1" (peça
# comum) ou "+3" (Dama) sobre cada uma e soma nos placares do topo do tabuleiro.

const COMMON_VALUE: int = 1
const KING_VALUE: int = 3
# Valor de uma Dama por lado (Lei Dama Dourada); o SuddenDeathManager preenche antes de play().
var human_king_value: int = KING_VALUE
var ai_king_value: int = KING_VALUE
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
var _glows: Array = []        # [pos, t, color, king]
var _h_disp: float = 0.0      # placar mostrado (sobe "rolando" até o valor real)
var _a_disp: float = 0.0
var _h_flash: float = 0.0     # brilho do placar quando soma (dourado se foi Dama)
var _a_flash: float = 0.0
var _h_flash_col: Color = Color.WHITE
var _a_flash_col: Color = Color.WHITE
var _streak: int = 0
var _result: int = 2          # 2 = ainda contando; 1 vence você; -1 inimigo; 0 empate
var _result_t: float = 0.0
var _time: float = 0.0

var _score_layer: CanvasLayer
var _score_ctrl: Control

func _ready() -> void:
	z_index = 60
	# O placar fica numa camada própria, ACIMA da mão do inimigo (85) e da HUD.
	_score_layer = CanvasLayer.new()
	_score_layer.layer = 92
	add_child(_score_layer)
	_score_ctrl = Control.new()
	_score_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_score_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_ctrl.draw.connect(func(): if _show_scores: _draw_scores(_score_ctrl))
	_score_layer.add_child(_score_ctrl)

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
	for g in _glows:
		g[1] += delta
	_glows = _glows.filter(func(g): return g[1] < (1.0 if g[3] else 0.6))
	_human_bump = maxf(0.0, _human_bump - delta * 4.0)
	_ai_bump = maxf(0.0, _ai_bump - delta * 4.0)
	_h_flash = maxf(0.0, _h_flash - delta * 2.5)
	_a_flash = maxf(0.0, _a_flash - delta * 2.5)
	_time += delta
	if _result != 2:
		_result_t += delta
	# Placar "rola" até o valor real (instantâneo ao pular).
	var spd: float = 40.0 if not _skip else 1000.0
	_h_disp = move_toward(_h_disp, float(_human_score), spd * delta)
	_a_disp = move_toward(_a_disp, float(_ai_score), spd * delta)
	queue_redraw()
	if _score_ctrl != null:
		_score_ctrl.queue_redraw()

# Devolve {"human": int, "ai": int}.
func play(board: Board, board_offset: Vector2, cell_size: float, human_team: int, ai_team: int) -> Dictionary:
	is_animating = true
	_skip = false
	_cell = cell_size
	_human_score = 0
	_ai_score = 0
	_h_disp = 0.0
	_a_disp = 0.0
	_streak = 0
	_result = 2
	_result_t = 0.0
	_glows.clear()
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

	# A contagem acelera um pouquinho a cada peça (começa mais cadenciada).
	var idx: int = 0
	_streak = 0
	for entry in mine:
		await _count_piece(entry[0], entry[1], board_offset, true, step * lerpf(1.35, 0.7, float(idx) / maxf(total - 1, 1.0)))
		idx += 1
	await _sleep(0.2)
	_streak = 0
	for entry in theirs:
		await _count_piece(entry[0], entry[1], board_offset, false, step * lerpf(1.35, 0.7, float(idx) / maxf(total - 1, 1.0)))
		idx += 1

	# Resultado: o vencedor do placar brilha, o outro apaga.
	_result = signi(_human_score - _ai_score)
	if not _skip:
		Sfx.play("placar")
	_result_t = 0.0
	await _sleep(0.15)
	if not _skip:
		var win_col: Color = COL_HUMAN if _result >= 0 else COL_AI
		Juice.sparkle(self, _score_anchor + Vector2(0, -20), 26)
		Juice.ring(self, _score_anchor + Vector2(0, -22), 90.0, win_col)
	# Pulou a contagem: o placar final fica só um instante na tela.
	await get_tree().create_timer(0.7 if _skip else HOLD_TIME + 0.4).timeout
	_show_scores = false
	is_animating = false
	_pops.clear()
	_rings.clear()
	queue_redraw()
	if _score_ctrl != null:
		_score_ctrl.queue_redraw()
	return {"human": _human_score, "ai": _ai_score}

func _count_piece(cell: Vector2i, piece: BoardPiece, board_offset: Vector2, is_human: bool, step: float) -> void:
	var king: bool = piece.is_king
	var value: int = (human_king_value if is_human else ai_king_value) if king else COMMON_VALUE
	if _skip:
		# Pulando: soma direto, sem "+1"/anéis nem espera.
		if is_human:
			_human_score += value
		else:
			_ai_score += value
		queue_redraw()
		return
	_streak += 1
	if king:
		Sfx.play("contagem_dama")
	else:
		Sfx.play("contagem", 0.0, 1.0 + 0.06 * minf(_streak, 12.0))   # sobe de tom a cada peça
	var center = board_offset + Vector2(cell.x * _cell + _cell * 0.5, cell.y * _cell + _cell * 0.5)
	var col: Color = COL_KING if king else COL_COMMON
	var p = Pop.new()
	p.pos = center
	p.text = "+%d" % value
	p.color = col
	p.big = king
	_pops.append(p)
	_rings.append([center, 0.0, col])
	_glows.append([center, 0.0, col, king])
	if king:
		# Dama: brilho forte, segundo anel, faíscas e um tranco na tela.
		_rings.append([center, -0.12, Color(1.0, 0.95, 0.7)])
		Juice.flash_square(self, center, _cell, Color(1.0, 0.9, 0.45, 0.85), 0.28)
		Juice.sparkle(self, center, 22)
		Juice.burst(self, center, COL_KING, 14, 220.0, 0.6, 5.0)
		Juice.shake(get_parent(), 5.0, 0.2)
	else:
		Juice.flash_square(self, center, _cell * 0.9, Color(1.0, 0.97, 0.88, 0.35 + 0.02 * minf(_streak, 10)), 0.12)
	var bump: float = 1.8 if king else 1.0
	if is_human:
		_human_score += value
		_human_bump = bump
		_h_flash = 1.0
		_h_flash_col = COL_KING if king else COL_HUMAN
	else:
		_ai_score += value
		_ai_bump = bump
		_a_flash = 1.0
		_a_flash_col = COL_KING if king else COL_AI
	queue_redraw()
	await _sleep(step * (2.0 if king else 1.0))

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for g in _glows:
		var life: float = 1.0 if g[3] else 0.6
		var kg: float = g[1] / life
		var gc: Color = g[2]
		var rad: float = _cell * (0.75 if g[3] else 0.55)
		for i in range(3):
			var c2: Color = gc
			c2.a = (1.0 - kg) * (0.16 + 0.05 * (2 - i)) * (1.6 if g[3] else 1.0)
			draw_circle(g[0], rad * (1.0 - 0.28 * i) * (1.0 + 0.2 * kg), c2)
		if g[3]:
			# estrela de 4 pontas girando sobre a Dama
			var sc: Color = Color(1.0, 0.95, 0.7, (1.0 - kg))
			var arm: float = _cell * (0.35 + 0.35 * sin(minf(kg * 3.0, 1.0) * PI))
			var ang: float = g[1] * 2.5
			for q in range(2):
				var d := Vector2.from_angle(ang + q * PI * 0.5) * arm
				draw_line(g[0] - d, g[0] + d, sc, 3.0)
	for r in _rings:
		if r[1] < 0.0:
			continue
		var k: float = r[1] / 0.5
		var col: Color = r[2]
		col.a = (1.0 - k) * 0.9
		draw_arc(r[0], _cell * (0.25 + 0.4 * k), 0.0, TAU, 28, col, 3.0)
	for p in _pops:
		var k: float = p.t / 0.9
		# sobe, com um "pulo" de escala no começo, e some no final
		var rise: float = -_cell * 0.15 - _cell * 0.55 * (1.0 - pow(1.0 - k, 2.0))
		var pulse: float = 1.0 + 0.5 * maxf(0.0, 1.0 - p.t / 0.18)
		var fs: int = int(round((_cell * (0.62 if p.big else 0.34)) * pulse))
		var alpha: float = clampf((1.0 - k) * 2.0, 0.0, 1.0)
		var pos: Vector2 = p.pos + Vector2(-_cell * 0.5, rise + fs * 0.35)
		draw_string(font, pos + Vector2(2, 2), p.text, HORIZONTAL_ALIGNMENT_CENTER, _cell, fs, Color(0.1, 0.06, 0.12, alpha))
		var c: Color = p.color
		c.a = alpha
		draw_string(font, pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, _cell, fs, c)

func _draw_scores(c: CanvasItem) -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = 340.0
	var h: float = 52.0
	var rect = Rect2(_score_anchor - Vector2(w * 0.5, h), Vector2(w, h))
	var mid: float = rect.position.y + h * 0.5 + 10.0
	# fundo, com brilho do lado que acabou de somar
	c.draw_rect(rect, Color(0.14, 0.10, 0.17, 0.97))
	var lh: float = _h_flash * 0.35
	var la: float = _a_flash * 0.35
	if lh > 0.0:
		c.draw_rect(Rect2(rect.position, Vector2(w * 0.5, h)), Color(_h_flash_col.r, _h_flash_col.g, _h_flash_col.b, lh))
	if la > 0.0:
		c.draw_rect(Rect2(rect.position + Vector2(w * 0.5, 0), Vector2(w * 0.5, h)), Color(_a_flash_col.r, _a_flash_col.g, _a_flash_col.b, la))
	var border: Color = Color(0.85, 0.64, 0.25)
	if _result != 2:
		border = border.lerp(Color(1.0, 0.95, 0.6), 0.5 + 0.5 * sin(_result_t * 8.0))
	c.draw_rect(rect, border, false, 3.0)
	PixelRenderer.draw_pixel_corners(c, rect, border.lightened(0.2), 9.0, 3.0)
	c.draw_string(font, Vector2(rect.position.x, mid), "x", HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0.8, 0.7, 0.6))

	var hs_base: float = 34.0
	var hs: int = int(round(hs_base * (1.0 + 0.3 * _human_bump)))
	var as_: int = int(round(hs_base * (1.0 + 0.3 * _ai_bump)))
	var hcol: Color = COL_HUMAN.lerp(_h_flash_col, _h_flash) if _h_flash > 0.0 else COL_HUMAN
	var acol: Color = COL_AI.lerp(_a_flash_col, _a_flash) if _a_flash > 0.0 else COL_AI
	if _result != 2:
		var grow: float = 1.0 + 0.25 * minf(_result_t * 4.0, 1.0)
		if _result >= 0:
			hs = int(round(hs_base * grow)); hcol = COL_KING
		if _result <= 0:
			as_ = int(round(hs_base * grow)); acol = COL_KING
		if _result == 1:
			acol = acol.darkened(0.45)
		elif _result == -1:
			hcol = hcol.darkened(0.45)
	var hn: int = int(round(_h_disp))
	var an: int = int(round(_a_disp))
	c.draw_string(font, Vector2(rect.position.x, mid + 4), "VOCÊ  %d" % hn, HORIZONTAL_ALIGNMENT_CENTER, w * 0.46, hs, hcol)
	c.draw_string(font, Vector2(rect.position.x + w * 0.54, mid + 4), "%d  INIMIGO" % an, HORIZONTAL_ALIGNMENT_CENTER, w * 0.46, as_, acol)
