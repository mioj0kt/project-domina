class_name RuleRails
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossMine/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "rails"
	boss_law = true
	name = "Trilhos"
	description = "Duas diagonais têm trilhos. A peça que parar na ponta de um trilho embarca na vagoneta e vai até a outra ponta, se ela estiver livre. Vale para os dois lados."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
