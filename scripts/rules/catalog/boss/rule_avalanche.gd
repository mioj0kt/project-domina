class_name RuleAvalanche
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCume/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "avalanche"
	boss_law = true
	name = "Avalanche"
	description = "A cada 4 rodadas a neve desce por 1, 2 ou 3 diagonais (elas ficam marcadas 2 rodadas antes): todas as peças nelas escorregam uma casa morro abaixo, se a casa estiver livre. No alto de cada encosta fica um monte de neve que bloqueia a casa por 2 rodadas."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
