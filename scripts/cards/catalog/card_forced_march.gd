class_name CardForcedMarch
extends ActionCard

# Marcha Forçada: uma peça inimiga comum é obrigada a dar um passo para a frente
# (na diagonal, rumo ao lado dela de virar Dama) numa casa livre, de preferência
# para dentro do seu alcance. Não vale empurrar para a fileira de coroação.

func _init() -> void:
	id = "forced_march"
	icon_path = "res://assets/sprites/cards/icons/forced_march.png"
	name = "Marcha Forçada"
	description = "Obriga uma peça inimiga comum a andar uma casa para a frente na diagonal, se estiver livre. Você escolhe para qual lado."
	rarity = Rarity.COMMON
	target_type = TargetType.ENEMY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	return not landings(board, target_pos).is_empty()

static func landings(board: Board, pos: Vector2i) -> Array:
	var out: Array = []
	var p: BoardPiece = board.grid[pos.y][pos.x]
	if p == Board.EMPTY or p.is_tree or p.is_king or p.rooted_turns > 0:
		return out
	var fwd: int = -1 if p.owner_team == board.human_team_color else 1
	var promo: int = CardPush.promo_row(board, p.owner_team)
	for dx in [-1, 1]:
		var to := Vector2i(pos.x + dx, pos.y + fwd)
		if CardPush.free_tile(board, to) and to.y != promo:
			out.append(to)
	return out

func get_second_targets(board: Board, first: Vector2i, _team: int, _context: Dictionary = {}) -> Array:
	return landings(board, first)

func execute(board: Board, target_pos: Vector2i, _team: int, context: Dictionary = {}) -> void:
	var opts: Array = landings(board, target_pos)
	if opts.is_empty():
		return
	var to: Vector2i = context.get("second", Vector2i(-1, -1))
	if not opts.has(to):
		to = opts[0]
	board.grid[to.y][to.x] = board.grid[target_pos.y][target_pos.x]
	board.grid[target_pos.y][target_pos.x] = Board.EMPTY
	Sfx.play("mover")
	await CardFx.slide(context.get("main"), [[target_pos, to]], 0.3)
	_pop_banner(context, "MARCHA FORÇADA!", Color(0.95, 0.6, 0.45), to)
