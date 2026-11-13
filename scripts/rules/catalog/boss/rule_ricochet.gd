class_name RuleRicochet
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossMine/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "ricochet"
	boss_law = true
	name = "Ricochete"
	description = "Cristais nascem em casas vazias e bloqueiam a casa. Se uma captura fosse pousar num cristal, a peça ricocheteia na vítima e pousa na casa espelhada, podendo seguir a cadeia dali. Vale para os dois lados."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
