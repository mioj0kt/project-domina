class_name RuleAdrenaline
extends RuleCard

# Puramente descritiva: o efeito é aplicado pelo main.gd (apply_sudden_death_duel_rules
# no começo do duelo e _apply_sudden_death_start_laws quando a Morte Súbita liga).
# Só do jogador (não está em AI_ELIGIBLE_RULE_IDS).

func _init() -> void:
	id = "adrenaline"
	name = "Adrenalina"
	description = "Quando a Morte Súbita começa, compre 2 cartas."
	category = Category.TURN
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 6
