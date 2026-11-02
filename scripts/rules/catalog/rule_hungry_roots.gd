class_name RuleHungryRoots
extends RuleCard

# Puramente descritiva — a mecânica (enraizar quem capturou) vive em
# DuelBoss/Board/DuelTurnController. Existe pra dar o slot visual + tooltip.

func _init() -> void:
	id = "hungry_roots"
	boss_law = true
	name = "Raízes Famintas"
	description = "Peça sua que captura fica enraizada e não se move nos próximos 2 turnos. As do chefe não sofrem isso."
	category = Category.BOSS
	scope = Scope.PLAYER_ONLY
	priority = 1
	cost = 0
