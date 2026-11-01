class_name RuleClosingForest
extends RuleCard

# Puramente descritiva — a mecânica (árvores neutras) vive em DuelBoss/Board.

func _init() -> void:
	id = "closing_forest"
	boss_law = true
	name = "A Floresta Fecha"
	description = "A cada 3 rodadas nasce uma arvore numa casa vazia. Arvores bloqueiam o caminho, mas qualquer lado pode derruba-las pulando por cima (opcional, sem ouro). Elimine todo o exercito inimigo pra vencer."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
