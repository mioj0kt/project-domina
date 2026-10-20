class_name CardRetaliation
extends ActionCard

func _init() -> void:
	id = "retaliation"
	icon_path = "res://assets/sprites/cards/icons/retaliation.png"
	name = "Retaliação"
	description = "Só pode ser jogada se voce perdeu uma peça no último turno. Concede +10 de Ouro e coroa uma peça sua."
	rarity = Rarity.EPIC
	target_type = TargetType.ALLY_PIECE

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	var main_node = context.get("main")
	return main_node != null and main_node.lost_piece_last_enemy_turn

func execute(board: Board, target_pos: Vector2i, _human_team: int, _context: Dictionary = {}) -> void:
	if RunManager != null:
		RunManager.add_effect_gold(10)
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece != Board.EMPTY:
		piece.is_king = true
