class_name CardSwap
extends ActionCard

# Troca de Lugar: uma peça sua troca de casa com uma peça inimiga colada nela (na
# diagonal). Se houver mais de uma inimiga encostada, o jogador escolhe qual.
const DIRS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

func _init() -> void:
	id = "swap"
	icon_path = "res://assets/sprites/cards/icons/swap.png"
	name = "Troca de Lugar"
	description = "Uma peça sua troca de casa com uma peça inimiga colada nela na diagonal."
	rarity = Rarity.EPIC
	target_type = TargetType.ALLY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	if board.grid[target_pos.y][target_pos.x].is_tree:
		return false
	return not _neighbors(board, target_pos, team).is_empty()

static func _neighbors(board: Board, pos: Vector2i, team: int) -> Array:
	var out: Array = []
	for d in DIRS:
		var n: Vector2i = pos + d
		if not board.is_valid_pos(n.y, n.x):
			continue
		var p: BoardPiece = board.grid[n.y][n.x]
		if p != Board.EMPTY and not p.is_tree and p.owner_team != team and p.owner_team != Board.NEUTRAL:
			out.append(n)
	return out

func get_second_targets(board: Board, first: Vector2i, team: int, _context: Dictionary = {}) -> Array:
	return _neighbors(board, first, team)

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var opts: Array = _neighbors(board, target_pos, team)
	if opts.is_empty():
		return
	var other: Vector2i = context.get("second", Vector2i(-1, -1))
	if not opts.has(other):
		other = opts[0]
	var a: BoardPiece = board.grid[target_pos.y][target_pos.x]
	board.grid[target_pos.y][target_pos.x] = board.grid[other.y][other.x]
	board.grid[other.y][other.x] = a
	Sfx.play("mover")
	await CardFx.slide(context.get("main"), [[target_pos, other], [other, target_pos]], 0.4)
	_pop_banner(context, "TROCA DE LUGAR!", Color(0.95, 0.8, 0.4), other)
