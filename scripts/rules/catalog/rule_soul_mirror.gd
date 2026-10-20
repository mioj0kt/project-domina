class_name RuleSoulMirror
extends RuleCard

func _init() -> void:
	id = "soul_mirror"
	name = "Espelho de Almas"
	description = "Quando o inimigo coroa uma Dama, uma peça comum sua e coroada imediatamente."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	priority = 45

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name == &"on_promotion":
		var promoted_piece: BoardPiece = context.get("piece")
		if promoted_piece and promoted_piece.owner_team != board.human_team_color:
			for r in range(board.rows - 1, -1, -1):
				for c in range(board.cols):
					var p: BoardPiece = board.grid[r][c]
					if p != Board.EMPTY and p.owner_team == board.human_team_color and not p.is_king:
						p.is_king = true
						board.rule_fired.emit(id)
						return
