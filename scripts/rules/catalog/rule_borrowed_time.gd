class_name RuleBorrowedTime
extends RuleCard

# Puramente descritiva: o efeito é aplicado pelo main.gd (apply_sudden_death_duel_rules
# no começo do duelo e _apply_sudden_death_start_laws quando a Morte Súbita liga).
# Só do jogador (não está em AI_ELIGIBLE_RULE_IDS).

func _init() -> void:
	id = "borrowed_time"
	name = "Tempo Emprestado"
	description = "A Morte Súbita dura 3 turnos a mais."
	category = Category.TURN
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 6
