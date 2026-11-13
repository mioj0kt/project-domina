class_name RuleNuggets
extends RuleCard

# Puramente descritiva — a mecânica vive em DuelBossMine/Board. Existe pra dar
# o slot visual + tooltip.

func _init() -> void:
	id = "nuggets"
	boss_law = true
	name = "Garimpo"
	description = "Pepitas aparecem em casas vazias. Quem pousar numa coleta. A cada 3 pepitas, o lado que coletou ganha uma Dama: a peça que pegou a 3ª vira Dama (ou a mais adiantada, se ela já for)."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0
