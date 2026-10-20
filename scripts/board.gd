class_name Board
extends RefCounted

signal piece_destroyed(grid_pos: Vector2i, piece: BoardPiece)
# Uma Lei (ex: Escudo) impediu a captura desta peça — a peça continua no tabuleiro.
signal capture_prevented(grid_pos: Vector2i, piece: BoardPiece)
# Uma Lei acabou de agir (id da Lei): a HUD faz o slot dela tremer/brilhar (game juice).
signal rule_fired(rule_id: String)

const EMPTY: BoardPiece = null
const NEUTRAL: int = 0
const WHITE: int = 1
const BLACK: int = 2

var rows: int = 8
var cols: int = 8
var grid: Array = []

var human_team_color: int = WHITE
var ai_team_color: int = BLACK
var rule_pipeline: RulePipeline = null

# true nos tabuleiros clonados pra simulação (IA / Profecia). Simulações NÃO
# disparam eventos nem consomem efeitos das Leis: elas compartilham o mesmo
# RulePipeline do jogo real, e Leis têm estado (cargas, escudo usado) e
# efeitos externos (ouro) que não podem vazar de uma jogada hipotética.
var is_simulation: bool = false

# true se o ÚLTIMO make_move foi uma captura que uma Lei (Escudo) impediu.
var last_capture_prevented: bool = false

# Peça que acabou de ser salva por uma Lei (Escudo): o time atacante não pode
# encadear uma nova captura nela no resto do turno (uma Dama que pousou além
# dela a recapturaria na hora). Expira quando o outro time se move.
var _protected_piece: BoardPiece = null
var _protected_attacker_team: int = 0

# Casas bloqueadas (Fortificar): Vector2i(col, row) -> turnos restantes.
var scorched_tiles: Dictionary = {}

# Casas em chamas (Terra Queimada): Vector2i(col, row) -> turnos restantes.
# Diferente de scorched_tiles (que BLOQUEIA a casa), aqui a casa é livre para
# andar, mas qualquer peça que POUSE nela é destruída.
var fire_tiles: Dictionary = {}

# Casas claras acesas (carta Acender Casa): Vector2i(col, row) ->
# {"turns": turnos restantes, "team": time protegido}. As peças DESSE time nas
# 4 casas escuras de lado ficam protegidas contra captura (mesma proteção do
# vaga-lume do chefe, mas só para quem acendeu).
var lit_tiles: Dictionary = {}

# Disposição inicial das peças (ver layout_cells) e quantas cada lado começa tendo.
var layout_id: String = LAYOUT_CLASSIC
var initial_piece_count: int = 0

# Última Chance: peça que o jogador já salvou (moeda) antes de make_move; a
# captura dela falha uma vez, como no Escudo (o atacante pousa, ela fica).
var last_chance_piece: BoardPiece = null

# Dama Voadora: peça que ainda pode fazer um 2º movimento neste turno.
var extra_move_piece: BoardPiece = null

# Time que, ENQUANTO durar, pode andar 2 casas (caminho livre) além do passo
# normal — usado pela Noite da Coruja. 0 = ninguém.
var night_boost_team: int = 0

# Movimentos bônus concedidos por cartas (Investida Heroica, Recuar), válidos
# só até o próximo movimento: Vector2i(col, row) da peça -> {"dirs", "distance"}.
var bonus_moves: Dictionary = {}

# --- Leis do Chefe da Floresta que usam as casas CLARAS ((r+c) par) ---
# Cipós: Vector2i(col, row) -> true. Uma peça ao lado de um cipó pode atravessá-lo
# (2 casas em linha reta) até a casa escura do outro lado, se estiver livre.
var vine_tiles: Dictionary = {}
# Vaga-lumes: Vector2i(col, row) -> true. Peças nas 4 casas vizinhas (lados) de
# um vaga-lume não podem ser capturadas.
var firefly_tiles: Dictionary = {}
# Raízes Famintas: time cujas peças ficam enraizadas (sem mover no próximo turno)
# depois de capturar. 0 = lei inativa. _capturers guarda quem capturou no turno.
var hungry_roots_team: int = 0
# Quantos turnos (do próprio time) a peça fica enraizada depois de capturar.
const HUNGRY_ROOTS_TURNS: int = 2
var _capturers: Array = []

var light_tile_color: Color = Color(0.92, 0.92, 0.94)
var dark_tile_color: Color = Color(0.18, 0.20, 0.26)
var grid_border_color: Color = Color(0.12, 0.14, 0.18, 0.4)

# Tingimento multiplicado sobre o sprite de madeira (BoardSkin), branco =
# sem alteração. Usado só quando existe assets/sprites/board/board_frame_8x8.png;
# quando não existe, o desenho cai de volta pras cores acima (retângulos
# lisos) e esses tints são ignorados.
# Estilo visual do tabuleiro (ver BoardSkin): madeira nos duelos da Floresta,
# "tutorial" nos duelos do tutorial.
var skin_id: String = BoardSkin.SKIN_WOOD
var light_tile_tint: Color = Color(1, 1, 1)
var dark_tile_tint: Color = Color(1, 1, 1)
var frame_tint: Color = Color(1, 1, 1)

func _init(p_rows: int = 8, p_cols: int = 8) -> void:
	rows = p_rows
	cols = p_cols
	grid = []
	for r in range(rows):
		var row_arr = []
		for c in range(cols):
			row_arr.append(EMPTY)
		grid.append(row_arr)

func set_rule_pipeline(pipeline: RulePipeline) -> void:
	rule_pipeline = pipeline

func set_theme_for_duel(is_hard_or_boss: bool) -> void:
	if is_hard_or_boss:
		light_tile_color = Color(0.24, 0.16, 0.18)
		dark_tile_color = Color(0.12, 0.08, 0.09)
		grid_border_color = Color(0.35, 0.10, 0.12, 0.6)
		# Escurece e puxa pro vermelho sobre o sprite de madeira, sem
		# apagar a textura (tint multiplicativo, não substitui a cor).
		light_tile_tint = Color(0.85, 0.55, 0.55)
		dark_tile_tint = Color(0.55, 0.30, 0.32)
		frame_tint = Color(0.9, 0.65, 0.65)
	else:
		light_tile_color = Color(0.90, 0.91, 0.94)
		dark_tile_color = Color(0.16, 0.18, 0.24)
		grid_border_color = Color(0.08, 0.10, 0.14, 0.4)
		light_tile_tint = Color(1, 1, 1)
		dark_tile_tint = Color(1, 1, 1)
		frame_tint = Color(1, 1, 1)

func clear_board() -> void:
	for r in range(rows):
		for c in range(cols):
			grid[r][c] = EMPTY
	scorched_tiles.clear()
	fire_tiles.clear()
	lit_tiles.clear()
	last_chance_piece = null
	extra_move_piece = null
	bonus_moves.clear()
	night_boost_team = 0
	vine_tiles.clear()
	firefly_tiles.clear()
	hungry_roots_team = 0
	_capturers.clear()

# Concede à peça em `pos` a possibilidade de andar `distance` casas (caminho
# livre) nas direções `dirs` neste turno, além dos movimentos normais.
func grant_bonus_move(pos: Vector2i, dirs: Array[Vector2i], distance: int = 1) -> void:
	bonus_moves[pos] = {"dirs": dirs.duplicate(), "distance": distance}

func clear_bonus_moves() -> void:
	bonus_moves.clear()

# Chamado uma vez por rodada completa: desconta 1 turno de cada casa
# bloqueada e libera as que chegaram a zero.
func tick_scorched_tiles() -> void:
	for pos in scorched_tiles.keys():
		scorched_tiles[pos] -= 1
		if scorched_tiles[pos] <= 0:
			scorched_tiles.erase(pos)
	for pos in fire_tiles.keys():
		fire_tiles[pos] -= 1
		if fire_tiles[pos] <= 0:
			fire_tiles.erase(pos)
	for pos in lit_tiles.keys():
		lit_tiles[pos]["turns"] -= 1
		if lit_tiles[pos]["turns"] <= 0:
			lit_tiles.erase(pos)

# Chamado ao fim do turno de `team`: desconta os efeitos temporários DAS PEÇAS
# DELE (Emboscada, Herdeiro). Devolve eventos [{"type", "pos"}] pra a UI avisar.
func tick_piece_effects(team: int) -> Array:
	var events: Array = []
	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p == EMPTY or p.owner_team != team:
				continue
			if p.rooted_turns > 0:
				p.rooted_turns -= 1
			if p.shield_turns > 0:
				p.shield_turns -= 1
			if p.temp_king_turns > 0:
				p.temp_king_turns -= 1
				if p.temp_king_turns == 0:
					p.is_king = false
					events.append({"type": "heir_expired", "pos": Vector2i(c, r)})
	return events

# Fileiras de cada lado na formação clássica. Tamanhos ímpares deixam sempre 3
# fileiras livres no meio (7x7 -> 2, 9x9 -> 3).
static func deploy_rows_for(total_rows: int) -> int:
	if total_rows % 2 == 1:
		@warning_ignore("integer_division")
		return maxi(1, (total_rows - 3) / 2)
	if total_rows <= 6:
		return 1
	elif total_rows <= 8:
		return 3
	elif total_rows <= 10:
		return 4
	return 5

func get_max_deployment_rows() -> int:
	return deploy_rows_for(rows)

# ---------------------------------------------------------------------
# Disposições iniciais (layouts). Cada uma descreve só o lado do INIMIGO (topo);
# o jogador é a rotação de 180° dela, então os dois lados sempre começam iguais.
# ---------------------------------------------------------------------
const LAYOUT_CLASSIC := "classic"
const LAYOUT_SKIRMISH := "skirmish"
const LAYOUT_FLANKS := "flanks"
const LAYOUT_PYRAMID := "pyramid"
const LAYOUT_SPARSE := "sparse"
const LAYOUT_ROYAL := "royal"
const LAYOUT_DOUBLE := "double"
const LAYOUT_IDS: Array[String] = [LAYOUT_CLASSIC, LAYOUT_SKIRMISH, LAYOUT_FLANKS, LAYOUT_PYRAMID, LAYOUT_SPARSE, LAYOUT_ROYAL, LAYOUT_DOUBLE]
const LAYOUT_MIN_PIECES: int = 4

static func layout_name(id: String) -> String:
	match id:
		LAYOUT_SKIRMISH: return "Escaramuça"
		LAYOUT_FLANKS: return "Flancos"
		LAYOUT_PYRAMID: return "Pirâmide"
		LAYOUT_SPARSE: return "Esparso"
		LAYOUT_ROYAL: return "Realeza"
		LAYOUT_DOUBLE: return "Duas Fileiras"
	return "Clássico"

static func layout_description(id: String) -> String:
	match id:
		LAYOUT_SKIRMISH: return "Cada lado começa com uma fileira a menos: mais espaço no meio."
		LAYOUT_FLANKS: return "As peças ficam só nas laterais; o centro começa vazio."
		LAYOUT_PYRAMID: return "Fundo cheio e frente estreita, em forma de pirâmide."
		LAYOUT_SPARSE: return "Metade das peças, espalhadas em xadrez."
		LAYOUT_ROYAL: return "Cada lado começa com uma Dama no fundo."
		LAYOUT_DOUBLE: return "Cada lado começa com duas fileiras de peças."
	return "Formação padrão."

# Casas do lado do inimigo: {"pieces": Array[Vector2i(col,row)], "kings": Array[Vector2i]}.
static func layout_cells(id: String, total_rows: int, total_cols: int) -> Dictionary:
	var d: int = deploy_rows_for(total_rows)
	var rows_used: int = d
	if id == LAYOUT_SKIRMISH and d >= 2:
		rows_used = d - 1
	# Duas Fileiras: só onde a clássica tem 1 fileira e ainda sobram 2 livres no meio.
	if id == LAYOUT_DOUBLE:
		rows_used = d + 1 if (d == 1 and total_rows >= 6) else 0
	var pieces: Array[Vector2i] = []
	var kings: Array[Vector2i] = []
	@warning_ignore("integer_division")
	var flank_w: int = maxi(2, total_cols / 4)
	for r in range(rows_used):
		for c in range(total_cols):
			if (r + c) % 2 != 1:
				continue
			match id:
				LAYOUT_FLANKS:
					if c >= flank_w and c < total_cols - flank_w:
						continue
				LAYOUT_PYRAMID:
					if c < r or c > total_cols - 1 - r:
						continue
				LAYOUT_SPARSE:
					@warning_ignore("integer_division")
					if (c / 2 + r) % 2 != 0:
						continue
			pieces.append(Vector2i(c, r))
	if id == LAYOUT_ROYAL and not pieces.is_empty():
		var back: Array[Vector2i] = []
		for v in pieces:
			if v.y == 0:
				back.append(v)
		if not back.is_empty():
			@warning_ignore("integer_division")
			kings.append(back[back.size() / 2])
	return {"pieces": pieces, "kings": kings}

# Disposições que servem para um tamanho (peças suficientes e diferentes da clássica).
static func layouts_for_size(total_rows: int, total_cols: int) -> Array[String]:
	var out: Array[String] = []
	var classic_n: int = layout_cells(LAYOUT_CLASSIC, total_rows, total_cols)["pieces"].size()
	for id in LAYOUT_IDS:
		if id == LAYOUT_CLASSIC:
			continue
		var n: int = layout_cells(id, total_rows, total_cols)["pieces"].size()
		# Precisa ter peças demais pra jogar e ser de fato diferente da clássica.
		if n < LAYOUT_MIN_PIECES:
			continue
		if id != LAYOUT_ROYAL and id != LAYOUT_DOUBLE and n >= classic_n:
			continue
		if id == LAYOUT_DOUBLE and n <= classic_n:
			continue
		out.append(id)
	return out

func setup_match(human_team: int, ai_team: int) -> void:
	clear_board()
	human_team_color = human_team
	ai_team_color = ai_team

	var cells: Dictionary = layout_cells(layout_id, rows, cols)
	for pos in cells["pieces"]:
		var is_royal: bool = cells["kings"].has(pos)
		var ai_piece := BoardPiece.new(ai_team, is_royal)
		var human_piece := BoardPiece.new(human_team, is_royal)
		if is_royal:
			# Dama inicial não ativa a Morte Súbita (igual à Guarda Real).
			ai_piece.sd_exempt = true
			human_piece.sd_exempt = true
		grid[pos.y][pos.x] = ai_piece
		# Lado do jogador = rotação de 180° (mantém a paridade das casas escuras).
		grid[rows - 1 - pos.y][cols - 1 - pos.x] = human_piece
	initial_piece_count = cells["pieces"].size()

func is_valid_pos(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols

func is_center_tile(r: int, c: int) -> bool:
	@warning_ignore("integer_division")
	var mid_r = rows / 2
	@warning_ignore("integer_division")
	var mid_c = cols / 2
	# Tamanho ímpar: o meio exato é uma casa clara; o "centro" vira as 4 casas
	# escuras coladas nela (losango), simétrico para os dois lados.
	if rows % 2 == 1 and cols % 2 == 1:
		return absi(r - mid_r) + absi(c - mid_c) == 1
	return (r == mid_r or r == mid_r - 1) and (c == mid_c or c == mid_c - 1)

func get_all_valid_moves(team: int) -> Array:
	var moves: Array = []
	var captures: Array = []

	for r in range(rows):
		for c in range(cols):
			var piece: BoardPiece = grid[r][c]
			if piece != EMPTY and piece.owner_team == team:
				# get_piece_captures também devolve "saltos camarada" (Lei Salto
				# Camarada), que NÃO são capturas: não podem tornar a captura
				# obrigatória, valem como movimentos comuns.
				for m in get_piece_captures(r, c):
					# Capturar árvore é opcional: nunca torna a captura obrigatória.
					if m["is_capture"] and not m.get("optional", false):
						captures.append(m)
					else:
						moves.append(m)
				moves.append_array(get_piece_moves(r, c))

	var capture_mandatory = true
	if rule_pipeline != null:
		capture_mandatory = rule_pipeline.is_capture_mandatory(team, human_team_color)

	if capture_mandatory and not captures.is_empty():
		return captures

	return captures + moves

# Vaga-lume ao lado (nos 4 lados) = peça protegida contra captura.
func is_firefly_protected(pos: Vector2i) -> bool:
	if firefly_tiles.is_empty() and lit_tiles.is_empty():
		return false
	var occupant: BoardPiece = grid[pos.y][pos.x] if is_valid_pos(pos.y, pos.x) else EMPTY
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if firefly_tiles.has(pos + d):
			return true
		if lit_tiles.has(pos + d) and occupant != EMPTY and occupant.owner_team == lit_tiles[pos + d]["team"]:
			return true
	return false

# Raízes Famintas: ao fim do turno de `team`, enraíza (HUNGRY_ROOTS_TURNS) as peças dele que
# capturaram. Devolve as casas enraizadas. Nunca deixa o time sem nenhuma jogada
# por causa disso (senão a captura final viraria derrota por bloqueio).
func apply_hungry_roots(team: int) -> Array:
	var rooted: Array = []
	if _capturers.is_empty():
		return rooted
	var mine: Array = _capturers.filter(func(p): return p.owner_team == team)
	_capturers = _capturers.filter(func(p): return p.owner_team != team)
	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p != EMPTY and mine.has(p):
				p.rooted_turns = HUNGRY_ROOTS_TURNS
				rooted.append(Vector2i(c, r))
	if not rooted.is_empty() and get_all_valid_moves(team).is_empty():
		for pos in rooted:
			grid[pos.y][pos.x].rooted_turns = 0
		return []
	return rooted

func get_piece_captures(r: int, c: int) -> Array:
	var captures: Array = []
	var piece_obj: BoardPiece = grid[r][c]
	if piece_obj == EMPTY:
		return captures

	if piece_obj.rooted_turns > 0:
		return captures

	var is_king: bool = piece_obj.is_king
	var moves_up: bool = (piece_obj.owner_team == human_team_color)

	var capture_dirs: Array[Vector2i] = []
	var can_capture_backwards = is_king

	if rule_pipeline != null and rule_pipeline.can_capture_backwards(piece_obj, human_team_color):
		can_capture_backwards = true

	if can_capture_backwards:
		capture_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	else:
		if moves_up:
			capture_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1)])
		else:
			capture_dirs.append_array([Vector2i(-1, 1), Vector2i(1, 1)])

	if is_king:
		var lands_before: bool = rule_pipeline != null and rule_pipeline.king_lands_before_victim(piece_obj, human_team_color)
		# Dama voadora: captura uma peça inimiga a qualquer distância na
		# diagonal (desde que o caminho até ela esteja livre) e pode pousar
		# em qualquer casa vazia logo depois dela, não só na adjacente.
		for d in capture_dirs:
			var dist = 1
			while true:
				var cr = r + d.y * dist
				var cc = c + d.x * dist
				if not is_valid_pos(cr, cc) or scorched_tiles.has(Vector2i(cc, cr)):
					break
				var occupant: BoardPiece = grid[cr][cc]
				if occupant == EMPTY:
					dist += 1
					continue
				if occupant.owner_team == piece_obj.owner_team:
					break
				if occupant == _protected_piece and piece_obj.owner_team == _protected_attacker_team:
					break
				if not occupant.is_tree and is_firefly_protected(Vector2i(cc, cr)):
					break
				var captured_pos = Vector2i(cc, cr)
				var landing_dist = dist + 1
				while true:
					var lr = r + d.y * landing_dist
					var lc = c + d.x * landing_dist
					if not is_valid_pos(lr, lc) or scorched_tiles.has(Vector2i(lc, lr)) or grid[lr][lc] != EMPTY:
						break
					captures.append({
						"from": Vector2i(c, r),
						"to": Vector2i(lc, lr),
						"is_capture": true,
						"captured": captured_pos,
						"optional": occupant.is_tree
					})
					landing_dist += 1
				# Lei do Peso: também pode pousar na casa logo ANTES da vítima
				# (precisa ter andado pelo menos 1 casa livre).
				if lands_before and dist >= 2:
					captures.append({
						"from": Vector2i(c, r),
						"to": Vector2i(c + d.x * (dist - 1), r + d.y * (dist - 1)),
						"is_capture": true,
						"captured": captured_pos,
						"optional": occupant.is_tree
					})
				break
		return captures

	var can_hop_allies: bool = (rule_pipeline != null and rule_pipeline.can_hop_allies(piece_obj, human_team_color))
	var has_power_center = rule_pipeline != null and rule_pipeline.has_rule("power_center")
	var has_iron_crown = rule_pipeline != null and rule_pipeline.has_rule("iron_crown")

	# Alcance de salto (1 = peça adjacente). Leis como Sangue e Fúria Vingativa
	# aumentam: o inimigo pode estar a até `reach` casas na diagonal, com o
	# caminho até ele livre, e a peça pousa na casa logo depois dele.
	var reach: int = 1
	if rule_pipeline != null:
		reach = max(1, rule_pipeline.filter_capture_reach(piece_obj, 1, human_team_color, self))

	for d in capture_dirs:
		for dist in range(1, reach + 1):
			var cap_r: int = r + d.y * dist
			var cap_c: int = c + d.x * dist
			var landing_r: int = r + d.y * (dist + 1)
			var landing_c: int = c + d.x * (dist + 1)

			if not is_valid_pos(cap_r, cap_c) or scorched_tiles.has(Vector2i(cap_c, cap_r)):
				break

			var target: BoardPiece = grid[cap_r][cap_c]
			if target == EMPTY:
				continue # casa livre: o alcance estendido continua pra frente

			# Primeira peça no caminho: ou é capturável aqui, ou bloqueia a linha.
			if not is_valid_pos(landing_r, landing_c) or grid[landing_r][landing_c] != EMPTY or scorched_tiles.has(Vector2i(landing_c, landing_r)):
				break

			if target == _protected_piece and piece_obj.owner_team == _protected_attacker_team:
				break

			if target.owner_team != piece_obj.owner_team:
				# Vaga-lume ao lado: a peça não pode ser capturada (árvores não contam).
				if not target.is_tree and is_firefly_protected(Vector2i(cap_c, cap_r)):
					break
				# Validação RulePowerCenter: Alvo aliado no centro imune a peças inimigas comuns
				if has_power_center and target.owner_team == human_team_color and is_center_tile(cap_r, cap_c) and not is_king:
					break

				# Validação RuleIronCrown: Damas inimigas imunes a peças não-damas
				if has_iron_crown and target.owner_team != human_team_color and target.is_king and not is_king:
					break

				captures.append({
					"from": Vector2i(c, r),
					"to": Vector2i(landing_c, landing_r),
					"is_capture": true,
					"captured": Vector2i(cap_c, cap_r),
					"optional": target.is_tree
				})
			elif can_hop_allies and dist == 1:
				captures.append({
					"from": Vector2i(c, r),
					"to": Vector2i(landing_c, landing_r),
					"is_capture": false,
					"captured": Vector2i(-1, -1)
				})
			break

	return captures

func get_piece_moves(r: int, c: int) -> Array:
	var moves: Array = []
	var piece_obj: BoardPiece = grid[r][c]
	if piece_obj == EMPTY:
		return moves

	if piece_obj.rooted_turns > 0:
		return moves

	var is_king: bool = piece_obj.is_king
	var moves_up: bool = (piece_obj.owner_team == human_team_color)

	var directions: Array[Vector2i] = []
	if is_king:
		directions.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
	else:
		if moves_up:
			directions.append_array([Vector2i(-1, -1), Vector2i(1, -1)])
		else:
			directions.append_array([Vector2i(-1, 1), Vector2i(1, 1)])

	if rule_pipeline != null:
		var filtered = rule_pipeline.filter_move_directions(piece_obj, directions, human_team_color, self)
		directions = Array(filtered, TYPE_VECTOR2I, "", null)

	if is_king:
		# Dama voadora: anda quantas casas quiser em linha reta na diagonal,
		# parando na primeira casa ocupada (ou "queimada") no caminho.
		# Lei do Peso limita o alcance (max_range > 0).
		var max_range: int = 0
		if rule_pipeline != null:
			max_range = rule_pipeline.filter_king_range(piece_obj, human_team_color)
		for d in directions:
			var dist = 1
			while true:
				if max_range > 0 and dist > max_range:
					break
				var nr: int = r + (d.y * dist)
				var nc: int = c + (d.x * dist)
				if not is_valid_pos(nr, nc) or scorched_tiles.has(Vector2i(nc, nr)) or grid[nr][nc] != EMPTY:
					break
				moves.append({
					"from": Vector2i(c, r),
					"to": Vector2i(nc, nr),
					"is_capture": false,
					"captured": Vector2i(-1, -1)
				})
				dist += 1
		_append_vine_moves(r, c, piece_obj, directions, moves)
		return moves

	var step_dist: int = 1
	if rule_pipeline != null:
		step_dist = rule_pipeline.filter_step_distance(piece_obj, step_dist, human_team_color, self)

	for d in directions:
		var nr: int = r + (d.y * step_dist)
		var nc: int = c + (d.x * step_dist)

		if is_valid_pos(nr, nc) and grid[nr][nc] == EMPTY and not scorched_tiles.has(Vector2i(nc, nr)):
			moves.append({
				"from": Vector2i(c, r),
				"to": Vector2i(nc, nr),
				"is_capture": false,
				"captured": Vector2i(-1, -1)
			})

	if night_boost_team != 0 and piece_obj.owner_team == night_boost_team:
		_append_double_steps(r, c, directions, moves)

	_append_bonus_moves(r, c, moves)
	_append_vine_moves(r, c, piece_obj, directions, moves)
	return moves

# Cipós: a peça ao lado de um cipó (casa clara) atravessa em linha reta até a casa
# escura do outro lado. Na horizontal vale sempre; na vertical, ir "para trás"
# só vale para quem pode andar para trás (Dama, ou uma Lei/efeito que dê a
# direção de recuo).
func _append_vine_moves(r: int, c: int, piece_obj: BoardPiece, dirs: Array, moves: Array) -> void:
	if vine_tiles.is_empty():
		return
	var forward_dy: int = -1 if piece_obj.owner_team == human_team_color else 1
	var can_go_back: bool = piece_obj.is_king
	if not can_go_back:
		for d in dirs:
			if d.y == -forward_dy:
				can_go_back = true
				break
	for od in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not vine_tiles.has(Vector2i(c + od.x, r + od.y)):
			continue
		if od.y == -forward_dy and not can_go_back:
			continue
		var dest := Vector2i(c + od.x * 2, r + od.y * 2)
		if not is_valid_pos(dest.y, dest.x) or grid[dest.y][dest.x] != EMPTY or scorched_tiles.has(dest):
			continue
		var listed := false
		for m in moves:
			if m["to"] == dest:
				listed = true
				break
		if listed:
			continue
		moves.append({"from": Vector2i(c, r), "to": dest, "is_capture": false, "captured": Vector2i(-1, -1), "via_vine": true})

# Passo duplo (Noite da Coruja): 2 casas na diagonal com as duas livres.
func _append_double_steps(r: int, c: int, dirs: Array[Vector2i], moves: Array) -> void:
	for d in dirs:
		var mid = Vector2i(c + d.x, r + d.y)
		var dest = Vector2i(c + d.x * 2, r + d.y * 2)
		if not is_valid_pos(dest.y, dest.x) or not is_valid_pos(mid.y, mid.x):
			continue
		if grid[mid.y][mid.x] != EMPTY or grid[dest.y][dest.x] != EMPTY:
			continue
		if scorched_tiles.has(mid) or scorched_tiles.has(dest):
			continue
		var listed = false
		for m in moves:
			if m["to"] == dest:
				listed = true
				break
		if listed:
			continue
		moves.append({"from": Vector2i(c, r), "to": dest, "is_capture": false, "captured": Vector2i(-1, -1)})

# Movimentos extras de cartas (ver grant_bonus_move). Só vale se todas as
# casas do caminho estiverem livres; ignora destinos que já existem na lista.
func _append_bonus_moves(r: int, c: int, moves: Array) -> void:
	var bonus = bonus_moves.get(Vector2i(c, r))
	if bonus == null:
		return

	var distance: int = bonus["distance"]
	for d in bonus["dirs"]:
		var path_clear = true
		for step in range(1, distance + 1):
			var pr: int = r + d.y * step
			var pc: int = c + d.x * step
			if not is_valid_pos(pr, pc) or grid[pr][pc] != EMPTY or scorched_tiles.has(Vector2i(pc, pr)):
				path_clear = false
				break
		if not path_clear:
			continue

		var dest = Vector2i(c + d.x * distance, r + d.y * distance)
		var already_listed = false
		for m in moves:
			if m["to"] == dest:
				already_listed = true
				break
		if already_listed:
			continue

		moves.append({
			"from": Vector2i(c, r),
			"to": dest,
			"is_capture": false,
			"captured": Vector2i(-1, -1)
		})

func make_move(move_dict: Dictionary) -> bool:
	var from_pos: Vector2i = move_dict["from"]
	var to_pos: Vector2i = move_dict["to"]
	var is_cap: bool = move_dict.get("is_capture", false)

	# Bônus de cartas valem só até o próximo movimento.
	bonus_moves.clear()
	last_capture_prevented = false

	var piece: BoardPiece = grid[from_pos.y][from_pos.x]
	grid[from_pos.y][from_pos.x] = EMPTY
	grid[to_pos.y][to_pos.x] = piece

	if _protected_piece != null and piece.owner_team != _protected_attacker_team:
		_protected_piece = null

	# Em simulação nenhuma Lei é consultada nem notificada (ver is_simulation).
	var pipeline: RulePipeline = null if is_simulation else rule_pipeline

	if is_cap:
		var cap_pos: Vector2i = move_dict["captured"]
		var cap_piece: BoardPiece = grid[cap_pos.y][cap_pos.x]

		# Lei Escudo (ou qualquer Lei com try_prevent_capture): a peça sobrevive
		# e o salto acontece mesmo assim — o atacante pousa, a vítima fica.
		if cap_piece.is_tree:
			# Árvore: cai sem Leis, sem eventos de captura e sem ouro.
			grid[cap_pos.y][cap_pos.x] = EMPTY
			piece_destroyed.emit(cap_pos, cap_piece)
		elif pipeline != null and pipeline.try_prevent_capture(cap_piece, human_team_color, self):
			last_capture_prevented = true
			_protected_piece = cap_piece
			_protected_attacker_team = piece.owner_team
			capture_prevented.emit(cap_pos, cap_piece)
		elif cap_piece == last_chance_piece:
			# Última Chance (moeda já girada pelo controlador): a Dama fica.
			last_chance_piece = null
			last_capture_prevented = true
			_protected_piece = cap_piece
			_protected_attacker_team = piece.owner_team
		else:
			grid[cap_pos.y][cap_pos.x] = EMPTY
			piece_destroyed.emit(cap_pos, cap_piece)
			if not is_simulation and hungry_roots_team != 0 and piece.owner_team == hungry_roots_team and not _capturers.has(piece):
				_capturers.append(piece)

			if pipeline != null:
				# Dispara evento de captura
				pipeline.emit_event(&"piece_captured", {
					"attacker": piece,
					"victim": cap_piece,
					"attacker_pos": to_pos,
					"victim_pos": cap_pos
				}, self)
				# Dispara evento de peça perdida
				pipeline.emit_event(&"piece_lost", {
					"piece": cap_piece,
					"pos": cap_pos
				}, self)
	else:
		if pipeline != null:
			pipeline.emit_event(&"step_moved", {
				"piece": piece,
				"from": from_pos,
				"to": to_pos
			}, self)

	# Terra Queimada: quem POUSA numa casa em chamas é destruído.
	if fire_tiles.has(to_pos):
		grid[to_pos.y][to_pos.x] = EMPTY
		piece_destroyed.emit(to_pos, piece)
		return false

	# Herdeiro que chega ao fim do tabuleiro vira Dama de verdade.
	if piece.is_king and piece.temp_king_turns > 0:
		var end_row = 0 if piece.owner_team == human_team_color else rows - 1
		if to_pos.y == end_row:
			piece.temp_king_turns = 0

	var promoted = false
	if not piece.is_king:
		var target_promotion_row = 0 if (piece.owner_team == human_team_color) else (rows - 1)
		var reached_end = (to_pos.y == target_promotion_row)
		var custom_promo = false

		if pipeline != null:
			custom_promo = pipeline.should_promote_to_king(piece, to_pos, human_team_color, self)

		if reached_end or custom_promo:
			piece.is_king = true
			promoted = true
			if pipeline != null:
				pipeline.emit_event(&"on_promotion", {
					"piece": piece,
					"pos": to_pos
				}, self)

	return promoted

func count_pieces(team: int, kings_only: bool = false) -> int:
	var count = 0
	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p != EMPTY and p.owner_team == team:
				if not kings_only or p.is_king:
					count += 1
	return count

func evaluate_for_team(team: int) -> int:
	var score = 0
	var enemy_team = BLACK if team == WHITE else WHITE

	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p != EMPTY:
				var val = 50 if p.is_king else 10
				if p.owner_team == team:
					score += val
				elif p.owner_team == enemy_team:
					score -= val

	return score

func clone() -> Board:
	var new_b = Board.new(rows, cols)
	new_b.human_team_color = human_team_color
	new_b.layout_id = layout_id
	new_b.initial_piece_count = initial_piece_count
	new_b.ai_team_color = ai_team_color
	new_b.rule_pipeline = rule_pipeline
	new_b.is_simulation = true
	new_b.scorched_tiles = scorched_tiles.duplicate()
	new_b.fire_tiles = fire_tiles.duplicate()
	new_b.bonus_moves = bonus_moves.duplicate(true)
	new_b.night_boost_team = night_boost_team
	new_b.vine_tiles = vine_tiles.duplicate()
	new_b.firefly_tiles = firefly_tiles.duplicate()
	new_b.lit_tiles = lit_tiles.duplicate(true)

	for r in range(rows):
		for c in range(cols):
			var p: BoardPiece = grid[r][c]
			if p != EMPTY:
				new_b.grid[r][c] = p.clone()

	return new_b
