class_name CardSquire
extends ActionCard

const SHIELD_DURATION: int = 2

func _init() -> void:
	id = "squire"
	icon_path = "res://assets/sprites/cards/icons/squire.png"
	name = "Escudeiro"
	description = "Cria uma peça comum com escudo numa casa escura vazia das suas 2 primeiras fileiras. A próxima captura contra ela falha."
	rarity = Rarity.EPIC
	target_type = TargetType.EMPTY_TILE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	if human_team == board.human_team_color:
		return target_pos.y >= (board.rows - 2)
	return target_pos.y <= 1

func execute(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> void:
	var p := BoardPiece.new(human_team, false)
	p.shield_turns = SHIELD_DURATION
	board.grid[target_pos.y][target_pos.x] = p
	await CardFx.spawn(context.get("main"), target_pos, human_team)
