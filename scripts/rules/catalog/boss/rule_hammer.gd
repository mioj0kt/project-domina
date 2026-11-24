class_name RuleHammer
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCaldeira/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "hammer"
	boss_law = true
	name = "Martelada"
	description = "A cada 4 rodadas a Ferreira marca uma peça sua (a Dama mais adiantada; sem Dama, a peça mais adiantada) e o martelo segue ela por 2 rodadas. Se na hora ela estiver sem nenhuma aliada colada na diagonal, Dama perde a coroa (e o chefe ganha uma) e peça comum é esmagada."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
