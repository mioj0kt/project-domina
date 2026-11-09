class_name RuleCinders
extends RuleCard

const BONUS_GOLD: int = 2

func _init() -> void:
	id = "cinders"
	name = "Lei das Cinzas"
	description = "Todas as chamas somem 1 turno mais cedo, mas toda peça que pousar numa casa em chamas rende +2 de ouro."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.COMMON
	priority = 48
	incompatible_with = ["inferno"]

func on_game_event(event_name: StringName, _context: Dictionary, board: RefCounted) -> void:
	if event_name != &"landed_on_fire":
		return
	if RunManager != null:
		RunManager.add_effect_gold(BONUS_GOLD)
	board.rule_fired.emit(id)
