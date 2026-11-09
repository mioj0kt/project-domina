class_name RuleFrenzy
extends RuleCard

# Combo (2+ capturas seguidas) = turno extra. O controlador consome o turno extra
# em extra_turns_by_team (mesmo caminho da carta Segundo Turno).

func _init() -> void:
	id = "frenzy"
	name = "Lei do Frenesi"
	description = "Sempre que você termina um combo de 2 ou mais capturas seguidas, ganha um turno extra."
	category = Category.COMBO
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 16

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name != &"combo_ended":
		return
	var main_node = context.get("main")
	if main_node == null or not ("extra_turns_by_team" in main_node):
		return
	var team: int = board.human_team_color
	main_node.extra_turns_by_team[team] = main_node.extra_turns_by_team.get(team, 0) + 1
	board.rule_fired.emit(id)
