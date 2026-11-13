class_name CardPush
extends ActionCard

# Empurrão: uma peça inimiga colada (na diagonal) numa peça sua é empurrada uma
# casa para longe dela, continuando a mesma diagonal. A casa precisa estar livre e
# não pode ser a fileira onde a inimiga viraria Dama. Com mais de uma direção
# possível, o jogador escolhe a casa.
const DIRS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

func _init() -> void:
	id = "push"
	icon_path = "res://assets/sprites/cards/icons/push.png"
	name = "Empurrão"
	description = "Empurra uma peça inimiga colada numa peça sua uma casa para longe dela, na mesma diagonal (se a casa estiver livre)."
	rarity = Rarity.COMMON
	target_type = TargetType.ENEMY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	return not landings(board, target_pos, team).is_empty()

static func free_tile(board: Board, pos: Vector2i) -> bool:
	return board.is_valid_pos(pos.y, pos.x) and board.grid[pos.y][pos.x] == Board.EMPTY \
		and not board.scorched_tiles.has(pos) and not board.fire_tiles.has(pos)

static func promo_row(board: Board, team: int) -> int:
	return 0 if team == board.human_team_color else board.rows - 1

static func landings(board: Board, enemy_pos: Vector2i, team: int) -> Array:
	var out: Array = []
	var enemy: BoardPiece = board.grid[enemy_pos.y][enemy_pos.x]
	if enemy == Board.EMPTY or enemy.is_tree:
		return out
	for d in DIRS:
		var ally_pos: Vector2i = enemy_pos - d
		if not board.is_valid_pos(ally_pos.y, ally_pos.x):
			continue
		var ally: BoardPiece = board.grid[ally_pos.y][ally_pos.x]
		if ally == Board.EMPTY or ally.is_tree or ally.owner_team != team:
			continue
		var to: Vector2i = enemy_pos + d
		if not free_tile(board, to) or out.has(to):
			continue
		if not enemy.is_king and to.y == promo_row(board, enemy.owner_team):
			continue
		out.append(to)
	return out

func get_second_targets(board: Board, first: Vector2i, team: int, _context: Dictionary = {}) -> Array:
	return landings(board, first, team)

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var opts: Array = landings(board, target_pos, team)
	if opts.is_empty():
		return
	var to: Vector2i = context.get("second", Vector2i(-1, -1))
	if not opts.has(to):
		to = opts[0]
	board.grid[to.y][to.x] = board.grid[target_pos.y][target_pos.x]
	board.grid[target_pos.y][target_pos.x] = Board.EMPTY
	var main = context.get("main")
	if CardFx._ok(main):
		Juice.ring(main, CardFx.center_of(main, target_pos), main.cell_size * 0.6, Color(1, 0.9, 0.7), 4.0, 0.2)
	Sfx.play("bloqueio")
	await CardFx.slide(main, [[target_pos, to]], 0.22)
	_pop_banner(context, "EMPURRÃO!", Color(0.95, 0.75, 0.45), to)
