class_name CardBreathless
extends ActionCard

# Sem Fôlego: o ar do cume pesa sobre quem invadiu. Toda peça inimiga que está na
# SUA metade do tabuleiro fica parada no próximo turno dela (a mesma marca do Ar
# Rarefeito do chefe do Cume: BoardPiece.winded + rooted_turns). Nunca deixa o
# adversário sem nenhuma jogada: as mais recuadas são poupadas até sobrar uma.

func _init() -> void:
	id = "breathless"
	icon_path = "res://assets/sprites/cards/icons/breathless.png"
	name = "Sem Fôlego"
	description = "Toda peça inimiga que está na sua metade do tabuleiro fica parada no próximo turno dela. Nunca deixa o inimigo sem nenhuma jogada."
	rarity = Rarity.EPIC
	target_type = TargetType.NONE

func can_play(board: Board, team: int, _context: Dictionary = {}) -> bool:
	return not _invaders(board, team).is_empty()

# Peças do adversário dentro da metade de `team`, das mais avançadas para as mais recuadas.
static func _invaders(board: Board, team: int) -> Array:
	var out: Array = []
	var bottom: bool = team == board.human_team_color   # o jogador joga de baixo pra cima
	for r in range(board.rows):
		var in_half: bool = (r * 2 >= board.rows) if bottom else (r * 2 < board.rows)
		if not in_half:
			continue
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p == Board.EMPTY or p.owner_team == team or p.owner_team == Board.NEUTRAL or p.is_tree:
				continue
			if p.is_sarcophagus or p.is_cactus or p.is_rock:
				continue
			out.append(Vector2i(c, r))
	out.sort_custom(func(a, b): return (a.y > b.y) if bottom else (a.y < b.y))
	return out

func execute(board: Board, _target_pos: Vector2i, team: int, context: Dictionary = {}) -> void:
	var cells: Array = _invaders(board, team)
	var hit: Array = []
	for pos in cells:
		var p: BoardPiece = board.grid[pos.y][pos.x]
		var old_r: int = p.rooted_turns
		p.rooted_turns = maxi(p.rooted_turns, 1)
		if board.get_all_valid_moves(p.owner_team).is_empty():
			p.rooted_turns = old_r   # essa precisa ficar livre
			continue
		p.winded = true
		hit.append(pos)
	var main = context.get("main")
	if CardFx._ok(main):
		Sfx.play("vento_nascer")
		for pos in hit:
			var c := CardFx.center_of(main, pos)
			Juice.burst(main, c, Color(0.85, 0.93, 1.0), 6, 120.0, 0.45, maxf(2.0, main.cell_size / 26.0), -30.0, 80.0, Vector2.UP)
	if hit.is_empty():
		_pop_banner(context, "O AR NÃO PESOU", Color(0.7, 0.75, 0.85))
	else:
		_pop_banner(context, "SEM FÔLEGO! (%d)" % hit.size(), Color(0.8, 0.92, 1.0))
