class_name CardCoronation
extends ActionCard

func _init() -> void:
	id = "coronation"
	icon_path = "res://assets/sprites/cards/icons/coronation.png"
	name = "Coroação"
	description = "Promove imediatamente uma peça aliada comum para Dama."
	rarity = Rarity.LEGENDARY
	target_type = TargetType.ALLY_PIECE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	return not piece.is_king # Somente peças comuns

func execute(board: Board, target_pos: Vector2i, _human_team: int, _context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece != Board.EMPTY:
		piece.is_king = true
