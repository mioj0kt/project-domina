class_name CardFortify
extends ActionCard

const DURATION_TURNS: int = 3

func _init() -> void:
	id = "fortify"
	icon_path = "res://assets/sprites/cards/icons/fortify.png"
	name = "Fortificar"
	description = "Bloqueia uma casa vazia por 3 turnos — nenhuma peça pode passar ou pousar nela enquanto ativo."
	rarity = Rarity.RARE
	target_type = TargetType.EMPTY_TILE

func execute(board: Board, target_pos: Vector2i, _human_team: int, _context: Dictionary = {}) -> void:
	board.scorched_tiles[target_pos] = DURATION_TURNS
