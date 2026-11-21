class_name DuelBossCume
extends DuelBoss

# Chefe do Cume Congelado (O Último Montanhista): cada run sorteia UMA destas
# leis (RunManager). Herda do chefe da floresta a vitória por eliminação, o
# cerco e a Morte Súbita anti-impasse. O estado de tabuleiro novo vive em Board
# (ice_tiles, snow_tiles, rope_pairs) e em BoardPiece (frost/frozen, winded,
# polar_shield). O topo do tabuleiro (fileira 0) é o "cume": é o lado do chefe.
const LAW_FROST := "frost"
const LAW_ICE := "ice"
const LAW_AVALANCHE := "avalanche"
const LAW_ROPE := "rope"
const LAW_THIN_AIR := "thin_air"
const LAW_POLAR := "polar"
const CUME_LAWS := [LAW_FROST, LAW_ICE, LAW_AVALANCHE, LAW_ROPE, LAW_THIN_AIR, LAW_POLAR]

# Geada: turnos do DONO parada e sem aliada colada até congelar.
const FROST_LIMIT := 3
# Gelo Escorregadio: casas de gelo espalhadas pelo tabuleiro inteiro (fração das
# casas escuras fora das fileiras de coroação; nunca menos que ICE_COUNT).
const ICE_COUNT := 7
const ICE_SHARE := 0.45
# Avalanche: a cada 8 jogadas (4 rodadas), avisada 4 jogadas (2 rodadas) antes.
const AVALANCHE_INTERVAL_PLIES := 8
const AVALANCHE_WARN_PLIES := 4
const AVALANCHE_MIN_LEN := 5
# Quantas encostas descem de uma vez: 1 (50%), 2 (35%) ou 3 (15%).
const AVALANCHE_COUNT_WEIGHTS := [0.5, 0.35, 0.15]
const SNOW_ROUNDS := 3   # o 1º tique vem logo no fim do turno do chefe
# Cordada: quantos pares amarrados. As cordas são refeitas no fim de cada turno
# do chefe, nas duplas que mais aproveitam o puxão (peça ameaçada + parceira
# que, puxada para a casa dela, consegue revidar).
const ROPE_PAIRS := 2
# De quantos em quantos turnos do chefe ele refaz TODAS as cordas. Nos outros
# turnos só repõe uma corda gasta (puxão) ou esticada além do alcance.
const ROPE_RETIE_TURNS := 4
# Ar Rarefeito: fileiras do alto (do lado do chefe) onde falta fôlego.
const THIN_AIR_ROWS := 2

# Casas marcadas para o próximo efeito (Avalanche: a encosta da vez). O renderer desenha.
var telegraph_tiles: Array = []
# Avalanche: as encostas marcadas (cada uma é uma lista de casas, de cima para baixo).
var avalanche_lanes: Array = []
# Luz Polar: fileira iluminada agora (as peças do chefe nela têm escudo) e a próxima.
var polar_row: int = -1
var polar_next_row: int = -1
var _polar_dir: int = 1
# Quem acabou de jogar (o controlador preenche antes de advance_turn).
var mover_team: int = 0
var _cume_ply: int = 0
var _rope_boss_turns: int = 0

func _init() -> void:
	if RunManager != null:
		law_id = RunManager.get_cume_boss_law_id(CUME_LAWS)

func setup(p_board: Board, p_human_team: int, p_ai_team: int, p_sudden_death_mgr: SuddenDeathManager) -> void:
	super.setup(p_board, p_human_team, p_ai_team, p_sudden_death_mgr)
	telegraph_tiles = []
	avalanche_lanes = []
	_cume_ply = 0
	polar_row = -1
	polar_next_row = -1

func apply_board_modifiers() -> void:
	board.night_boost_team = 0
	match law_id:
		LAW_ICE:
			_spawn_ice()
		LAW_ROPE:
			_retie_ropes()
		LAW_POLAR:
			polar_next_row = _first_polar_row()
			_polar_dir = 1 if randf() < 0.5 else -1
			_advance_polar()

func get_enemy_fixed_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = []
	match law_id:
		LAW_ICE:
			rules.append(RuleSlipperyIce.new())
		LAW_AVALANCHE:
			rules.append(RuleAvalanche.new())
		LAW_ROPE:
			rules.append(RuleRope.new())
		LAW_THIN_AIR:
			rules.append(RuleThinAir.new())
		LAW_POLAR:
			rules.append(RulePolarLight.new())
		_:
			rules.append(RuleFrost.new())
	return rules

# Chamado UMA vez por fim de turno (de qualquer lado). Muda o estado e devolve
# os eventos para a view.
func advance_turn() -> Array:
	var events: Array = []
	_cume_ply += 1
	match law_id:
		LAW_FROST:
			events.append_array(_tick_frost(mover_team))
		LAW_AVALANCHE:
			var phase: int = _cume_ply % AVALANCHE_INTERVAL_PLIES
			if phase == AVALANCHE_INTERVAL_PLIES - AVALANCHE_WARN_PLIES:
				avalanche_lanes = _pick_lanes(_roll_lane_count())
				telegraph_tiles = []
				for lane in avalanche_lanes:
					telegraph_tiles.append_array(lane)
				if not telegraph_tiles.is_empty():
					events.append({"type": "avalanche_warn", "tiles": telegraph_tiles.duplicate(), "count": avalanche_lanes.size()})
			elif phase == 0 and not avalanche_lanes.is_empty():
				var moves: Array = []
				var snows: Array = []
				for lane in avalanche_lanes:
					var res: Dictionary = _run_avalanche(lane)
					moves.append_array(res["moves"])
					if res["snow"].x >= 0:
						snows.append(res["snow"])
				events.append({"type": "avalanche", "tiles": telegraph_tiles.duplicate(), "moves": moves, "snow": snows, "count": avalanche_lanes.size()})
				telegraph_tiles = []
				avalanche_lanes = []
		LAW_ROPE:
			if mover_team == ai_team:
				_rope_boss_turns += 1
				var tied: Array = _retie_ropes(_rope_boss_turns % ROPE_RETIE_TURNS == 0)
				if not tied.is_empty():
					events.append({"type": "rope_tie", "tiles": tied})
		LAW_THIN_AIR:
			if mover_team == human_team:
				var w: Vector2i = _apply_thin_air()
				if w.x >= 0:
					events.append({"type": "winded", "tiles": [w]})
		LAW_POLAR:
			if mover_team == ai_team:
				var lit: Array = _advance_polar()
				events.append({"type": "polar", "tiles": lit, "row": polar_row})
	return events

func get_status_text() -> String:
	if board == null:
		return ""
	match law_id:
		LAW_AVALANCHE:
			if telegraph_tiles.is_empty():
				return ""
			var left: int = AVALANCHE_INTERVAL_PLIES - (_cume_ply % AVALANCHE_INTERVAL_PLIES)
			var what: String = "AVALANCHE" if avalanche_lanes.size() <= 1 else "AVALANCHE x%d" % avalanche_lanes.size()
			return "%s EM %d RODADA(S)" % [what, int(ceil(left / 2.0))]
	return ""

# --- Ajudantes ------------------------------------------------------------

func _is_free_dark(pos: Vector2i) -> bool:
	return (pos.x + pos.y) % 2 == 1 and board.grid[pos.y][pos.x] == Board.EMPTY \
		and not board.scorched_tiles.has(pos) and not board.fire_tiles.has(pos)

func _both_can_move() -> bool:
	return not board.get_all_valid_moves(human_team).is_empty() and not board.get_all_valid_moves(ai_team).is_empty()

func _is_real_piece(p: BoardPiece) -> bool:
	return p != Board.EMPTY and not p.is_tree and not p.is_rock and p.owner_team != Board.NEUTRAL

# Escolha espalhada: prefere a casa mais longe das já escolhidas, com um pouco de acaso.
func _pick_spread(cands: Array, count: int) -> Array:
	var pool: Array = cands.duplicate()
	var chosen: Array = []
	while chosen.size() < count and not pool.is_empty():
		var best: Vector2i = pool[0]
		var best_score: float = -1.0
		for p in pool:
			var d: float = 99.0
			for a in chosen:
				d = minf(d, absf(p.x - a.x) + 1.3 * absf(p.y - a.y))
			var score: float = d + randf() * 1.6
			if score > best_score:
				best_score = score
				best = p
		chosen.append(best)
		pool.erase(best)
	return chosen

# --- Geada ------------------------------------------------------------------

func _has_ally_touching(pos: Vector2i, team: int) -> bool:
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var q: Vector2i = pos + d
		if board.is_valid_pos(q.y, q.x):
			var p: BoardPiece = board.grid[q.y][q.x]
			if p != Board.EMPTY and p.owner_team == team and not p.is_tree and not p.is_rock:
				return true
	return false

# Fim do turno de `team`: a peça que andou zera a geada; as outras paradas e
# sozinhas ganham 1 de geada e, com FROST_LIMIT, congelam. Uma aliada parada
# colada descongela. Nunca deixa o time sem jogada no próximo turno dele.
func _tick_frost(team: int) -> Array:
	var events: Array = []
	var froze: Array = []
	var thawed: Array = []
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if not _is_real_piece(p) or p.owner_team != team:
				continue
			var pos := Vector2i(c, r)
			var touching: bool = _has_ally_touching(pos, team)
			if p == board.last_moved_piece or touching:
				p.frost = 0
				if p.frozen:
					p.frozen = false
					thawed.append(pos)
				continue
			if p.frozen:
				continue
			p.frost += 1
			if p.frost >= FROST_LIMIT:
				p.frozen = true
				froze.append(pos)
	# congelar tudo nunca pode travar o time: devolve as recém-congeladas
	if not froze.is_empty() and board.get_all_valid_moves(team).is_empty():
		for pos in froze:
			var q: BoardPiece = board.grid[pos.y][pos.x]
			q.frozen = false
			q.frost = FROST_LIMIT - 1
		froze = []
	# o time já estava travado por gelo antigo: descongela a mais antiga que destrave
	if board.get_all_valid_moves(team).is_empty():
		for r in range(board.rows):
			for c in range(board.cols):
				var p2: BoardPiece = board.grid[r][c]
				if _is_real_piece(p2) and p2.owner_team == team and p2.frozen:
					p2.frozen = false
					p2.frost = 0
					thawed.append(Vector2i(c, r))
					if not board.get_all_valid_moves(team).is_empty():
						break
			if not board.get_all_valid_moves(team).is_empty():
				break
	if not froze.is_empty():
		events.append({"type": "freeze", "tiles": froze})
	if not thawed.is_empty():
		events.append({"type": "thaw", "tiles": thawed})
	return events

# --- Gelo Escorregadio --------------------------------------------------------

func _spawn_ice() -> void:
	board.ice_tiles.clear()
	# Casas escuras do tabuleiro todo (menos as fileiras de coroação), inclusive
	# as que já têm peça: o gelo fica embaixo e vale quando alguém PARAR ali.
	var cands: Array = []
	for r in range(1, board.rows - 1):
		for c in range(board.cols):
			var p := Vector2i(c, r)
			if (p.x + p.y) % 2 != 1 or board.scorched_tiles.has(p) or board.fire_tiles.has(p):
				continue
			var occ: BoardPiece = board.grid[r][c]
			if occ != Board.EMPTY and not _is_real_piece(occ):
				continue   # árvore/pedra/obstáculo
			cands.append(p)
	var count: int = maxi(ICE_COUNT, int(round(cands.size() * ICE_SHARE)))
	for pos in _pick_spread(cands, count):
		board.ice_tiles[pos] = true

# --- Avalanche ----------------------------------------------------------------

# Encostas: diagonais ("/" e "\") de casas escuras entre as fileiras 1 e rows-2.
# Ordenadas de cima (cume) para baixo.
func _lanes() -> Array:
	var out: Array = []
	for k in range(-board.rows, board.rows + board.cols):
		var a: Array = []
		var d: Array = []
		for r in range(1, board.rows - 1):
			var c1: int = k - r
			if c1 >= 0 and c1 < board.cols and (c1 + r) % 2 == 1:
				a.append(Vector2i(c1, r))
			var c2: int = k + r
			if c2 >= 0 and c2 < board.cols and (c2 + r) % 2 == 1:
				d.append(Vector2i(c2, r))
		if a.size() >= AVALANCHE_MIN_LEN:
			out.append(a)
		if d.size() >= AVALANCHE_MIN_LEN:
			out.append(d)
	return out

func _roll_lane_count() -> int:
	var r: float = randf()
	var acc: float = 0.0
	for i in range(AVALANCHE_COUNT_WEIGHTS.size()):
		acc += AVALANCHE_COUNT_WEIGHTS[i]
		if r < acc:
			return i + 1
	return AVALANCHE_COUNT_WEIGHTS.size()

# As encostas da vez: as com mais peças (de qualquer lado), com um pouco de
# acaso, sem duas encostas dividindo casa (senão a neve "desceria duas vezes").
func _pick_lanes(count: int) -> Array:
	var scored: Array = []
	for lane in _lanes():
		var n: int = 0
		for pos in lane:
			if _is_real_piece(board.grid[pos.y][pos.x]):
				n += 1
		scored.append({"lane": lane, "s": float(n) + randf() * 1.5})
	scored.sort_custom(func(x, y): return x["s"] > y["s"])
	var chosen: Array = []
	var used: Dictionary = {}
	for e in scored:
		if chosen.size() >= count:
			break
		var clash := false
		for pos in e["lane"]:
			if used.has(pos):
				clash = true
				break
		if clash:
			continue
		chosen.append(e["lane"])
		for pos in e["lane"]:
			used[pos] = true
	return chosen

# Desce: cada peça da encosta escorrega UMA casa morro abaixo (de baixo para
# cima, para abrir espaço), se a casa estiver livre. Peça comum do chefe não
# desce até a fileira de coroação dele. No alto da encosta fica um monte de neve.
func _run_avalanche(lane: Array) -> Dictionary:
	var moves: Array = []
	for i in range(lane.size() - 2, -1, -1):
		var from: Vector2i = lane[i]
		var to: Vector2i = lane[i + 1]
		var p: BoardPiece = board.grid[from.y][from.x]
		if not _is_real_piece(p):
			continue
		if board.grid[to.y][to.x] != Board.EMPTY or board.scorched_tiles.has(to) or board.fire_tiles.has(to):
			continue
		if not p.is_king and p.owner_team == ai_team and to.y == board.rows - 1:
			continue
		board.grid[from.y][from.x] = Board.EMPTY
		board.grid[to.y][to.x] = p
		moves.append([from, to])
	# monte de neve: a casa mais alta da encosta que ficou vazia
	var snow := Vector2i(-1, -1)
	for pos in lane:
		if board.grid[pos.y][pos.x] == Board.EMPTY and not board.scorched_tiles.has(pos):
			board.snow_tiles[pos] = true
			board.scorched_tiles[pos] = SNOW_ROUNDS
			if _both_can_move():
				snow = pos
			else:
				board.snow_tiles.erase(pos)
				board.scorched_tiles.erase(pos)
			break
	return {"moves": moves, "snow": snow}

# --- Cordada ----------------------------------------------------------------

# Refaz as cordas (full) ou só repõe as que faltam: desamarra e amarra as ROPE_PAIRS melhores duplas do
# chefe. Melhor dupla = uma peça que o jogador pode capturar agora + uma parceira
# perto o bastante que, puxada para a casa da vítima, consegue capturar de volta
# quem pulou. Sem ameaça nenhuma, amarra duplas coladas ao acaso.
# Devolve as casas das peças recém-amarradas (para a animação).
func _retie_ropes(full: bool = true) -> Array:
	var old: Array = []
	for pair in board.rope_pairs:
		old.append(pair[0])
		old.append(pair[1])
	var used: Array = []
	if full:
		board.rope_pairs.clear()
	else:
		# mantém as cordas que ainda valem: as duas pontas no tabuleiro e ao alcance
		for i in range(board.rope_pairs.size() - 1, -1, -1):
			var pa: Vector2i = board.find_piece(board.rope_pairs[i][0])
			var pb: Vector2i = board.find_piece(board.rope_pairs[i][1])
			if pa.x < 0 or pb.x < 0 or maxi(absi(pa.x - pb.x), absi(pa.y - pb.y)) > Board.ROPE_REACH:
				board.rope_pairs.remove_at(i)
		for pair in board.rope_pairs:
			used.append(pair[0])
			used.append(pair[1])
		if board.rope_pairs.size() >= ROPE_PAIRS:
			return []
	var cands: Array = _rope_candidates()
	cands.sort_custom(func(x, y): return x["s"] > y["s"])
	var tied: Array = []
	for e in cands:
		if board.rope_pairs.size() >= ROPE_PAIRS:
			break
		var a: BoardPiece = board.grid[e["a"].y][e["a"].x]
		var b: BoardPiece = board.grid[e["b"].y][e["b"].x]
		if used.has(a) or used.has(b):
			continue
		board.rope_pairs.append([a, b])
		used.append(a)
		used.append(b)
		if not old.has(a):
			tied.append(e["a"])
		if not old.has(b):
			tied.append(e["b"])
	return tied

func _rope_candidates() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	# 1) peças ameaçadas: simula a captura do jogador e o puxão da parceira
	for m in board.get_all_valid_moves(human_team):
		if not m.get("is_capture", false) or not m.has("captured"):
			continue
		var v: Vector2i = m["captured"]
		var vp: BoardPiece = board.grid[v.y][v.x]
		if not _is_real_piece(vp) or vp.owner_team != ai_team:
			continue
		for dy in range(-Board.ROPE_REACH, Board.ROPE_REACH + 1):
			for dx in range(-Board.ROPE_REACH, Board.ROPE_REACH + 1):
				var q: Vector2i = v + Vector2i(dx, dy)
				if q == v or not board.is_valid_pos(q.y, q.x):
					continue
				var qp: BoardPiece = board.grid[q.y][q.x]
				if not _is_real_piece(qp) or qp.owner_team != ai_team:
					continue
				var key: String = "%s|%s" % [v, q]
				var score: float = 10.0 + randf() * 2.0
				var sim: Board = board.clone()
				sim.make_move(m)
				if sim.grid[v.y][v.x] == Board.EMPTY and sim.grid[q.y][q.x] != Board.EMPTY:
					sim.grid[v.y][v.x] = sim.grid[q.y][q.x]
					sim.grid[q.y][q.x] = Board.EMPTY
					for cm in sim.get_piece_captures(v.y, v.x):
						if cm.get("captured", Vector2i(-1, -1)) == m["to"]:
							score += 12.0   # puxada, ela revida em quem pulou
							break
				if seen.has(key):
					seen[key]["s"] = maxf(seen[key]["s"], score)
				else:
					var e := {"a": v, "b": q, "s": score}
					seen[key] = e
					out.append(e)
	# 2) duplas coladas na diagonal (sem ameaça): as da frente, variando ao acaso
	for r in range(board.rows):
		for c in range(board.cols):
			var a: BoardPiece = board.grid[r][c]
			if not _is_real_piece(a) or a.owner_team != ai_team:
				continue
			for d in [Vector2i(1, 1), Vector2i(-1, 1)]:
				var q2: Vector2i = Vector2i(c, r) + d
				if not board.is_valid_pos(q2.y, q2.x):
					continue
				var b: BoardPiece = board.grid[q2.y][q2.x]
				if _is_real_piece(b) and b.owner_team == ai_team:
					# prefere a linha de frente (onde a briga acontece), com acaso
					out.append({"a": Vector2i(c, r), "b": q2, "s": randf() * 3.0 + float(r) * 0.6})
	return out

# --- Ar Rarefeito -------------------------------------------------------------

# A peça do jogador que acabou de chegar perto do cume perde o fôlego: fica a
# próxima jogada parada (nunca deixa o jogador sem nenhuma jogada).
func _apply_thin_air() -> Vector2i:
	var p: BoardPiece = board.last_moved_piece
	if p == null or not _is_real_piece(p) or p.owner_team != human_team:
		return Vector2i(-1, -1)
	var pos: Vector2i = board.find_piece(p)
	if pos.x < 0 or pos.y >= THIN_AIR_ROWS:
		return Vector2i(-1, -1)
	var before: int = p.rooted_turns
	# 2: o tick do fim deste turno já desconta 1; sobra 1 para a PRÓXIMA jogada.
	p.rooted_turns = maxi(p.rooted_turns, 2)
	p.winded = true
	if board.get_all_valid_moves(human_team).size() == 0 or _only_mover_can_move(p):
		p.rooted_turns = before
		p.winded = false
		return Vector2i(-1, -1)
	return pos

# Se essa peça é a ÚNICA que tem jogada, prendê-la travaria o jogador.
func _only_mover_can_move(p: BoardPiece) -> bool:
	var keep: int = p.rooted_turns
	p.rooted_turns = 0
	var others := false
	for m in board.get_all_valid_moves(human_team):
		var fp: Vector2i = m["from"]
		if board.grid[fp.y][fp.x] != p:
			others = true
			break
	p.rooted_turns = keep
	return not others

# --- Luz Polar ----------------------------------------------------------------

func _first_polar_row() -> int:
	@warning_ignore("integer_division")
	return clampi(board.rows / 2 + (randi() % 2) - 1, 1, board.rows - 2)

# Fim do turno do chefe: a aurora desce sobre a fileira marcada e as peças do
# chefe nela ganham escudo (a próxima captura contra cada uma falha); os escudos
# antigos somem. A faixa anda uma fileira e volta ao chegar na ponta.
func _advance_polar() -> Array:
	for r in range(board.rows):
		for c in range(board.cols):
			var q: BoardPiece = board.grid[r][c]
			if q != Board.EMPTY:
				q.polar_shield = false
	polar_row = polar_next_row if polar_next_row >= 0 else _first_polar_row()
	var lit: Array = []
	for c in range(board.cols):
		var p: BoardPiece = board.grid[polar_row][c]
		if _is_real_piece(p) and p.owner_team == ai_team:
			p.polar_shield = true
			lit.append(Vector2i(c, polar_row))
	var nxt: int = polar_row + _polar_dir
	if nxt < 1 or nxt > board.rows - 2:
		_polar_dir = -_polar_dir
		nxt = polar_row + _polar_dir
	polar_next_row = clampi(nxt, 1, board.rows - 2)
	return lit
