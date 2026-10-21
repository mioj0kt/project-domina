class_name RuleCacti
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "cacti"
	boss_law = true
	name = "Cactos"
	description = "A cada 3 rodadas brota um cacto numa casa vazia. Ele bloqueia o caminho, mas qualquer lado pode derrubá-lo pulando por cima (opcional, sem ouro) — só que os espinhos matam a peça que o derrubou: ela é eliminada. Elimine todo o exército inimigo pra vencer."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
