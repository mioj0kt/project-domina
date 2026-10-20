class_name RuleAllyHop
extends RuleCard

func _init() -> void:
	id = "ally_hop"
	name = "Salto Camarada"
	description = "Suas peças podem pular sobre peças aliadas na diagonal como se fossem capturas, avançando 2 casas sem destruir a aliada."
	category = Category.MOVEMENT
	scope = Scope.PLAYER_ONLY
	priority = 12

func modify_move_directions(_piece: BoardPiece, current_dirs: Array[Vector2i], _human_team: int, _board: RefCounted) -> Array[Vector2i]:
	return current_dirs

func get_move_trigger_banner(_piece: BoardPiece, from_pos: Vector2i, to_pos: Vector2i, was_capture: bool) -> Dictionary:
	if not was_capture and abs(to_pos.y - from_pos.y) == 2:
		return {"text": "SALTO CAMARADA!", "color": Color(0.4, 0.9, 0.5)}
	return {}
