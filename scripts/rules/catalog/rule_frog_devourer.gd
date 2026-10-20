class_name RuleFrogDevourer
extends RuleCard

# Puramente descritiva — a mecânica de verdade (moscas, língua, hazard_tiles)
# já vive em DuelBoss/FrogBossAnimationView. Isso só existe pra dar um lugar
# visual (slot da HUD-espelho + tooltip) pra explicar o chefe, em vez do
# texto que antes aparecia acima do tabuleiro.

func _init() -> void:
	id = "frog_devourer"
	boss_law = true
	name = "Sapo Devorador"
	description = "A cada poucos turnos, o sapo estica a lingua nas casas com moscas, devorando qualquer peça que residir. Elimine todo o exército inimigo pra vencer este duelo."
	category = Category.BOARD
	scope = Scope.BOTH
	priority = 1
	cost = 0
