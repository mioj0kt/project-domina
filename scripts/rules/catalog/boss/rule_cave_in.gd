class_name RuleCaveIn
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossMine/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "cave_in"
	boss_law = true
	name = "Desabamento"
	description = "A cada 4 rodadas o teto racha sobre algumas casas (elas ficam marcadas 2 rodadas antes). Quando desaba, a peça que estiver ali é destruída e a rocha fica na casa. Qualquer lado pode derrubar a rocha pulando por cima (opcional)."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
