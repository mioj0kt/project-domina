class_name RuleFireflies
extends RuleCard

# Puramente descritiva — a mecânica (luzes nas casas claras, proteção contra
# captura) vive em DuelBoss/Board. Existe pra dar o slot visual + tooltip.

func _init() -> void:
	id = "fireflies"
	boss_law = true
	name = "Vaga-lumes"
	description = "Vaga-lumes andam pelas casas claras, 1 casa por rodada (o próximo passo aparece marcado). Peças ao lado de um vaga-lume não podem ser capturadas, suas ou do chefe."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
