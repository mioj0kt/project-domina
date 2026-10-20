class_name RuleFaithfulCoin
extends RuleCard

# Depois do sorteio de cores do duelo, a PRÓXIMA moeda girada (de carta ou de
# Lei) cai na cor do jogador. Quem arma é DuelTurnController.on_coin_flip_completed
# (CoinFlipView.rigged_team); a moeda inicial não pode ser viciada porque é ela
# que decide qual é a cor do jogador.

func _init() -> void:
	id = "faithful_coin"
	name = "Lei da Moeda Fiel"
	description = "Depois do sorteio de cores, a primeira da partida será viciada"
	category = Category.TURN
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 70
