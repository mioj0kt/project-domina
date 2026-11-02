class_name RuleSoulMirror
extends RuleCard

var used: bool = false

func _init() -> void:
	id = "soul_mirror"
	name = "Espelho de Almas"
	description = "Na primeira vez que o inimigo coroar uma Dama no duelo, uma peça comum sua também é coroada. Vale só 1 vez."
	category = Category.PROMOTION
	scope = Scope.PLAYER_ONLY
	priority = 45

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name == &"duel_started":
		used = false
	elif event_name == &"on_promotion" and not used:
		var promoted_piece: BoardPiece = context.get("piece")
		if promoted_piece and promoted_piece.owner_team != board.human_team_color:
			for r in range(board.rows - 1, -1, -1):
				for c in range(board.cols):
					var p: BoardPiece = board.grid[r][c]
					if p != Board.EMPTY and p.owner_team == board.human_team_color and not p.is_king:
						p.is_king = true
						used = true
						board.rule_fired.emit(id)
						return
