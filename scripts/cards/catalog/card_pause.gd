class_name CardPause
extends ActionCard

# Só faz sentido com a Morte Subita ativa; o relogio nao desconta durante uma
# rodada completa (o fechamento do seu turno e o do turno do inimigo).
const PAUSED_TICKS: int = 2

func _init() -> void:
	id = "pause"
	icon_path = "res://assets/sprites/cards/icons/pause.png"
	name = "Pausa"
	description = "Congela o relógio da Morte Súbita por uma rodada. Só consegue usar com a Morte Súbita ativa."
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
	main_node.sudden_death_mgr.pause_ticks = PAUSED_TICKS
	main_node.sudden_death_mgr.queue_redraw()
	_pop_banner(context, "TEMPO PAUSADO!", Color(0.45, 0.8, 1.0))
