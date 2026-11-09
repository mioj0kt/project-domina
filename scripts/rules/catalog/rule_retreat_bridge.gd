class_name RuleRetreatBridge
extends RuleCard

# O movimento vive em Board._append_retreat_hops (uma vez por peça comum).

func _init() -> void:
	id = "retreat_bridge"
	name = "Lei da Ponte de Recuo"
	description = "Cada peça comum sua pode recuar uma vez: pula 2 casas para trás em linha reta, por cima da casa clara, como numa ponte."
	category = Category.MOVEMENT
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 11

func get_move_trigger_banner(piece: BoardPiece, from_pos: Vector2i, to_pos: Vector2i, _was_capture: bool) -> Dictionary:
	if not piece.is_king and to_pos.y - from_pos.y == 2:
		return {"text": "RECUO!", "color": Color(0.3, 0.75, 1.0)}
	return {}
