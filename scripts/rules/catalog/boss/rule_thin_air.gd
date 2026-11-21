class_name RuleThinAir
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossCume/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "thin_air"
	boss_law = true
	name = "Ar Rarefeito"
	description = "Perto do cume falta fôlego: peça do jogador que termina a jogada nas 2 fileiras de cima (o lado do chefe) fica a próxima jogada parada, recuperando o ar. Nunca deixa o jogador sem nenhuma jogada."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
