class_name RuleSecondMove
extends RuleCard

var has_used_extra_step: bool = false

func _init() -> void:
	id = "second_move"
	name = "Segundo Movimento"
	description = "Ao realizar um passo simples sem capturar, você pode mover outra peça antes de passar o turno."
	category = Category.TURN
	scope = Scope.PLAYER_ONLY
	priority = 50

func on_game_event(event_name: StringName, _context: Dictionary, _board: RefCounted) -> void:
	if event_name == &"turn_started":
		has_used_extra_step = false

func try_consume_extra_step() -> bool:
	if has_used_extra_step:
		return false
	has_used_extra_step = true
	return true
