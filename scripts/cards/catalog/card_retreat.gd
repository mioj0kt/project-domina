class_name CardRetreat
extends ActionCard

func _init() -> void:
	id = "retreat"
	icon_path = "res://assets/sprites/cards/icons/retreat.png"
	name = "Recuar"
	description = "Permite que a peça selecionada recue uma casa na diagonal para trás neste turno (se estiver livre)."
	rarity = Rarity.COMMON
	target_type = TargetType.ALLY_PIECE

func execute(board: Board, target_pos: Vector2i, human_team: int, _context: Dictionary = {}) -> void:
	var back_dirs: Array[Vector2i]
	if human_team == board.human_team_color:
		back_dirs = [Vector2i(-1, 1), Vector2i(1, 1)]
	else:
		back_dirs = [Vector2i(-1, -1), Vector2i(1, -1)]
	board.grant_bonus_move(target_pos, back_dirs, 1)
