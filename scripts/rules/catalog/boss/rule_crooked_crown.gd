class_name RuleCrookedCrown
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCaldeira/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "crooked_crown"
	boss_law = true
	name = "Coroa Torta"
	description = "Suas Damas saem da coroação tortas: andam e capturam só 1 casa (para frente ou para trás) até fazerem a primeira captura. Aí ganham o acabamento e viram Dama completa. As Damas do chefe saem perfeitas."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
