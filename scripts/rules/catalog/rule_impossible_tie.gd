class_name RuleImpossibleTie
extends RuleCard

# Puramente descritiva — a mecânica de verdade (3 moedas ao iniciar a
# Morte Súbita) está em main.gd (_resolve_impossible_tie), chamada pelo
# DuelTurnController quando a Morte Súbita começa. Vale só pra quem POSSUI
# a Lei: scope = PLAYER_ONLY como toda lei (a IA recebe a cópia com
# scope = AI_ONLY em LootTables.get_random_ai_rules).
func _init() -> void:
	id = "impossible_tie_law"
	name = "Empate Impossível"
	description = "Ao começaar a Morte Subita, gira 3 moedas em sequencia: cada uma que cair na cor das suas peças promove uma peça comum aleatória sua a Dama."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	priority = 5
