class_name CardHeir
extends ActionCard

# O turno em que a carta e jogada ja conta: a peca e Dama agora e nos
# proximos (DURATION_TURNS - 1) turnos do dono; depois volta a ser comum.
const DURATION_TURNS: int = 3

func _init() -> void:
	id = "heir"
	icon_path = "res://assets/sprites/cards/icons/heir.png"
	name = "Herdeiro"
	description = "Uma peça comum sua vira Dama por 3 turnos e depois volta a ser comum."
	rarity = Rarity.EPIC
	target_type = TargetType.ALLY_PIECE

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), human_team, context):
				return true
	return false

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return not board.grid[target_pos.y][target_pos.x].is_king

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	piece.is_king = true
	piece.temp_king_turns = DURATION_TURNS
	_pop_banner(context, "HERDEIRO!", Color(0.85, 0.65, 1.0), target_pos)
