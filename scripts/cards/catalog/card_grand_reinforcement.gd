class_name CardGrandReinforcement
extends ActionCard

func _init() -> void:
	id = "grand_reinforcement"
	icon_path = "res://assets/sprites/cards/icons/grand_reinforcement.png"
	name = "Grande Reforço"
	description = "Se uma das 3 fileiras do seu lado estiver totalmente vazia (sem nenhuma peça), invoca uma peça comum em cada casa escura dessa fileira."
	rarity = Rarity.LEGENDARY
	target_type = TargetType.EMPTY_TILE

# Fileiras de trás do lado de quem joga (3 mais próximas da própria borda).
const BACK_ROWS: int = 3

func _is_own_back_row(board: Board, row: int, human_team: int) -> bool:
	if human_team == board.human_team_color:
		return row >= board.rows - BACK_ROWS
	return row < BACK_ROWS

# "Totalmente vazia": nenhuma peça de ninguém (nem inimiga, nem árvore).
func _is_row_totally_empty(board: Board, row: int) -> bool:
	for c in range(board.cols):
		if board.grid[row][c] != Board.EMPTY:
			return false
	return true

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return _is_own_back_row(board, target_pos.y, human_team) and _is_row_totally_empty(board, target_pos.y)

func execute(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> void:
	var row = target_pos.y
	for c in range(board.cols):
		var is_dark_tile = (row + c) % 2 == 1
		var is_empty = board.grid[row][c] == Board.EMPTY
		var is_scorched = board.scorched_tiles.has(Vector2i(c, row))
		if is_dark_tile and is_empty and not is_scorched:
			board.grid[row][c] = BoardPiece.new(human_team, false)
