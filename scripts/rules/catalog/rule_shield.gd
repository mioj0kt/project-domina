class_name RuleShield
extends RuleCard

var shield_used: bool = false

func _init() -> void:
	id = "shield"
	name = "Escudo"
	description = "A primeira peça sua que seria capturada neste duelo sobrevive automaticamente, uma única vez."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 5

func try_prevent_capture(_victim: BoardPiece, _board: RefCounted) -> bool:
	if shield_used:
		return false
	shield_used = true
	return true

func on_game_event(event_name: StringName, _context: Dictionary, _board: RefCounted) -> void:
	if event_name == &"duel_started":
		shield_used = false
