class_name BridgeMod
extends RefCounted

# Duelo travado EM CIMA de uma ponte de corda (nodo do desfiladeiro, mapa do Cume).
# Fica pendurado no DuelBase (`bridge`) e vale para os dois lados:
#
#  - O tabuleiro é estreito e comprido (definido no mapa).
#  - BALANÇO ANUNCIADO: um dos lados da ponte fica marcado; algumas jogadas depois a
#    ponte balança e cada peça nas DUAS colunas daquele lado desliza UMA casa na
#    diagonal, para dentro (se a casa estiver livre). A diagonal (para cima ou para
#    baixo) é sorteada junto com o lado, então o tabuleiro mostra desde o aviso onde
#    cada peça vai parar (preview()). Depois marca outro lado.

const SWAY_INTERVAL_PLIES: int = 6   # jogadas entre um balanço e o próximo (2 jogadas = 1 rodada)
const SWAY_COLS: int = 2             # quantas colunas da beirada são empurradas

var board: Board
var human_team: int = Board.WHITE
var ai_team: int = Board.BLACK
var side: int = -1                   # -1: beirada esquerda marcada; +1: direita
var gust_vy: int = 1                 # desliza para baixo (+1) ou para cima (-1)
var gust_row: int = 0                # só para o desenho da seta (>= 0 = há balanço marcado)
var _ply: int = 0

func setup(p_board: Board, p_human: int, p_ai: int) -> void:
	board = p_board
	human_team = p_human
	ai_team = p_ai
	_ply = 0
	side = 1 if randf() < 0.5 else -1
	gust_vy = 1 if randf() < 0.5 else -1
	_pick_next()

# Chamado UMA vez por jogada (de qualquer lado). Devolve os eventos para a view:
# [{"type": "sway", "side": s, "moves": [[de, para], ...]}].
func advance() -> Array:
	var events: Array = []
	_ply += 1
	if _ply % SWAY_INTERVAL_PLIES == 0:
		var s: int = side
		var moves: Array = _sway()
		events.append({"type": "sway", "side": s, "moves": moves})
		_pick_next()
	return events

func plies_to_gust() -> int:
	return SWAY_INTERVAL_PLIES - (_ply % SWAY_INTERVAL_PLIES)

func get_status_text() -> String:
	return "PONTE: BALANÇO EM %d RODADA(S)" % int(ceil(plies_to_gust() / 2.0))

# Colunas marcadas, da beirada para dentro.
func columns() -> Array:
	var out: Array = []
	for i in range(mini(SWAY_COLS, int(board.cols / 2.0))):
		out.append(i if side < 0 else board.cols - 1 - i)
	return out

func preview() -> Array:
	if board == null:
		return []
	return _simulate(side, gust_vy)

func _is_team_piece(p: BoardPiece) -> bool:
	return p != Board.EMPTY and not p.is_tree and (p.owner_team == Board.WHITE or p.owner_team == Board.BLACK)

func _free(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= board.cols or pos.y < 1 or pos.y > board.rows - 2:
		return false   # não empurra para fora nem para as fileiras de promoção
	return board.grid[pos.y][pos.x] == Board.EMPTY and not board.scorched_tiles.has(pos) and not board.fire_tiles.has(pos)

# Quem desliza e para onde, sem mexer no tabuleiro. Começa pela coluna de dentro,
# para ela abrir espaço para a da beirada.
func _simulate(s: int, dy: int) -> Array:
	var moves: Array = []
	var dx: int = 1 if s < 0 else -1
	var cols: Array = []
	for i in range(mini(SWAY_COLS, int(board.cols / 2.0)) - 1, -1, -1):
		cols.append(i if s < 0 else board.cols - 1 - i)
	var filled: Dictionary = {}
	var vacated: Dictionary = {}
	for c in cols:
		for r in range(board.rows):
			var p: BoardPiece = board.grid[r][c]
			if not _is_team_piece(p) or p.rooted_turns > 0 or p.frozen:
				continue
			var to := Vector2i(c + dx, r + dy)
			if filled.has(to):
				continue
			if not _free(to) and not vacated.has(to):
				continue
			if to.y < 1 or to.y > board.rows - 2:
				continue
			filled[to] = true
			vacated[Vector2i(c, r)] = true
			moves.append([Vector2i(c, r), to])
	return moves

func _pick_next() -> void:
	# prefere o lado/diagonal que realmente empurra peças, sem repetir o anterior
	var last := Vector2i(side, gust_vy)
	var best := Vector2i(-side, gust_vy)
	var best_score: float = -1.0
	for s in [-1, 1]:
		for dy in [-1, 1]:
			var combo := Vector2i(s, dy)
			if combo == last:
				continue
			var score: float = float(_simulate(s, dy).size()) * 2.0 + randf() * 3.0
			if score > best_score:
				best_score = score
				best = combo
	side = best.x
	gust_vy = best.y

# Balança: empurra as peças (o mesmo que preview() mostrava). Desfaz tudo se algum
# lado ficasse sem jogada.
func _sway() -> Array:
	var moves: Array = preview()
	var pieces: Array = []
	for mv in moves:
		pieces.append(board.grid[mv[0].y][mv[0].x])
	for mv in moves:
		board.grid[mv[0].y][mv[0].x] = Board.EMPTY
	for i in range(moves.size()):
		board.grid[moves[i][1].y][moves[i][1].x] = pieces[i]
	if moves.is_empty():
		return moves
	if board.get_all_valid_moves(human_team).is_empty() or board.get_all_valid_moves(ai_team).is_empty():
		for mv in moves:
			board.grid[mv[1].y][mv[1].x] = Board.EMPTY
		for i in range(moves.size()):
			board.grid[moves[i][0].y][moves[i][0].x] = pieces[i]
		return []
	return moves
