class_name RuleShockwave
extends RuleCard

func _init() -> void:
	id = "shockwave"
	name = "Onda de Choque"
	description = "Ao capturar uma peca com uma Dama, uma peca inimiga adjacente a casa de pouso tambem e destruida."
	category = Category.CAPTURE
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.LEGENDARY
	priority = 60

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name != &"piece_captured":
		return

	var attacker: BoardPiece = context.get("attacker")
	if attacker == null or attacker.owner_team != board.human_team_color or not attacker.is_king:
		return

	var landing_pos: Vector2i = context.get("attacker_pos")
	var dirs = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

	for d in dirs:
		var nr = landing_pos.y + d.y
		var nc = landing_pos.x + d.x
		if board.is_valid_pos(nr, nc):
			var target: BoardPiece = board.grid[nr][nc]
			if target != Board.EMPTY and target.owner_team != attacker.owner_team:
				board.grid[nr][nc] = Board.EMPTY
				board.piece_destroyed.emit(Vector2i(nc, nr), target)
				board.rule_fired.emit(id)
				return
