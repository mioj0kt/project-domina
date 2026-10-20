class_name RuleAdvance
extends RuleCard

func _init() -> void:
	id = "advance"
	name = "Investida"
	description = "Suas peças comuns podem andar ATÉ 2 casas por vez (1 ou 2, a sua escolha), desde que o caminho esteja livre. Não afeta capturas."
	category = Category.MOVEMENT
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 12

func modify_step_distance(piece: BoardPiece, base_distance: int, _board: RefCounted) -> int:
	if piece.is_king:
		return base_distance
	return base_distance + 1
