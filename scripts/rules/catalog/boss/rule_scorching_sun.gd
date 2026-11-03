class_name RuleScorchingSun
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "scorching_sun"
	boss_law = true
	name = "Sol Escaldante"
	description = "Uma linha do tabuleiro (fileira, coluna ou diagonal) fica marcada e, a cada 4 rodadas, pega fogo por 2 rodadas. Peça que pousar numa casa em brasa é destruída (quem já estava lá fica). A próxima linha aparece marcada."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
