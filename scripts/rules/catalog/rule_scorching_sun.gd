class_name RuleScorchingSun
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossDesert/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "scorching_sun"
	boss_law = true
	name = "Sol Escaldante"
	description = "Uma fileira do tabuleiro é marcada e, a cada 4 rodadas, entra em brasa por 2 rodadas: qualquer peça que POUSE numa casa em brasa é destruída (peças que já estão lá ficam). A próxima fileira aparece marcada. Elimine todo o exército inimigo pra vencer."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
