class_name RuleCounterAttack
extends RuleCard

# [LEI INIMIGA] Cada peça que o inimigo perde dá 1 carga (máx. 2). No turno
# seguinte, depois da jogada normal, a IA gasta as cargas num movimento extra
# com OUTRA peça (DuelTurnController.play_ai_turn consome via consume_charges).
const MAX_CHARGES: int = 2
var charges: int = 0

func _init() -> void:
	id = "counter_attack"
	name = "Contra-Ataque"
	description = "[LEI INIMIGA] Toda vez que o inimigo perde uma peça, ganha um movimento extra no turno seguinte (até 2 por turno)."
	category = Category.TURN
	scope = Scope.AI_ONLY
	priority = 55

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	match event_name:
		&"duel_started":
			charges = 0
		&"piece_lost":
			var victim: BoardPiece = context.get("piece")
			if victim != null and not victim.is_tree and applies_to_team(victim.owner_team, board.human_team_color):
				charges = mini(MAX_CHARGES, charges + 1)
				board.rule_fired.emit(id)

func consume_charges() -> int:
	var n = charges
	charges = 0
	return n
