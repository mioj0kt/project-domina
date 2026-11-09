class_name RuleCharge
extends RuleCard

# Cada jogada sem captura acumula 1 carga (até 3). A próxima captura gasta tudo:
# +1 de alcance de salto por carga.
const MAX_CHARGES: int = 3
var charges: int = 0

func _init() -> void:
	id = "charge"
	name = "Lei da Carga"
	description = "Cada jogada sua sem captura dá 1 carga (até 3). Sua próxima captura gasta todas: +1 casa de alcance de salto por carga."
	category = Category.COMBO
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	priority = 18

func modify_capture_reach(_piece: BoardPiece, base_reach: int, _board: RefCounted) -> int:
	return base_reach + charges

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	match event_name:
		&"duel_started":
			charges = 0
		&"step_moved":
			var piece: BoardPiece = context.get("piece")
			if piece != null and piece.owner_team == board.human_team_color and charges < MAX_CHARGES:
				charges += 1
				board.rule_fired.emit(id)
		&"piece_captured":
			var attacker: BoardPiece = context.get("attacker")
			if attacker != null and attacker.owner_team == board.human_team_color:
				charges = 0
