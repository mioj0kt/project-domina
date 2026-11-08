class_name RuleShortFuse
extends RuleCard

# Puramente descritiva: o efeito é aplicado pelo main.gd (apply_sudden_death_duel_rules
# no começo do duelo e _apply_sudden_death_start_laws quando a Morte Súbita liga).
# Só do jogador (não está em AI_ELIGIBLE_RULE_IDS).

func _init() -> void:
	id = "short_fuse"
	name = "Pavio Curto"
	description = "A Morte Súbita começa quando um lado fica com 3 peças ou menos, em vez de 1."
	category = Category.TURN
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.COMMON
	priority = 6
