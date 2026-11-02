class_name RuleBlood
extends RuleCard

var consecutive_captures: int = 0
# Buff: o bônus sobrevive à virada do turno se você capturou neste turno, e só
# zera quando um turno passa sem captura.
var captured_this_turn: bool = false

func _init() -> void:
	id = "blood"
	name = "Sangue"
	description = "Cada captura sua dá +1 casa de alcance nos saltos seguintes. O bônus continua no turno seguinte e só zera se você passar um turno sem capturar."
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
			captured_this_turn = false
		&"piece_captured":
			var attacker: BoardPiece = context.get("attacker")
			if attacker and attacker.owner_team == board.human_team_color:
				consecutive_captures += 1
				captured_this_turn = true
				board.rule_fired.emit(id)
		&"turn_started":
			if not captured_this_turn:
				consecutive_captures = 0
			captured_this_turn = false
