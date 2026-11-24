class_name RuleAnvil
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCaldeira/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "anvil"
	boss_law = true
	name = "Bigorna"
	description = "Duas casas do meio são bigornas. A peça (sua ou do chefe) que começar a vez do dono numa bigorna quente é martelada e vira Dama na hora. Depois a bigorna esfria por 3 rodadas."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
