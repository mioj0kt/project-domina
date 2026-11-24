class_name RuleBoilingCauldron
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCaldeira/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "boiling_cauldron"
	boss_law = true
	name = "Caldeirão Fervente"
	description = "Cada peça capturada (de qualquer lado) esquenta o caldeirão. Com 5, ele marca casas espalhadas pelo tabuleiro todo e, no fim da rodada, transborda: quem estiver nelas é destruído e elas viram brasa por %d rodadas (ninguém passa nem pousa)." % DuelBossCaldeira.CAULDRON_EMBER_ROUNDS
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
