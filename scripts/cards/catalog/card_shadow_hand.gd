class_name CardShadowHand
extends ActionCard

const DURATION_TURNS: int = 3

func _init() -> void:
	id = "shadow_hand"
	icon_path = "res://assets/sprites/cards/icons/shadow_hand.png"
	name = "Mão Sombria"
	description = "Uma mão de sombra espera escondida numa casa vazia por 3 turnos. A primeira peça inimiga que pousar nela é agarrada e perde a próxima jogada."
	rarity = Rarity.EPIC
	target_type = TargetType.EMPTY_TILE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return not board.trap_tiles.has(target_pos)

func execute(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> void:
	# Sem aviso na casa: a mão é escondida. (Quando a IA usa, o aviso entregava
	# onde ela estava.) A mão do jogador já aparece desenhada no tabuleiro.
	board.trap_tiles[target_pos] = {"turns": DURATION_TURNS, "team": human_team}
