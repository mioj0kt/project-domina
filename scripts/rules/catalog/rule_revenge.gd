class_name RuleRevenge
extends RuleCard

var revenge_charges: int = 0

func _init() -> void:
	id = "revenge"
	name = "Vinganca"
	description = "Quando uma peca aliada e destruida, acumula 1 Carga de Vinganca. Sua proxima captura consome a carga para gerar +3 de Ouro e coroar o atacante a Dama imediatamente."
	category = Category.CAPTURE
	scope = Scope.PLAYER_ONLY
	priority = 25

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	match event_name:

		&"duel_started":
			revenge_charges = 0
		&"piece_lost":
			var victim: BoardPiece = context.get("piece")
			if victim and victim.owner_team == board.human_team_color:
				revenge_charges += 1

		&"piece_captured":
			var attacker: BoardPiece = context.get("attacker")
			if attacker and attacker.owner_team == board.human_team_color and revenge_charges > 0:
				revenge_charges -= 1
				if RunManager != null:
					RunManager.add_effect_gold(3)
				attacker.is_king = true
				board.rule_fired.emit(id)
