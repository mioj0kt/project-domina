class_name CardClimbingRope
extends ActionCard

# Corda de Escalada: amarra duas peças suas (a até 3 casas uma da outra). Quando uma
# delas é capturada, a parceira é puxada para a casa dela, se a corda alcançar (a
# mesma Cordada do chefe do Cume: Board.rope_pairs / Board._rope_pull). A corda vale
# até uma das duas cair.

func _init() -> void:
	id = "climbing_rope"
	icon_path = "res://assets/sprites/cards/icons/climbing_rope.png"
	name = "Corda de Escalada"
	description = "Amarra duas peças suas a até 3 casas uma da outra. Quando uma é capturada, a outra é puxada para a casa dela e pode revidar."
	rarity = Rarity.EPIC
	target_type = TargetType.ALLY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	if not _usable(board, board.grid[target_pos.y][target_pos.x]):
		return false
	return not _partners(board, target_pos, team).is_empty()

static func _usable(board: Board, p: BoardPiece) -> bool:
	if p == Board.EMPTY or p.is_tree or p.is_sarcophagus or p.is_cactus or p.is_rock:
		return false
	for pair in board.rope_pairs:
		if pair.has(p):
			return false   # já amarrada
	return true

static func _partners(board: Board, pos: Vector2i, team: int) -> Array:
	var out: Array = []
	for dy in range(-Board.ROPE_REACH, Board.ROPE_REACH + 1):
		for dx in range(-Board.ROPE_REACH, Board.ROPE_REACH + 1):
			var q: Vector2i = pos + Vector2i(dx, dy)
			if q == pos or not board.is_valid_pos(q.y, q.x):
				continue
			var qp: BoardPiece = board.grid[q.y][q.x]
			if qp != Board.EMPTY and qp.owner_team == team and _usable(board, qp):
				out.append(q)
	return out

func get_second_targets(board: Board, first: Vector2i, team: int, _context: Dictionary = {}) -> Array:
	return _partners(board, first, team)

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var opts: Array = _partners(board, target_pos, team)
	if opts.is_empty():
		return
	var other: Vector2i = context.get("second", Vector2i(-1, -1))
	if not opts.has(other):
		other = opts[0]
	board.rope_pairs.append([board.grid[target_pos.y][target_pos.x], board.grid[other.y][other.x]])
	var main = context.get("main")
	if CardFx._ok(main):
		Sfx.play("salto")
		for p in [target_pos, other]:
			Juice.burst(main, CardFx.center_of(main, p), Color(0.85, 0.7, 0.45), 8, 140.0, 0.35, maxf(2.0, main.cell_size / 24.0), 220.0, 80.0)
		await main.get_tree().create_timer(0.2).timeout
	_pop_banner(context, "AMARRADAS!", Color(0.95, 0.8, 0.55), other)
