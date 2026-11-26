class_name CardAnvil
extends ActionCard

# Bigorna: ergue uma bigorna quente numa casa escura vazia da metade do inimigo.
# A peça SUA que começar a sua vez nela (aguentou um turno inteiro do inimigo ali)
# é martelada e vira Dama; aí a bigorna some. Peças do inimigo passam por ela sem
# efeito. Board.card_anvils guarda o dono; Board.tick_piece_effects coroa.

func _init() -> void:
	id = "anvil"
	icon_path = "res://assets/sprites/cards/icons/anvil.png"
	name = "Bigorna"
	description = "Ergue uma bigorna numa casa escura vazia da metade do inimigo. A peça sua que começar a sua vez nela vira Dama, e a bigorna some."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	if board.anvil_tiles.has(target_pos) or board.fire_tiles.has(target_pos) or board.ice_tiles.has(target_pos):
		return false
	# metade do inimigo, sem ser a fileira de coroação (lá já se vira Dama)
	if team == board.human_team_color:
		return target_pos.y * 2 < board.rows and target_pos.y > 0
	return target_pos.y * 2 >= board.rows and target_pos.y < board.rows - 1

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	board.card_anvils[target_pos] = team
	board.anvil_tiles[target_pos] = 0
	var main = context.get("main")
	if CardFx._ok(main):
		var c := CardFx.center_of(main, target_pos)
		Sfx.play("martelo_bigorna", -4.0)
		Juice.shake(main, 3.0, 0.15)
		Juice.ring(main, c, main.cell_size * 0.8, Color(1.0, 0.72, 0.35), 5.0, 0.35)
		Juice.burst(main, c, Color(1.0, 0.8, 0.4), 12, 220.0, 0.45, maxf(3.0, main.cell_size / 18.0), 360.0, 90.0)
	_pop_banner(context, "BIGORNA!", Color(1.0, 0.72, 0.35), target_pos)
