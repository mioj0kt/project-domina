class_name SandstormMod
extends RefCounted

# Duelo travado DENTRO de uma tempestade de areia (nodo coberto no mapa do Deserto).
# Fica pendurado no DuelBase (`sandstorm`) e vale para os dois lados:
#
#  - RAJADA ANUNCIADA (todo duelo na tempestade): uma fileira do tabuleiro fica marcada;
#    algumas jogadas depois a rajada passa por ela e cada peça ali desliza UMA casa na
#    diagonal, no sentido do vento (se a casa estiver livre). Depois marca outra fileira.
#  - VISÃO CURTA (só duelo FORTE na tempestade): você só enxerga as peças inimigas a até
#    FOG_RADIUS casas das suas; as casas mais longe ficam cobertas de areia.

const GUST_INTERVAL_PLIES: int = 6   # jogadas entre uma rajada e a próxima (2 jogadas = 1 rodada)
const FOG_RADIUS: int = 2

var board: Board
var human_team: int = Board.WHITE
var ai_team: int = Board.BLACK
var dir: int = 1                      # +1: vento da esquerda para a direita; -1: o contrário
var fog: bool = false
var gust_row: int = -1                # fileira marcada para a próxima rajada
var _ply: int = 0
var _last_row: int = -1

func setup(p_board: Board, p_human: int, p_ai: int, p_fog: bool) -> void:
	board = p_board
	human_team = p_human
	ai_team = p_ai
	fog = p_fog
	dir = 1 if randf() < 0.5 else -1
	_ply = 0
	_last_row = -1
	gust_row = _pick_row()

# Chamado UMA vez por jogada (de qualquer lado). Devolve os eventos para a view:
# [{"type": "gust", "row": r, "moves": [[de, para], ...]}].
func advance() -> Array:
	var events: Array = []
	_ply += 1
	if _ply % GUST_INTERVAL_PLIES == 0 and gust_row >= 0:
		var moves: Array = _blow(gust_row)
		events.append({"type": "gust", "row": gust_row, "moves": moves})
		gust_row = _pick_row()
	return events

func plies_to_gust() -> int:
	return GUST_INTERVAL_PLIES - (_ply % GUST_INTERVAL_PLIES)

func get_status_text() -> String:
	if gust_row < 0:
		return ""
	var txt: String = "RAJADA EM %d RODADA(S)" % int(ceil(plies_to_gust() / 2.0))
	if fog:
		txt += " - VISÃO CURTA"
	return txt

# Casas a mais de FOG_RADIUS de qualquer peça do jogador ficam cobertas de areia
# (a propriedade é da CASA, então a névoa não entrega onde há peças).
func fog_strength(pos: Vector2i) -> float:
	if not fog or board == null:
		return 0.0
	var best: int = 99
	for r in range(board.rows):
		for c in range(board.cols):
			var q: BoardPiece = board.grid[r][c]
			if q != Board.EMPTY and q.owner_team == human_team:
				best = mini(best, maxi(absi(r - pos.y), absi(c - pos.x)))
	if best <= FOG_RADIUS:
		return 0.0
	return clampf(0.55 + 0.15 * float(best - FOG_RADIUS - 1), 0.55, 0.85)

# --- Rajada ---------------------------------------------------------------

func _is_team_piece(p: BoardPiece) -> bool:
	return p != Board.EMPTY and not p.is_tree and (p.owner_team == Board.WHITE or p.owner_team == Board.BLACK)

# Fileira jogável (nunca as das pontas, onde se promove) com mais peças, com um pouco de
# acaso e nunca a mesma da última vez.
func _pick_row() -> int:
	if board == null:
		return -1
	var best: int = -1
	var best_score: float = -1.0
	for r in range(1, board.rows - 1):
		if r == _last_row:
			continue
		var n: int = 0
		for c in range(board.cols):
			if _is_team_piece(board.grid[r][c]):
				n += 1
		var score: float = float(n) + randf() * 2.5
		if score > best_score:
			best_score = score
			best = r
	_last_row = best
	return best

func _free(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= board.cols or pos.y < 1 or pos.y > board.rows - 2:
		return false   # não empurra para fora nem para as fileiras de promoção
	return board.grid[pos.y][pos.x] == Board.EMPTY and not board.scorched_tiles.has(pos) and not board.fire_tiles.has(pos)

# Empurra as peças da fileira uma casa na diagonal, no sentido do vento. Começa pela
# ponta de onde o vento vai (para uma não bloquear a outra). Desfaz tudo se algum lado
# ficasse sem jogada. Devolve [[de, para], ...].
func _blow(r: int) -> Array:
	var moves: Array = []
	var cols: Array = range(board.cols)
	if dir > 0:
		cols.reverse()
	var vy: int = 1 if randf() < 0.5 else -1   # a rajada desce ou sobe (a mesma para a fileira toda)
	for c in cols:
		var from := Vector2i(c, r)
		var p: BoardPiece = board.grid[r][c]
		if not _is_team_piece(p) or p.rooted_turns > 0:
			continue
		var to := Vector2i(c + dir, r + vy)
		if not _free(to):
			to = Vector2i(c + dir, r - vy)
			if not _free(to):
				continue
		board.grid[to.y][to.x] = p
		board.grid[r][c] = Board.EMPTY
		moves.append([from, to])
	if moves.is_empty():
		return moves
	if board.get_all_valid_moves(human_team).is_empty() or board.get_all_valid_moves(ai_team).is_empty():
		for i in range(moves.size() - 1, -1, -1):
			var f: Vector2i = moves[i][0]
			var t: Vector2i = moves[i][1]
			board.grid[f.y][f.x] = board.grid[t.y][t.x]
			board.grid[t.y][t.x] = Board.EMPTY
		return []
	return moves
