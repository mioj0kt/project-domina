class_name CardFlameWall
extends ActionCard

const DURATION_TURNS: int = 2

func _init() -> void:
	id = "flame_wall"
	icon_path = "res://assets/sprites/cards/icons/flame_wall.png"
	name = "Muro de Chamas"
	description = "Todas as casas escuras vazias da fileira escolhida pegam fogo por 2 turnos: quem pousar nelas é destruído."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func execute(board: Board, target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	for c in range(board.cols):
		var pos := Vector2i(c, target_pos.y)
		if (pos.x + pos.y) % 2 == 1 and board.grid[pos.y][pos.x] == Board.EMPTY and not board.scorched_tiles.has(pos):
			board.ignite(pos, DURATION_TURNS, team == board.human_team_color)
	_pop_banner(context, "MURO DE CHAMAS!", Color(1.0, 0.5, 0.15), target_pos)
