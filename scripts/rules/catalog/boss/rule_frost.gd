class_name RuleFrost
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCume/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "frost"
	boss_law = true
	name = "Geada"
	description = "Peça que passa 3 turnos do dono parada e sem nenhuma aliada colada na diagonal congela: não anda nem captura (mas pode ser capturada). Ela descongela quando uma aliada para colada nela. Vale para os dois lados."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
