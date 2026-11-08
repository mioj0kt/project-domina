class_name CardSuddenStart
extends ActionCard

# Hora H: liga a Morte Súbita na hora (a checagem pós-efeito do controlador
# dispara a abertura). Não vale se já está ativa, nem no Chefe (lá ela só liga
# por impasse) nem em modos sem Morte Súbita.

func _init() -> void:
	id = "sudden_start"
	icon_path = "res://assets/sprites/cards/icons/sudden_start.png"
	name = "Hora H"
	description = "Liga a Morte Súbita agora. Só funciona se ela ainda não estiver ativa."
	rarity = Rarity.RARE
	target_type = TargetType.NONE

func can_play(_board: Board, _human_team: int, context: Dictionary = {}) -> bool:
	var main_node = context.get("main")
	if main_node == null or not ("sudden_death_mgr" in main_node) or main_node.sudden_death_mgr == null:
		return false
	var sd = main_node.sudden_death_mgr
	if sd.is_active or sd.stall_only:
		return false
	return main_node.current_duel != null and main_node.current_duel.uses_sudden_death()

func execute(_board: Board, _target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	var main_node = context.get("main")
	if main_node == null or not ("sudden_death_mgr" in main_node) or main_node.sudden_death_mgr == null:
		return
	main_node.sudden_death_mgr.request_start()
