class_name RulePowerCenter
extends RuleCard

func _init() -> void:
	id = "power_center"
	name = "Casas de Poder"
	description = "Suas peças paradas nas 4 casas centrais não podem ser capturadas por peças comuns inimigas."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	priority = 40
