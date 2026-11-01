class_name RuleVines
extends RuleCard

# Puramente descritiva — a mecânica (cipós nas casas claras, travessia) vive em
# DuelBoss/Board. Existe pra dar o slot visual + tooltip.

func _init() -> void:
	id = "vines"
	boss_law = true
	name = "Cipós"
	description = "Cipós crescem nas casas claras e mudam de lugar a cada 4 rodadas. Uma peça ao lado de um cipó pode atravessá-lo: anda 2 casas em linha reta até o outro lado, se a casa estiver livre. Recuar pelo cipó só vale para quem pode andar para trás. Elimine todo o exército inimigo pra vencer."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
