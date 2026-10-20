class_name RuleRoyalGuard
extends RuleCard

# [LEI INIMIGA] O inimigo começa com 1 Dama na fileira de trás, perto do
# centro. Ela é marcada como sd_exempt: não conta como "Dama nova" para ativar
# a Morte Súbita (SuddenDeathManager._count_total_kings ignora essas Damas).
# Aplicada no evento `board_ready` (depois do posicionamento das peças).

func _init() -> void:
	id = "royal_guard"
	name = "Guarda Real"
	description = "[LEI INIMIGA] O inimigo começa o duelo com 1 Dama na fileira de trás. Essa Dama não conta para ativar a Morte Súbita."
	category = Category.BOARD
	scope = Scope.AI_ONLY
	priority = 6

func on_game_event(event_name: StringName, _context: Dictionary, board: RefCounted) -> void:
	if event_name != &"board_ready":
		return
	# O inimigo joga do topo: a fileira de trás dele é a 0.
	var back_row = 0 if board.ai_team_color != board.human_team_color else board.rows - 1
	var mid = (board.cols - 1) / 2.0
	var best_c := -1
	var best_dist := 9999.0
	for c in range(board.cols):
		var p: BoardPiece = board.grid[back_row][c]
		if p == Board.EMPTY or p.owner_team == board.human_team_color or p.is_tree or p.is_king:
			continue
		var dist = absf(c - mid)
		if dist < best_dist:
			best_dist = dist
			best_c = c
	if best_c >= 0:
		var guard: BoardPiece = board.grid[back_row][best_c]
		guard.is_king = true
		guard.sd_exempt = true
		board.rule_fired.emit(id)
