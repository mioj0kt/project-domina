class_name RuleReverseMovement
extends RuleCard

func _init() -> void:
	id = "reverse_movement"
	name = "Movimento Reverso"
	description = "Suas peças comuns podem se mover e capturar recuando nas diagonais para trás."
	category = Category.MOVEMENT
	scope = Scope.PLAYER_ONLY
	priority = 10

func modify_move_directions(piece: BoardPiece, current_dirs: Array[Vector2i], _human_team: int, _board: RefCounted) -> Array[Vector2i]:
	if not piece.is_king:
		return [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	return current_dirs

func get_move_trigger_banner(piece: BoardPiece, from_pos: Vector2i, to_pos: Vector2i, _was_capture: bool) -> Dictionary:
	if not piece.is_king and to_pos.y > from_pos.y:
		return {"text": "REVERSO!", "color": Color(0.3, 0.75, 1.0)}
	return {}
