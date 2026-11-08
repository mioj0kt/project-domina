class_name CardExtension
extends ActionCard

# Prorrogação: soma turnos ao relógio da Morte Súbita.
const TURNS_ADDED: int = 3

func _init() -> void:
	id = "extension"
	icon_path = "res://assets/sprites/cards/icons/extension.png"
	name = "Prorrogação"
	description = "Adiciona 3 turnos ao relógio da Morte Súbita. Só funciona com ela ativa."
	rarity = Rarity.RARE
	target_type = TargetType.NONE

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	var main_node = context.get("main")
	if main_node == null or not ("sudden_death_mgr" in main_node) or main_node.sudden_death_mgr == null:
		return false
	return main_node.sudden_death_mgr.is_active

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var main_node = context.get("main")
	if main_node == null or not ("sudden_death_mgr" in main_node) or main_node.sudden_death_mgr == null:
		return
	main_node.sudden_death_mgr.extend(TURNS_ADDED)
	_pop_banner(context, "+%d TURNOS!" % TURNS_ADDED, Color(0.45, 0.9, 0.55))
