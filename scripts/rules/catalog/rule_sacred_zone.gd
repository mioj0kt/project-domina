class_name RuleSacredZone
extends RuleCard

func _init() -> void:
	id = "sacred_zone"
	name = "Zona Sagrada"
	description = "Suas peças comuns também são promovidas à Dama ao pisarem em uma das 4 casas centrais do tabuleiro."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 32

func check_custom_promotion(piece: BoardPiece, to_pos: Vector2i, board: RefCounted) -> bool:
	if piece.is_king:
		return false
	return board.is_center_tile(to_pos.y, to_pos.x)

func get_promotion_trigger_banner(_to_pos: Vector2i) -> Dictionary:
	return {"text": "ZONA SAGRADA!", "color": Color(1.0, 0.9, 0.3)}
