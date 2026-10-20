class_name CardRebellion
extends CardCorrupt

# Corromper em massa: mesma regra de alvo (peça comum inimiga isolada), mas
# converte a escolhida E mais uma peça comum isolada do inimigo, se houver.

func _init() -> void:
	super._init()
	id = "rebellion"
	icon_path = "res://assets/sprites/cards/icons/rebellion.png"
	name = "Rebelião"
	description = "Converte ate 2 peças comuns inimigas isoladas para o seu lado: a escolhida e mais uma."
	rarity = Rarity.LEGENDARY
	target_type = TargetType.ENEMY_PIECE

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	# A primeira usa a conversao animada do Corromper.
	super.execute(board, target_pos, human_team, context)

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
	piece.owner_team = human_team
	piece.rooted_turns = 0
	var promotion_row = 0 if (human_team == board.human_team_color) else (board.rows - 1)
	if second.y == promotion_row:
		piece.is_king = true
	_pop_banner(context, "REBELIAO!", Color(0.85, 0.3, 0.3), second)
