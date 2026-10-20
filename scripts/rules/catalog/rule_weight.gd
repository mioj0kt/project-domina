class_name RuleWeight
extends RuleCard

# Suas Damas ficam "pesadas": o passo simples vai só até 3 casas, mas em troca
# elas capturam de longe mesmo quando a casa atrás da vítima está ocupada (ou é
# a borda) — pousam na casa logo antes dela. A mecânica vive em Board
# (filter_king_range / king_lands_before_victim), consultada via RulePipeline.
const MAX_STEP_RANGE: int = 3

func _init() -> void:
	id = "weight"
	name = "Lei do Peso"
	description = "Suas Damas andam no máximo 3 casas, mas capturam de qualquer distancia mesmo sem casa livre atras da vítima (pousam na casa antes dela)."
	category = Category.MOVEMENT
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 12

func modify_king_range(_piece: BoardPiece, base_range: int) -> int:
	if base_range <= 0:
		return MAX_STEP_RANGE
	return mini(base_range, MAX_STEP_RANGE)

func king_lands_before_victim(_piece: BoardPiece) -> bool:
	return true
