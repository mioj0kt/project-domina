class_name CheckersAI
extends RefCounted

# exclude_from: peça que NÃO pode ser movida (Contra-Ataque: o movimento extra
# tem que ser de OUTRA peça). (-1,-1) = sem restrição.
static func get_best_move(board: Board, depth: int = 4, ai_team: int = Board.BLACK, exclude_from: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var best_score = -INF
	var best_move = {}
	var moves = board.get_all_valid_moves(ai_team)
	if exclude_from.x >= 0:
		moves = moves.filter(func(m): return m["from"] != exclude_from)

	if moves.size() == 0:
		return {}

	for move in moves:
		var sim_board = board.clone()
		sim_board.make_move(move)
		
		var score = minimax(sim_board, depth - 1, -INF, INF, false, ai_team)
		# Árvore é um avanço grátis: desempata a favor de derrubá-la.
		if move.get("optional", false):
			score += 0.5
		if score > best_score:
			best_score = score
			best_move = move

	if best_move.is_empty() and moves.size() > 0:
		best_move = moves[0]

	return best_move

static func minimax(board: Board, depth: int, alpha: float, beta: float, maximizing_player: bool, ai_team: int) -> float:
	var opponent_team = board.human_team_color

	if depth == 0:
		return board.evaluate_for_team(ai_team)

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
