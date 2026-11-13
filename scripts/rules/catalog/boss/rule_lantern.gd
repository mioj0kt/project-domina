class_name RuleLantern
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossMine/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "lantern"
	boss_law = true
	name = "Lampião"
	description = "O lampião do chefe varre o tabuleiro, uma diagonal por vez, sempre para a do lado. A cada 2 rodadas ele acende: suas peças na diagonal iluminada ficam ofuscadas e perdem a próxima jogada. A diagonal da vez fica marcada."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
