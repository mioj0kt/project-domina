class_name CardEmber
extends ActionCard

const DURATION_TURNS: int = 4

func _init() -> void:
	id = "ember"
	icon_path = "res://assets/sprites/cards/icons/ember.png"
	name = "Brasa"
	description = "Uma casa vazia pega fogo por 4 turnos: quem pousar nela é destruído."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func is_valid_target(board: Board, target_pos: Vector2i, human_team: int, context: Dictionary = {}) -> bool:
	if not super.is_valid_target(board, target_pos, human_team, context):
		return false
	return not board.fire_tiles.has(target_pos)

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	board.ignite(target_pos, DURATION_TURNS, team == board.human_team_color)
	_pop_banner(context, "BRASA!", Color(1.0, 0.5, 0.15), target_pos)
