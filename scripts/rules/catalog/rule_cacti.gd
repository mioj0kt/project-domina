class_name RuleCacti
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "cacti"
	boss_law = true
	name = "Cactos"
	description = "A cada 3 rodadas nasce um cacto numa casa vazia. Ele bloqueia a casa. Qualquer lado pode derrubá-lo pulando por cima (opcional), mas a peça que pousar é destruída."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
