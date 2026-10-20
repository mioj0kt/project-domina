class_name CardExtraTurn
extends ActionCard

func _init() -> void:
	id = "extra_turn"
	icon_path = "res://assets/sprites/cards/icons/extra_turn.png"
	name = "Segundo Turno"
	description = "Concede um turno adicional imediatamente após realizar a sua jogada deste turno."
	rarity = Rarity.LEGENDARY
	target_type = TargetType.NONE

func execute(_board: Board, _target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	var main_node = context.get("main")
	if main_node and "extra_turns_by_team" in main_node:
		var current = main_node.extra_turns_by_team.get(human_team, 0)
		main_node.extra_turns_by_team[human_team] = current + 1
