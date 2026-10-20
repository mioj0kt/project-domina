class_name RuleSandstorm
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "sandstorm"
	boss_law = true
	name = "Tempestade de Areia"
	description = "A cada 3 rodadas a areia cobre 4 casas vazias por 2 rodadas: ninguém pode passar nem pousar nelas (as próximas aparecem marcadas). Elimine todo o exército inimigo pra vencer."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
