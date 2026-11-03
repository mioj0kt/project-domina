class_name RuleHourglass
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "hourglass"
	boss_law = true
	name = "Ampulheta"
	description = "A cada 4 rodadas, a areia soterra mais uma coluna de cada lado (as próximas aparecem marcadas). O tabuleiro vai encolhendo."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
