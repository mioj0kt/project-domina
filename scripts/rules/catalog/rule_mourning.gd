class_name RuleMourning
extends RuleCard

# Quando uma peça sua é capturada, a peça aliada mais próxima ganha um escudo
# (BoardPiece.shield_turns): a PRÓXIMA captura contra ela falha. Dura até o fim
# do seu próximo turno (o escudo é descontado ao fim dos turnos do dono; 2 =
# cobre o turno do inimigo que vem logo depois do seu).
const SHIELD_DURATION: int = 2

func _init() -> void:
	id = "mourning"
	name = "Lei do Luto"
	description = "Quando uma peca sua e capturada, a peca aliada mais proxima ganha um escudo: a proxima captura contra ela falha. Dura ate o fim do seu proximo turno."
	category = Category.BOARD
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.RARE
	# Antes do Escudo (5): o escudo de peça é consumido primeiro, o do duelo fica guardado.
	priority = 4

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name != &"piece_lost":
		return
	var victim: BoardPiece = context.get("piece")
	var pos: Vector2i = context.get("pos", Vector2i(-1, -1))
	if victim == null or victim.is_tree or not applies_to_team(victim.owner_team, board.human_team_color):
		return

	var best_pos := Vector2i(-1, -1)
	var best_key := 9999
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p == Board.EMPTY or p.owner_team != victim.owner_team or p.is_tree or p.shield_turns > 0:
				continue
			var dx = absi(c - pos.x)
			var dy = absi(r - pos.y)
			# Chebyshev primeiro (vizinha na diagonal ganha de tudo), Manhattan desempata.
			var key = maxi(dx, dy) * 100 + dx + dy
			if key < best_key:
				best_key = key
				best_pos = Vector2i(c, r)
	if best_pos.x >= 0:
		board.grid[best_pos.y][best_pos.x].shield_turns = SHIELD_DURATION
		board.rule_fired.emit(id)

func try_prevent_capture(victim: BoardPiece, _board: RefCounted) -> bool:
	if victim.shield_turns > 0:
		victim.shield_turns = 0
		return true
	return false
