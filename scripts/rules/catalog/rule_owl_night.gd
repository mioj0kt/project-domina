class_name RuleOwlNight
extends RuleCard

# Puramente descritiva — a mecânica (ciclo dia/noite, névoa, passo duplo) vive
# em DuelBoss/Board/BoardRenderer. Existe pra dar o slot visual + tooltip.

func _init() -> void:
	id = "owl_night"
	boss_law = true
	name = "Noite da Coruja"
	description = "O dia e a noite se alternam a cada 3 rodadas. De noite, as peças do chefe somem na neblina (só aparecem perto das suas) e ele anda 2 casas por passo. Elimine todo o exército inimigo pra vencer."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
