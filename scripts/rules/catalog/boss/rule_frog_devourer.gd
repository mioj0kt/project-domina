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
	description = "De tempos em tempos, o sapo estica a língua nas casas com mosca e devora qualquer peça que estiver ali."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
