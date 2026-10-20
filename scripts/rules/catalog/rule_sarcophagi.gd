class_name RuleSarcophagi
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "sarcophagi"
	boss_law = true
	name = "Sarcófagos"
	description = "A cada 3 rodadas surge um sarcófago numa casa vazia. Ele bloqueia o caminho, mas qualquer lado pode derrubá-lo pulando por cima (opcional, sem ouro) — e derrubar um sarcófago liberta uma múmia do chefe naquela casa. Elimine todo o exército inimigo pra vencer."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
