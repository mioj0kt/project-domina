class_name CardTemper
extends ActionCard

# Têmpera: a forja coroa na hora, mas cobra o Preço da Coroa (lei do chefe da
# Caldeira): a sua peça comum mais atrasada derrete. Precisa de outra peça comum
# para pagar (Board.crown_price_victim).

func _init() -> void:
	id = "temper"
	icon_path = "res://assets/sprites/cards/icons/temper.png"
	name = "Têmpera"
	description = "Promove uma peça comum sua a Dama, mas a sua peça comum mais atrasada derrete na forja. Precisa de outra peça comum para pagar."
	rarity = Rarity.EPIC
	target_type = TargetType.ALLY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	var p: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if p.is_king or p.is_tree or p.is_sarcophagus or p.is_cactus or p.is_rock:
		return false
	return board.crown_price_victim(team, p).x >= 0

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var piece: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if piece == Board.EMPTY:
		return
	var main = context.get("main")
	var vpos: Vector2i = board.crown_price_victim(team, piece)
	if CardFx._ok(main):
		CaldeiraBossFx.strike(target_pos)
		await main.get_tree().create_timer(CaldeiraBossFx.STRIKE_IMPACT).timeout
		Sfx.play("martelo_bigorna")
		Juice.shake(main, 4.0, 0.18)
	piece.is_king = true
	await CardFx.crown(main, target_pos, piece)
	if vpos.x >= 0:
		var victim: BoardPiece = board.grid[vpos.y][vpos.x]
		if victim != Board.EMPTY:
			if CardFx._ok(main):
				Sfx.play("lava_afunda")
				var vc := CardFx.center_of(main, vpos)
				Juice.burst(main, vc, Color(1.0, 0.5, 0.15), 14, 160.0, 0.6, maxf(3.0, main.cell_size / 18.0), 260.0, 70.0)
			await CardFx.destroy(main, board, vpos, victim)
			_pop_banner(context, "DERRETEU NA FORJA!", Color(1.0, 0.5, 0.2), vpos)
	_pop_banner(context, "TÊMPERA!", Color(1.0, 0.75, 0.35), target_pos)
