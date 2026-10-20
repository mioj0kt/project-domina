class_name CardLightUp
extends ActionCard

# Acender Casa: peças nunca ficam em casa CLARA, então a luz protege as peças
# da casa escura de lado (4 lados) — reaproveita a proteção do vaga-lume
# (Board.is_firefly_protected), só que apenas para o time de quem acendeu.
const DURATION_TURNS: int = 2

func _init() -> void:
	id = "light_up"
	icon_path = "res://assets/sprites/cards/icons/light_up.png"
	name = "Acender Casa"
	description = "Acende uma casa clara por 2 turnos: suas peças nas 4 casas escuras ao redor dela não podem ser capturadas."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func can_play(board: Board, human_team: int, context: Dictionary = {}) -> bool:
	for r in range(board.rows):
		for c in range(board.cols):
			if is_valid_target(board, Vector2i(c, r), human_team, context):
				return true
	return false

# Casa CLARA livre (as escuras são das peças).
func is_valid_target(board: Board, target_pos: Vector2i, _human_team: int, _context: Dictionary = {}) -> bool:
	if not board.is_valid_pos(target_pos.y, target_pos.x):
		return false
	if (target_pos.y + target_pos.x) % 2 != 0:
		return false
	return not board.lit_tiles.has(target_pos) and not board.vine_tiles.has(target_pos) \
		and not board.firefly_tiles.has(target_pos) and not board.scorched_tiles.has(target_pos)

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	board.lit_tiles[target_pos] = {"turns": DURATION_TURNS, "team": human_team}
	_pop_banner(context, "CASA ACESA!", Color(1.0, 0.9, 0.45), target_pos)
