class_name RuleCarnage
extends RuleCard

func _init() -> void:
	id = "carnage"
	name = "Carnificina"
	description = "Ao capturar uma peça inimiga, concede +1 de Ouro imediatamente."
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
