class_name RuleCarnage
extends RuleCard

func _init() -> void:
	id = "carnage"
	name = "Carnificina"
	description = "Ganha +1 de ouro a cada captura."
	category = Category.CAPTURE
	scope = Scope.PLAYER_ONLY
	priority = 35

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name == &"piece_captured":
		var attacker: BoardPiece = context.get("attacker")
		if attacker and attacker.owner_team == board.human_team_color:
			if RunManager != null:
				RunManager.add_effect_gold(1)
			board.rule_fired.emit(id)
