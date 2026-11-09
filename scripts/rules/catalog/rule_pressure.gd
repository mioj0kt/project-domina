class_name RulePressure
extends RuleCard

# Ao capturar, a peça inimiga mais próxima de onde você pousou fica imobilizada
# por 1 turno do inimigo (nunca deixa o inimigo sem jogadas).
const ROOT_TURNS: int = 1

func _init() -> void:
	id = "pressure"
	name = "Lei da Pressão"
	description = "Quando você captura, a peça inimiga mais próxima de onde você pousou fica imobilizada no próximo turno do inimigo."
	category = Category.CAPTURE
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.COMMON
	priority = 40

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name != &"piece_captured":
		return
	var attacker: BoardPiece = context.get("attacker")
	var at: Vector2i = context.get("attacker_pos", Vector2i(-1, -1))
	if attacker == null or not applies_to_team(attacker.owner_team, board.human_team_color) or at.x < 0:
		return
	var best: BoardPiece = null
	var best_key := 99999
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p == Board.EMPTY or p.is_tree or p.owner_team == attacker.owner_team or p.rooted_turns > 0:
				continue
			var dx := absi(c - at.x)
			var dy := absi(r - at.y)
			var key := maxi(dx, dy) * 100 + dx + dy
			if key < best_key:
				best_key = key
				best = p
	if best == null:
		return
	best.rooted_turns = ROOT_TURNS
	# Nunca deixa o inimigo sem nenhuma jogada (mesma proteção da Areia Movediça).
	if not board.is_simulation and board.get_all_valid_moves(best.owner_team).is_empty():
		best.rooted_turns = 0
		return
	board.rule_fired.emit(id)
