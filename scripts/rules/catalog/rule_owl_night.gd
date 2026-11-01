class_name RuleOwlNight
extends RuleCard

# Puramente descritiva — a mecânica (ciclo dia/noite, névoa, passo duplo) vive
# em DuelBoss/Board/BoardRenderer. Existe pra dar o slot visual + tooltip.

func _init() -> void:
	id = "owl_night"
	boss_law = true
	name = "Noite da Coruja"
	description = "O dia e a noite se alternam a cada 3 rodadas. De noite, as pecas do chefe somem na neblina (so aparecem perto das suas) e ele anda 2 casas por passo. Elimine todo o exercito inimigo pra vencer."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
