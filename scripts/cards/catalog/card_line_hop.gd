class_name CardLineHop
extends ActionCard

# Base das cartas de PONTE: o jogador escolhe uma casa CLARA e a ponte nasce ali
# por BRIDGE_ROUNDS rodadas (como um cipó que ele posiciona). As peças dos DOIS
# lados ao lado dela atravessam 2 casas em linha reta, no eixo da ponte. As filhas só dizem o
# eixo (Ponte Vertical = cima/baixo, Ponte Lateral = esquerda/direita).
# Não é carta sorteável sozinha (id vazio, fora do LootTables).

const BRIDGE_ROUNDS: int = 4

func _vertical() -> bool:
	return true

func _bridge_name() -> String:
	return "PONTE!"

# Casa clara livre de outros efeitos de casa clara, com as duas casas escuras do
# eixo dentro do tabuleiro (senão a ponte não ligaria nada).
func is_valid_target(board: Board, target_pos: Vector2i, _human_team: int, _context: Dictionary = {}) -> bool:
	if not board.is_valid_pos(target_pos.y, target_pos.x):
		return false
	if (target_pos.x + target_pos.y) % 2 != 0:
		return false
	if board.vine_tiles.has(target_pos) or board.bridge_tiles.has(target_pos) \
			or board.firefly_tiles.has(target_pos) or board.lit_tiles.has(target_pos):
		return false
	var axis: Vector2i = Vector2i(0, 1) if _vertical() else Vector2i(1, 0)
	var a: Vector2i = target_pos - axis
	var b: Vector2i = target_pos + axis
	return board.is_valid_pos(a.y, a.x) and board.is_valid_pos(b.y, b.x)

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	board.build_bridge(target_pos, human_team, _vertical(), BRIDGE_ROUNDS)
	_pop_banner(context, _bridge_name(), Color(0.85, 0.63, 0.25), target_pos)
