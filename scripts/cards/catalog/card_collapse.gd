class_name CardCollapse
extends ActionCard

# Desmoronar: uma rocha cai sobre uma peça inimiga comum. A peça é destruída e a
# rocha fica na casa, funcionando como uma árvore (bloqueia e pode ser derrubada
# por quem pular por cima dela).

func _init() -> void:
	id = "collapse"
	icon_path = "res://assets/sprites/cards/icons/collapse.png"
	name = "Desmoronar"
	description = "Uma rocha despenca sobre uma peça inimiga comum: ela é destruída e a rocha fica na casa, bloqueando como uma árvore."
	rarity = Rarity.EPIC
	target_type = TargetType.ENEMY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	var p: BoardPiece = board.grid[target_pos.y][target_pos.x]
	return not p.is_king and p.owner_team != Board.NEUTRAL

func execute(board: Board, target_pos: Vector2i, _team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	var main = context.get("main")
	# a rocha "cai": começa grande (perto da câmera) e encolhe até o chão
	board.grid[target_pos.y][target_pos.x] = Board.EMPTY
	board.piece_destroyed.emit(target_pos, piece)
	var rock: BoardPiece = BoardPiece.make_rock()
	board.grid[target_pos.y][target_pos.x] = rock
	if CardFx._ok(main):
		var c := CardFx.center_of(main, target_pos)
		main.piece_spawn_scales[target_pos] = 2.2
		var tw = main.create_tween()
		tw.tween_method(func(v): main.piece_spawn_scales[target_pos] = v, 2.2, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		main.piece_spawn_scales.erase(target_pos)
		Sfx.play("captura")
		Juice.dust(main, c, main.cell_size)
		Juice.burst(main, c, Color(0.55, 0.45, 0.52), 14, 260.0, 0.55, maxf(3.0, main.cell_size / 16.0), 500.0, 70.0, Vector2.UP)
		Juice.shake(main, 7.0, 0.25)
	_pop_banner(context, "DESMORONOU!", Color(0.8, 0.7, 0.6), target_pos)
