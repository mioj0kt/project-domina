class_name CardRecruit
extends ActionCard

func _init() -> void:
	id = "recruit"
	icon_path = "res://assets/sprites/cards/icons/recruit.png"
	name = "Recrutamento"
	description = "Invoca uma peça comum em uma casa escura vazia nas duas primeiras linhas do seu lado."
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

func execute(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> void:
	board.grid[target_pos.y][target_pos.x] = BoardPiece.new(human_team, false)
