class_name CardFreeze
extends ActionCard

# Congelar: a peça inimiga vira um bloco de gelo por 2 turnos do dono — não anda
# nem captura, mas pode ser capturada (a mesma peça congelada da Geada do chefe do
# Cume, BoardPiece.frozen). BoardPiece.freeze_turns conta o degelo.
const FREEZE_TURNS: int = 2

func _init() -> void:
	id = "freeze"
	icon_path = "res://assets/sprites/cards/icons/freeze.png"
	name = "Congelar"
	description = "Congela uma peça inimiga por 2 turnos dela: não anda nem captura, mas pode ser capturada."
	rarity = Rarity.RARE
	target_type = TargetType.ENEMY_PIECE

func can_play(board: Board, team: int, context: Dictionary = {}) -> bool:
	return has_any_target(board, team, context)

func is_valid_target(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, team, context):
		return false
	var p: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if p.frozen or p.is_sarcophagus or p.is_cactus or p.is_rock or p.owner_team == Board.NEUTRAL:
		return false
	# não pode deixar o adversário sem nenhuma jogada (isso seria vitória de graça)
	p.frozen = true
	var ok: bool = not board.get_all_valid_moves(p.owner_team).is_empty()
	p.frozen = false
	return ok

func execute(board: Board, target_pos: Vector2i, _team: int, context: Dictionary = {}) -> void:
	var p: BoardPiece = board.grid[target_pos.y][target_pos.x]
	if p == Board.EMPTY:
		return
	p.frozen = true
	p.freeze_turns = FREEZE_TURNS
	var main = context.get("main")
	if CardFx._ok(main):
		var c := CardFx.center_of(main, target_pos)
		Sfx.play("bloqueio")
		Juice.ring(main, c, main.cell_size * 0.75, Color(0.75, 0.92, 1.0), 5.0, 0.35)
		Juice.burst(main, c, Color(0.85, 0.95, 1.0), 14, 200.0, 0.5, maxf(3.0, main.cell_size / 20.0), 120.0, 60.0)
		Juice.shake(main, 2.5, 0.14)
	_pop_banner(context, "CONGELOU!", Color(0.78, 0.94, 1.0), target_pos)
