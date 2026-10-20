class_name RuleQuicksand
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "quicksand"
	boss_law = true
	name = "Areia Movediça"
	description = "4 casas de areia movediça trocam de lugar a cada 4 rodadas. Quem POUSA numa delas fica preso e perde a próxima jogada (as suas peças e as do chefe). Elimine todo o exército inimigo pra vencer."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
