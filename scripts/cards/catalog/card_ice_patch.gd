class_name CardIcePatch
extends ActionCard

# Placa de Gelo: a casa escolhida e as casas escuras coladas nela na diagonal viram
# gelo até o fim do duelo (a mesma regra do Gelo Escorregadio do chefe do Cume, ver
# Board.ice_tiles): quem PARA no gelo com movimento simples escorrega mais uma casa.

const DIRS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

func _init() -> void:
	id = "ice_patch"
	icon_path = "res://assets/sprites/cards/icons/ice_patch.png"
	name = "Placa de Gelo"
	description = "Uma casa escura vazia e as casas coladas nela na diagonal viram gelo até o fim do duelo. Quem para no gelo com um movimento simples escorrega mais uma casa, se estiver livre."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	return not _cells(board, target_pos).is_empty()

# Casas que viram gelo: o alvo e as diagonais (ocupadas ou não) que não estão bloqueadas.
static func _cells(board: Board, center: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.ZERO] + DIRS:
		var p: Vector2i = center + d
		if not board.is_valid_pos(p.y, p.x) or board.scorched_tiles.has(p) or board.fire_tiles.has(p):
			continue
		if board.ice_tiles.has(p) or board.water_tiles.has(p) or board.lava_tiles.has(p):
			continue
		out.append(p)
	return out

func execute(board: Board, target_pos: Vector2i, _team: int, context: Dictionary = {}) -> void:
	var cells: Array = _cells(board, target_pos)
	for p in cells:
		board.ice_tiles[p] = true
	var main = context.get("main")
	if CardFx._ok(main):
		Sfx.play("vento_nascer")
		for p in cells:
			var c := CardFx.center_of(main, p)
			Juice.flash_square(main, c, main.cell_size, Color(0.75, 0.92, 1.0, 0.5), 0.25)
			Juice.burst(main, c, Color(0.85, 0.95, 1.0), 6, 140.0, 0.4, maxf(2.0, main.cell_size / 24.0), -40.0, 70.0, Vector2.UP)
		Juice.sparkle(main, CardFx.center_of(main, target_pos), 10)
	_pop_banner(context, "PLACA DE GELO!", Color(0.75, 0.92, 1.0), target_pos)
