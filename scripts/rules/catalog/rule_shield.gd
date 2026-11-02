class_name RuleShield
extends RuleCard

const MAX_BLOCKS: int = 2
var blocks_used: int = 0

func _init() -> void:
	id = "shield"
	name = "Escudo"
	description = "As 2 primeiras peças suas que seriam capturadas no duelo sobrevivem."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 5

func try_prevent_capture(_victim: BoardPiece, _board: RefCounted) -> bool:
	if blocks_used >= MAX_BLOCKS:
		return false
	blocks_used += 1
	return true

func on_game_event(event_name: StringName, _context: Dictionary, _board: RefCounted) -> void:
	if event_name == &"duel_started":
		blocks_used = 0
