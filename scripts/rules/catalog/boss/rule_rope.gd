class_name RuleRope
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCume/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "rope"
	boss_law = true
	name = "Cordada"
	description = "Duas duplas de peças do chefe ficam amarradas e ele troca as duplas a cada 4 turnos dele (de preferência uma peça que você pode capturar e uma parceira que consegue revidar). Quando uma peça amarrada é capturada, a parceira é puxada para a casa dela, se estiver a até 3 casas, e uma corda nova é amarrada no lugar."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
