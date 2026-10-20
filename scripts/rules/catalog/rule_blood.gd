class_name RuleBlood
extends RuleCard

var consecutive_captures: int = 0

func _init() -> void:
	id = "blood"
	name = "Sangue"
	description = "A cada captura consecutiva no mesmo turno, a peça se enfurece: ganha +1 casa de alcance de salto para a próxima captura."
	category = Category.COMBO
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.COMMON
	priority = 15

func modify_capture_reach(_piece: BoardPiece, base_reach: int, _board: RefCounted) -> int:
	return base_reach + consecutive_captures

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	match event_name:
		&"duel_started":
			consecutive_captures = 0
		&"piece_captured":
			var attacker: BoardPiece = context.get("attacker")
			if attacker and attacker.owner_team == board.human_team_color:
				consecutive_captures += 1
				board.rule_fired.emit(id)
		&"turn_started":
			consecutive_captures = 0
