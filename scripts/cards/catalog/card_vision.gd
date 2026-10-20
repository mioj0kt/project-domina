class_name CardVision
extends ActionCard

func _init() -> void:
	id = "vision"
	icon_path = "res://assets/sprites/cards/icons/vision.png"
	name = "Visao"
	description = "Revela os movimentos e capturas ameaçados pelo inimigo para este turno."
	rarity = Rarity.COMMON
	target_type = TargetType.NONE

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var main_node = context.get("main")
	if main_node and "show_enemy_threats" in main_node:
		main_node.show_enemy_threats = true
