class_name RuleUsury
extends RuleCard

const TURN_COST: int = 1
const CAPTURE_BONUS: int = 3

func _init() -> void:
	id = "usury"
	name = "Lei da Usura"
	description = "Você paga 1 de ouro no início de cada turno seu, mas ganha +3 de ouro a cada captura."
	category = Category.CAPTURE
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 39

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if RunManager == null:
		return
	if event_name == &"turn_started":
		RunManager.gold = maxi(0, RunManager.gold - TURN_COST)
	elif event_name == &"piece_captured":
		var attacker: BoardPiece = context.get("attacker")
		if attacker != null and attacker.owner_team == board.human_team_color:
			RunManager.add_effect_gold(CAPTURE_BONUS)
			board.rule_fired.emit(id)
