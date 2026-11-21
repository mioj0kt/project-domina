class_name RuleSlipperyIce
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCume/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "ice"
	boss_law = true
	name = "Gelo Escorregadio"
	description = "Há casas de gelo espalhadas por todo o tabuleiro. Quem PARA numa delas com um movimento simples escorrega mais uma casa na mesma direção, se a casa estiver livre (nunca até a fileira de coroação). Capturas não escorregam. Vale para os dois lados."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
