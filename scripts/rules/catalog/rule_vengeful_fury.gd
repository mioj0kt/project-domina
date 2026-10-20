class_name RuleVengefulFury
extends RuleCard

var bonus_active: bool = false

func _init() -> void:
	id = "vengeful_fury"
	name = "Fúria Vingativa"
	description = "Ao perder uma peça, a próxima peça sua a se mover ganha +1 casa de alcance de captura neste turno."
	category = Category.COMBO
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 18

func modify_capture_reach(_piece: BoardPiece, base_reach: int, _board: RefCounted) -> int:
	if bonus_active:
		return base_reach + 1
	return base_reach

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	match event_name:
		&"duel_started":
			bonus_active = false
		&"piece_lost":
			var victim: BoardPiece = context.get("piece")
			if victim and victim.owner_team == board.human_team_color:
				bonus_active = true
				board.rule_fired.emit(id)
		&"piece_captured":
			var attacker: BoardPiece = context.get("attacker")
			if attacker and attacker.owner_team == board.human_team_color:
				bonus_active = false
		&"step_moved":
			var mover: BoardPiece = context.get("piece")
			if mover and mover.owner_team == board.human_team_color:
				bonus_active = false
