class_name CardHammerBlow
extends ActionCard

# Martelada: o martelo da Ferreira desce numa peça inimiga SOZINHA (sem nenhuma
# aliada colada na diagonal), como na lei Martelada do chefe da Caldeira: peça
# comum é esmagada, Dama perde a coroa.
const DIRS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

func _init() -> void:
	id = "hammer_blow"
	icon_path = "res://assets/sprites/cards/icons/hammer_blow.png"
	name = "Martelada"
	description = "Martela uma peça inimiga sem nenhuma aliada colada na diagonal: peça comum é esmagada, Dama perde a coroa."
	rarity = Rarity.EPIC
	target_type = TargetType.ENEMY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	var p: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if p.is_sarcophagus or p.is_cactus or p.is_rock or p.owner_team == Board.NEUTRAL:
		return false
	return is_alone(board, target_pos)

static func is_alone(board: Board, pos: Vector2i) -> bool:
	var p: BoardPiece = board.grid[pos.y][pos.x]
	for d in DIRS:
		var n: Vector2i = pos + d
		if not board.is_valid_pos(n.y, n.x):
			continue
		var q: BoardPiece = board.grid[n.y][n.x]
		if q != Board.EMPTY and q.owner_team == p.owner_team and not q.is_tree:
			return false
	return true

func execute(board: Board, target_pos: Vector2i, _team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	var main = context.get("main")
	if CardFx._ok(main):
		CaldeiraBossFx.strike(target_pos)
		await main.get_tree().create_timer(CaldeiraBossFx.STRIKE_IMPACT).timeout
		Sfx.play("martelo_bigorna")
		Juice.shake(main, 6.0, 0.22)
		var c := CardFx.center_of(main, target_pos)
		Juice.burst(main, c, Color(1.0, 0.82, 0.4), 16, 300.0, 0.45, maxf(3.0, main.cell_size / 18.0), 380.0, 90.0)
	if piece.is_king:
		await CardFx.demote(main, target_pos, func(): piece.is_king = false)
		_pop_banner(context, "COROA AMASSADA!", Color(1.0, 0.7, 0.35), target_pos)
		return
	# Última Chance: se a peça é do jogador (Martelada da IA), a moeda gira antes.
	if await RuleLastChance.try_save(main, target_pos, piece):
		return
	await CardFx.destroy(main, board, target_pos, piece)
	_pop_banner(context, "ESMAGADA!", Color(1.0, 0.55, 0.3), target_pos)
