class_name RuleCrownPrice
extends RuleCard

# Puramente descritiva — a mecânica vive em Board (crown_price_team). Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "crown_price"
	boss_law = true
	name = "Preço da Coroa"
	description = "Coroar custa caro: quando uma peça sua vira Dama, a sua peça comum mais atrasada derrete na forja da Ferreira (ela fica marcada com metal escorrendo). Se só sobrarem Damas, a coroa sai de graça. As coroações do chefe não pagam nada."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
