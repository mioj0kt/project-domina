class_name CardRecruit
extends ActionCard

func _init() -> void:
	id = "recruit"
	icon_path = "res://assets/sprites/cards/icons/recruit.png"
	name = "Recrutamento"
	description = "Cria uma peça comum numa casa escura vazia das suas 2 primeiras fileiras."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	# Duas fileiras mais próximas do "próprio lado" — embaixo pro jogador,
	# em cima pra IA (a IA sempre começa nas fileiras de cima do tabuleiro).
	if human_team == board.human_team_color:
		return target_pos.y >= (board.rows - 2)
	return target_pos.y <= 1

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	board.grid[target_pos.y][target_pos.x] = BoardPiece.new(human_team, false)
	await CardFx.spawn(context.get("main"), target_pos, human_team)
