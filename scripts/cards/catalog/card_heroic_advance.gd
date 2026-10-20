class_name CardHeroicAdvance
extends ActionCard

func _init() -> void:
	id = "heroic_advance"
	icon_path = "res://assets/sprites/cards/icons/heroic_advance.png"
	name = "Investida Heroica"
	description = "A peça escolhida pode andar 2 casas para frente neste turno (em vez de 1), se o caminho estiver livre."
	rarity = Rarity.COMMON
	target_type = TargetType.ALLY_PIECE

func execute(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> void:
	var fwd_dirs: Array[Vector2i]
	if human_team == board.human_team_color:
		fwd_dirs = [Vector2i(-1, -1), Vector2i(1, -1)]
	else:
		fwd_dirs = [Vector2i(-1, 1), Vector2i(1, 1)]
	board.grant_bonus_move(target_pos, fwd_dirs, 2)
