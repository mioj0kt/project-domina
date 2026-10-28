class_name CardFrogBait
extends ActionCard
# Isca do Sapo: a mosca do chefe Sapo, agora como carta. Pousa numa casa escura
# vazia; depois de DELAY_PLIES jogadas (2 rodadas) a língua do sapo desce e devora
# QUALQUER peça que estiver ali — inclusive as suas.

const DELAY_PLIES: int = 4

func _init() -> void:
	id = "frog_bait"
	icon_path = "res://assets/sprites/cards/icons/frog_bait.png"
	name = "Isca do Sapo"
	description = "Pousa uma mosca numa casa escura vazia. Na 2a rodada depois, a lingua do sapo desce e devora QUALQUER peca que estiver la, inclusive as suas."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), human_team, context):
				return true
	return false

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	for b in board.bait_flies:
		if b["pos"] == target_pos:
			return false
	return true

func execute(board: Board, target_pos: Vector2i, _human_team: int, context: Dictionary = {}) -> void:
	board.bait_flies.append({"pos": target_pos, "turns": DELAY_PLIES})
	_pop_banner(context, "ISCA LANCADA!", Color(0.6, 0.95, 0.4), target_pos)
	var main_node = context.get("main")
	if main_node != null and "frog_animation_view" in main_node and main_node.frog_animation_view != null:
		await main_node.frog_animation_view.add_fly(target_pos)
