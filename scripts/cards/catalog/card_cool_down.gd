class_name CardCoolDown
extends ActionCard

# Resfriar: um balde d'água numa área 3x3. Apaga fogo e brasa, desfaz o basalto e
# a lava da escorrida (as casas voltam a ficar livres). A lava fixa das ilhas da
# Caldeira, cristais, neve e buracos no gelo não mudam.

func _init() -> void:
	id = "cool_down"
	icon_path = "res://assets/sprites/cards/icons/cool_down.png"
	name = "Resfriar"
	description = "Joga água numa área 3x3: apaga fogo e brasa e desfaz basalto e lava de escorrida. As casas voltam a ficar livres."
	rarity = Rarity.COMMON
	target_type = TargetType.EMPTY_TILE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

# Qualquer casa vale como centro, desde que a área tenha algo para esfriar.
func is_valid_target(board: Board, target_pos: Vector2i, _team: int, _context: Dictionary = {}) -> bool:
	if not board.is_valid_pos(target_pos.y, target_pos.x):
		return false
	return not _hot_cells(board, target_pos).is_empty()

static func _is_hot(board: Board, p: Vector2i) -> bool:
	return board.fire_tiles.has(p) or board.ember_tiles.has(p) or board.crust_tiles.has(p) or board.flow_tiles.has(p)

static func _hot_cells(board: Board, center: Vector2i) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p: Vector2i = center + Vector2i(dx, dy)
			if board.is_valid_pos(p.y, p.x) and _is_hot(board, p):
				out.append(p)
	return out

func execute(board: Board, target_pos: Vector2i, _team: int, context: Dictionary = {}) -> void:
	var cells: Array = _hot_cells(board, target_pos)
	for p in cells:
		board.fire_tiles.erase(p)
		if board.ember_tiles.has(p) or board.crust_tiles.has(p) or board.flow_tiles.has(p):
			board.scorched_tiles.erase(p)
		board.ember_tiles.erase(p)
		board.crust_tiles.erase(p)
		if board.flow_tiles.has(p):
			board.flow_tiles.erase(p)
			board.lava_tiles.erase(p)
	var main = context.get("main")
	if CardFx._ok(main):
		Sfx.play("lava_afunda")
		for p in cells:
			var c := CardFx.center_of(main, p)
			Juice.flash_square(main, c, main.cell_size, Color(0.6, 0.85, 1.0, 0.45), 0.25)
			Juice.burst(main, c, Color(0.9, 0.92, 0.95), 8, 120.0, 0.7, maxf(3.0, main.cell_size / 18.0), -80.0, 60.0, Vector2.UP)
	_pop_banner(context, "RESFRIOU! (%d)" % cells.size(), Color(0.6, 0.85, 1.0), target_pos)
