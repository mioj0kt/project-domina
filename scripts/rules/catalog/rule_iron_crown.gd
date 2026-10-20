class_name RuleIronCrown
extends RuleCard

func _init() -> void:
	id = "iron_crown"
	name = "Coroa de Ferro"
	description = "[LEI INIMIGA] Damas inimigas só podem ser capturadas por outras Damas."
	category = Category.CAPTURE
	scope = Scope.BOTH
	priority = 5
