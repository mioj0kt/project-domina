class_name RuleClosingForest
extends RuleCard

# Puramente descritiva — a mecânica (árvores neutras) vive em DuelBoss/Board.

func _init() -> void:
	id = "closing_forest"
	boss_law = true
	name = "A Floresta Fecha"
	description = "A cada 3 rodadas nasce uma árvore numa casa vazia. Ela bloqueia a casa. Qualquer lado pode derrubá-la pulando por cima (opcional)."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
