class_name RuleLavaFlow
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCaldeira/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "lava_flow"
	boss_law = true
	name = "Escorrida"
	description = "A cada 4 rodadas a lava brota no meio de uma coluna (a coluna e a fonte ficam marcadas 1 rodada antes) e escorre para cima e para baixo, uma casa no fim de cada turno do chefe. A peça que estiver na casa quando a lava chega é destruída, de qualquer lado. Depois a lava esfria em basalto, que bloqueia a casa por um tempo."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
