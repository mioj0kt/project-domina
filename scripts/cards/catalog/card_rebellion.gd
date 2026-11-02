class_name CardRebellion
extends CardCorrupt

# Corromper em massa: mesma regra de alvo (peça comum inimiga isolada), mas
# converte a escolhida E mais uma peça comum isolada do inimigo, se houver.

func _init() -> void:
	super._init()
	id = "rebellion"
	icon_path = "res://assets/sprites/cards/icons/rebellion.png"
	name = "Rebelião"
	description = "Toma até 2 peças comuns inimigas isoladas: a escolhida e mais uma."
	rarity = Rarity.LEGENDARY
	target_type = TargetType.ENEMY_PIECE

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	# A primeira usa a conversao animada do Corromper.
	await super.execute(board, target_pos, human_team, context)

	# Segunda peca: qualquer outra comum isolada do inimigo (sorteada).
	var candidates: Array[Vector2i] = []
	for r in range(board.rows):
		for c in range(board.cols):
			var pos = Vector2i(c, r)
			if pos != target_pos and is_valid_target(board, pos, human_team, context):
				candidates.append(pos)
	if candidates.is_empty():
		_pop_banner(context, "REBELIAO!", Color(0.85, 0.3, 0.3), target_pos)
		return

	var second: Vector2i = candidates[randi() % candidates.size()]
	var piece: BoardPiece = board.grid[second.y][second.x]
	_pop_banner(context, "REBELIAO!", Color(0.85, 0.3, 0.3), second)
	await _convert_piece(board, second, piece, human_team, context)
