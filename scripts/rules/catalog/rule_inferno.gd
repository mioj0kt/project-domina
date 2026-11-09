class_name RuleInferno
extends RuleCard

# O efeito vive em Board.ignite(): toda chama gerada pelo jogador (cartas e leis).
const EXTRA_TURNS: int = 2

func _init() -> void:
	id = "inferno"
	name = "Lei do Incêndio"
	description = "Todas as chamas que você gerar duram 2 turnos a mais."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 8
	incompatible_with = ["cinders"]
