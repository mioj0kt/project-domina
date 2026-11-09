class_name RuleDomino
extends RuleCard

# Sempre que um combo (2+ capturas seguidas) termina, uma peça inimiga ao lado da
# casa onde ele terminou também cai. Sem limite de usos.

func _init() -> void:
	id = "domino"
	name = "Lei do Dominó"
	description = "Sempre que você termina um combo de 2 ou mais capturas, uma peça inimiga ao lado de onde ele terminou também é destruída."
	category = Category.COMBO
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 61

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name != &"combo_ended":
		return
	var pos: Vector2i = context.get("pos", Vector2i(-1, -1))
	if pos.x < 0:
		return
	for d in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var q: Vector2i = pos + d
		if not board.is_valid_pos(q.y, q.x):
			continue
		var target: BoardPiece = board.grid[q.y][q.x]
		if target == Board.EMPTY or target.is_tree or target.owner_team == board.human_team_color:
			continue
		if board.rule_pipeline != null and board.rule_pipeline.try_prevent_capture(target, board.human_team_color, board):
			continue
		board.grid[q.y][q.x] = Board.EMPTY
		board.piece_destroyed.emit(q, target)
		board.rule_fired.emit(id)
		return
