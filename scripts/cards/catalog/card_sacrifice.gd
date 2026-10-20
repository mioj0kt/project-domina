class_name CardSacrifice
extends ActionCard

func _init() -> void:
	id = "sacrifice"
	icon_path = "res://assets/sprites/cards/icons/sacrifice.png"
	name = "Sacrifício"
	description = "Remove voluntariamente uma peça sua do tabuleiro para ganhar +15 de Ouro e comprar 1 carta extra."
	rarity = Rarity.RARE
	target_type = TargetType.ALLY_PIECE

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece != Board.EMPTY:
		board.grid[target_pos.y][target_pos.x] = Board.EMPTY
		board.piece_destroyed.emit(target_pos, piece)
		
		if RunManager != null:
			RunManager.add_effect_gold(15)

		var deck_mgr = context.get("deck_mgr")
		if deck_mgr != null and deck_mgr.has_method("draw_cards"):
			deck_mgr.draw_cards(1)
