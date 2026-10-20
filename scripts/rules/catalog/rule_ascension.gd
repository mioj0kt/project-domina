class_name RuleAscension
extends RuleCard

# Puramente descritiva — a mecânica de verdade (moeda ao promover) está
# em duel_turn_controller.gd, checada logo depois de board.make_move()
# retornar promoted=true, igual outras leis com efeito de animação
# especial (coroação, etc.) são tratadas fora do RuleCard em si.
#
# scope = PLAYER_ONLY (padrão de "afeta minhas próprias peças" que TODA
# lei usa antes de ser sorteada) — mas o efeito de verdade em
# duel_turn_controller.gd usa o resultado INVERTIDO de applies_to_team().
# Isso é de propósito: quando o JOGADOR possui essa lei (scope continua
# PLAYER_ONLY), o invertido aponta pro time DELE, então ela mira o
# INIMIGO. Quando a IA possui (LootTables.get_random_ai_rules() já vira
# o scope pra AI_ONLY sozinho, igual faz com qualquer lei), o invertido
# passa a apontar pro time humano — ou seja, mira o JOGADOR. O mesmo
# truque que a Lei Escudo usa (fica a favor de quem a possui); aqui é só
# invertido porque essa Lei é contra quem NÃO a possui.
func _init() -> void:
	id = "ascension_law"
	name = "Lei da Ascensão"
	description = "Toda vez que uma peça INIMIGA for promovida a Dama, gire uma moeda: se cair na cor dela, promove normalmente. Senão, a peça não promove."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	priority = 8
