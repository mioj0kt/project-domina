class_name RuleFoundry
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCaldeira/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "foundry"
	boss_law = true
	name = "Fundição"
	description = "Cada peça que o chefe perde cai no caldeirão. A cada 3, a Ferreira derrama uma peça nova numa casa livre do fundo do lado dela (no máximo 2 por duelo)."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
