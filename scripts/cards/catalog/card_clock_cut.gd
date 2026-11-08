class_name CardClockCut
extends ActionCard

# Corte no Relógio: tira turnos da Morte Súbita (sempre sobra pelo menos 1).
const TURNS_CUT: int = 2

func _init() -> void:
	id = "clock_cut"
	icon_path = "res://assets/sprites/cards/icons/clock_cut.png"
	name = "Corte no Relógio"
	description = "Remove 2 turnos do relógio da Morte Súbita. Só funciona com ela ativa."
	rarity = Rarity.COMMON
	target_type = TargetType.NONE

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	var main_node = context.get("main")
	if main_node == null or not ("sudden_death_mgr" in main_node) or main_node.sudden_death_mgr == null:
		return false
	return main_node.sudden_death_mgr.is_active and main_node.sudden_death_mgr.turns_left > 1

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var main_node = context.get("main")
	if main_node == null or not ("sudden_death_mgr" in main_node) or main_node.sudden_death_mgr == null:
		return
	main_node.sudden_death_mgr.shorten(TURNS_CUT)
	_pop_banner(context, "RELÓGIO CORTADO!", Color(1.0, 0.45, 0.35))
