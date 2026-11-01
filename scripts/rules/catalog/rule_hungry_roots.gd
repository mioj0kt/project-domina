class_name RuleHungryRoots
extends RuleCard

# Puramente descritiva — a mecânica (enraizar quem capturou) vive em
# DuelBoss/Board/DuelTurnController. Existe pra dar o slot visual + tooltip.

func _init() -> void:
	id = "hungry_roots"
	boss_law = true
	name = "Raízes Famintas"
	description = "Toda peça sua que captura fica enraizada: não pode se mover nos seus próximos 2 turnos. As peças do chefe não sofrem esse efeito. Elimine todo o exército inimigo pra vencer."
	category = Category.BOSS
	scope = Scope.PLAYER_ONLY
	priority = 1
	cost = 0
