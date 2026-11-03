class_name RuleSarcophagi
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "sarcophagi"
	boss_law = true
	name = "Sarcófagos"
	description = "A cada 3 rodadas surge um sarcófago numa casa vazia. Ele bloqueia a casa. Qualquer lado pode derrubá-lo pulando por cima (opcional), mas isso solta uma múmia do chefe ali (no máximo 3 por duelo)."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
