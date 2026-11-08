class_name RuleGoldenQueen
extends RuleCard

# Puramente descritiva: o efeito é aplicado pelo main.gd (apply_sudden_death_duel_rules
# no começo do duelo e _apply_sudden_death_start_laws quando a Morte Súbita liga).
# Só do jogador (não está em AI_ELIGIBLE_RULE_IDS).

func _init() -> void:
	id = "golden_queen"
	name = "Dama Dourada"
	description = "Na contagem da Morte Súbita, as suas Damas valem 5 pontos em vez de 3."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 6
