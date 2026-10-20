class_name RuleClosingForest
extends RuleCard

# Puramente descritiva — a mecânica (árvores neutras) vive em DuelBoss/Board.

func _init() -> void:
	id = "closing_forest"
	boss_law = true
	name = "A Floresta Fecha"
	description = "A cada 3 rodadas nasce uma árvore numa casa vazia. Árvores bloqueiam o caminho, mas qualquer lado pode derruba-las pulando por cima. Elimine todo o exército inimigo pra vencer."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
