class_name CheckersAI
extends RefCounted

# exclude_from: peça que NÃO pode ser movida (Contra-Ataque: o movimento extra
# tem que ser de OUTRA peça). (-1,-1) = sem restrição.
# Últimas jogadas da IA neste duelo (de/para). Usado para não ficar repetindo
# casas (ir e voltar) esperando o jogador agir.
const HISTORY_LEN := 4
static var _history: Array = []
static var _last_board_id: int = 0

# opts (ver AiDifficulty): "depth", "tolerance", "blunder". Sem opts: força total.
static func get_best_move(board: Board, depth: int = 4, ai_team: int = Board.BLACK, exclude_from: Vector2i = Vector2i(-1, -1), opts: Dictionary = {}) -> Dictionary:
	var moves = board.get_all_valid_moves(ai_team)
	if exclude_from.x >= 0:
		moves = moves.filter(func(m): return m["from"] != exclude_from)

	if moves.size() == 0:
		return {}

	var bid: int = board.get_instance_id()
	if bid != _last_board_id:
		_last_board_id = bid
		_history = []

	var scored: Array = []
	var best_score: float = -INF
	for move in moves:
		var sim_board = board.clone()
		sim_board.make_move(move)

		var score: float = minimax(sim_board, depth - 1, -INF, INF, false, ai_team)
		# Árvore é um avanço grátis: desempata a favor de derrubá-la.
		if move.get("optional", false):
			score += 0.5
		# Movimento extra de carta (Investida Heróica): aproveitar a distância toda.
		if not move.get("is_capture", false):
			var dist: int = maxi(absi(move["to"].x - move["from"].x), absi(move["to"].y - move["from"].y))
			if dist >= 2:
				score += 1.0
		# Anti-espera: não vale voltar para uma casa que a IA acabou de deixar
		# (ir e voltar). Só pesa em jogadas sem captura.
		if not move.get("is_capture", false) and _is_repeat(move):
			score -= 13.0
		scored.append({"m": move, "s": score})
		best_score = maxf(best_score, score)

	var tol: float = opts.get("tolerance", 0.25)
	if randf() < opts.get("blunder", 0.0):
		tol = maxf(tol, 12.0)
	var pool: Array = scored.filter(func(e): return e["s"] >= best_score - tol)
	var pick: Dictionary = pool[randi() % pool.size()]
	_history.append({"from": pick["m"]["from"], "to": pick["m"]["to"]})
	if _history.size() > HISTORY_LEN:
		_history.pop_front()
	return pick["m"]

# Jogada que leva uma peça de volta a uma casa que a IA deixou há pouco.
static func _is_repeat(move: Dictionary) -> bool:
	for h in _history:
		if move["to"] == h["from"] and move["from"] == h["to"]:
			return true
	return false

# Nota do tabuleiro para a IA: só material (comum 10, dama 50). Posição não
# conta: recuar não é "pior" que avançar. O que impede a IA de ficar esperando
# é a regra anti-repetição em get_best_move.
static func evaluate(board: Board, team: int) -> float:
	var enemy_team: int = Board.BLACK if team == Board.WHITE else Board.WHITE
	var score: float = 0.0
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p == Board.EMPTY or p.is_tree:
				continue
			if p.owner_team != team and p.owner_team != enemy_team:
				continue
			var val: float = 50.0 if p.is_king else 10.0
			score += val if p.owner_team == team else -val
	return score

static func minimax(board: Board, depth: int, alpha: float, beta: float, maximizing_player: bool, ai_team: int) -> float:
	var opponent_team = board.human_team_color

	if depth == 0:
		return evaluate(board, ai_team)

	if maximizing_player:
		var max_eval = -INF
		var moves = board.get_all_valid_moves(ai_team)
		if moves.size() == 0:
			return -1000.0

		for move in moves:
			var sim_board = board.clone()
			sim_board.make_move(move)
			var eval_score = minimax(sim_board, depth - 1, alpha, beta, false, ai_team)
			max_eval = max(max_eval, eval_score)
			alpha = max(alpha, eval_score)
			if beta <= alpha:
				break
		return max_eval

	else:
		var min_eval = INF
		var moves = board.get_all_valid_moves(opponent_team)
		if moves.size() == 0:
			return 1000.0

		for move in moves:
			var sim_board = board.clone()
			sim_board.make_move(move)
			var eval_score = minimax(sim_board, depth - 1, alpha, beta, true, ai_team)
			min_eval = min(min_eval, eval_score)
			beta = min(beta, eval_score)
			if beta <= alpha:
				break
		return min_eval
