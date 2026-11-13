class_name CardMirrorCrystal
extends ActionCard

# Cristal Espelho: ergue um cristal numa casa escura vazia. A casa fica bloqueada
# e uma captura que pousaria nela RICOCHETEIA para a diagonal espelhada (a mesma
# regra dos cristais do Chefe da Mina, ver Board.crystal_tiles).
const DURATION_ROUNDS: int = 6

func _init() -> void:
	id = "mirror_crystal"
	icon_path = "res://assets/sprites/cards/icons/mirror_crystal.png"
	name = "Cristal Espelho"
	description = "Ergue um cristal numa casa escura vazia por 6 rodadas. Ninguém para nele, e uma captura que pousaria ali ricocheteia para a diagonal espelhada."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	if board.fire_tiles.has(target_pos) or board.crystal_tiles.has(target_pos):
		return false
	# não pode trancar nenhum dos lados
	board.scorched_tiles[target_pos] = 1
	var ok: bool = not board.get_all_valid_moves(Board.WHITE).is_empty() and not board.get_all_valid_moves(Board.BLACK).is_empty()
	board.scorched_tiles.erase(target_pos)
	return ok

func execute(board: Board, target_pos: Vector2i, _team: int, context: Dictionary = {}) -> void:
	board.scorched_tiles[target_pos] = DURATION_ROUNDS
	board.crystal_tiles[target_pos] = true
	var main = context.get("main")
	if CardFx._ok(main):
		var c := CardFx.center_of(main, target_pos)
		Sfx.play("brotar")
		Juice.ring(main, c, main.cell_size * 0.8, Color(0.72, 0.6, 0.95), 5.0, 0.4)
		Juice.burst(main, c, Color(0.88, 0.83, 1.0), 12, 200.0, 0.6, maxf(3.0, main.cell_size / 18.0), -60.0, 50.0, Vector2.UP)
		Juice.sparkle(main, c, 8)
	_pop_banner(context, "CRISTAL ESPELHO!", Color(0.75, 0.65, 1.0), target_pos)
