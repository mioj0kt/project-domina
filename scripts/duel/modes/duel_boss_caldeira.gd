class_name DuelBossCaldeira
extends DuelBoss

# Chefe da Caldeira (A Ferreira da Caldeira): cada run sorteia UMA destas leis
# (RunManager.get_caldeira_boss_law_id). Herda do chefe da floresta a vitória por
# eliminação, o cerco e a Morte Súbita anti-impasse. O topo do tabuleiro
# (fileira 0) é o lado do chefe; ela coroa na última fileira (rows - 1).
# Estado novo no Board: anvil_tiles (Bigorna), flow_tiles/crust_tiles + lava_tiles
# (Escorrida), crown_price_team (Preço da Coroa). As casas em
# brasa do Caldeirão reaproveitam ember_tiles/scorched_tiles dos duelos chamuscados.
const LAW_ANVIL := "anvil"
const LAW_FOUNDRY := "foundry"
const LAW_CROWN_PRICE := "crown_price"
const LAW_LAVA_FLOW := "lava_flow"
const LAW_HAMMER := "hammer"
const LAW_CAULDRON := "boiling_cauldron"
const CALDEIRA_LAWS: Array = [LAW_ANVIL, LAW_FOUNDRY, LAW_CROWN_PRICE, LAW_LAVA_FLOW, LAW_HAMMER, LAW_CAULDRON]

# Tudo em "jogadas" (cada lado que termina o turno = 1; 2 jogadas = 1 rodada).
# Bigorna: quanto tempo esfria depois de martelar.
const ANVIL_COUNT := 2
const ANVIL_COOL_PLIES := 6
# Fundição: peças perdidas pelo chefe para derramar uma nova; máximo por duelo.
const FOUNDRY_NEED := 3
const FOUNDRY_MAX := 2
# Escorrida: a cada N jogadas a lava brota no meio de uma coluna (a casa e a
# coluna ficam marcadas antes) e escorre para os DOIS lados, 1 casa para cima e 1
# para baixo no fim de cada turno do chefe (cada lado tem uma jogada para sair da
# frente). A lava fica X jogadas e vira basalto, que bloqueia mais Y jogadas.
const FLOW_INTERVAL_PLIES := 8
const FLOW_WARN_PLIES := 2
const FLOW_LAVA_PLIES := 4
const FLOW_CRUST_PLIES := 4
const FLOW_FOREVER := 9999
# Martelada: a cada N jogadas, avisada W jogadas antes.
const HAMMER_INTERVAL_PLIES := 8
const HAMMER_WARN_PLIES := 4
# Caldeirão Fervente: cada peça perdida (qualquer lado) sobe 1; cheio, ele marca
# casas espalhadas e transborda depois de 2 jogadas; elas viram brasa por 2 rodadas.
const CAULDRON_MAX := 5
const CAULDRON_FUSE_PLIES := 2
const CAULDRON_EMBER_ROUNDS := 4

# Quem acabou de jogar (o controlador preenche antes de advance_turn).
var mover_team: int = 0
var _ply: int = 0
# Contagem de peças da última vez (para saber quantas cada lado perdeu).
var _last_counts: Dictionary = {}

# Fundição
var foundry_count: int = 0
var foundry_poured: int = 0
# Escorrida: línguas escorrendo [{"col": int, "up": int, "down": int}] (fileiras das duas pontas)
var flows: Array = []
var flow_warn_col: int = -1
var flow_warn_row: int = -1
var _flow_lava_left: Dictionary = {}   # casa -> jogadas restantes como lava
var _flow_crust_left: Dictionary = {}  # casa -> jogadas restantes como basalto
var _last_flow_col: int = -1
# Martelada: o martelo marca uma PEÇA e segue ela pelo tabuleiro
var hammer_piece: BoardPiece = null
var hammer_pos: Vector2i:     # onde a peça marcada está agora ((-1,-1) = sem marca)
	get:
		return _find_piece(hammer_piece)
# Caldeirão
var cauldron: int = 0
var cauldron_targets: Array = []
var cauldron_fuse: int = -1   # jogadas até transbordar (-1 = sem aviso)

func _init() -> void:
	law_id = LAW_ANVIL
	if RunManager != null:
		law_id = RunManager.get_caldeira_boss_law_id(CALDEIRA_LAWS)

func setup(p_board: Board, p_human_team: int, p_ai_team: int, p_sudden_death_mgr: SuddenDeathManager) -> void:
	super.setup(p_board, p_human_team, p_ai_team, p_sudden_death_mgr)
	_ply = 0
	foundry_count = 0
	foundry_poured = 0
	flows = []
	flow_warn_col = -1
	flow_warn_row = -1
	_flow_lava_left = {}
	_flow_crust_left = {}
	hammer_piece = null
	cauldron = 0
	cauldron_targets = []
	cauldron_fuse = -1

func apply_board_modifiers() -> void:
	board.night_boost_team = 0
	board.crown_price_team = human_team if law_id == LAW_CROWN_PRICE else 0
	if law_id == LAW_ANVIL:
		_place_anvils()
	_last_counts = {human_team: _count(human_team), ai_team: _count(ai_team)}

func get_enemy_fixed_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = []
	match law_id:
		LAW_FOUNDRY:
			rules.append(RuleFoundry.new())
		LAW_CROWN_PRICE:
			rules.append(RuleCrownPrice.new())
		LAW_LAVA_FLOW:
			rules.append(RuleLavaFlow.new())
		LAW_HAMMER:
			rules.append(RuleHammer.new())
		LAW_CAULDRON:
			rules.append(RuleBoilingCauldron.new())
		_:
			rules.append(RuleAnvil.new())
	return rules

# Chamado UMA vez por fim de turno (de qualquer lado). Muda o estado e devolve os
# eventos para a view.
func advance_turn() -> Array:
	var events: Array = []
	_ply += 1
	var lost: Dictionary = _losses()
	match law_id:
		LAW_ANVIL:
			events.append_array(_tick_anvils())
		LAW_FOUNDRY:
			events.append_array(_tick_foundry(int(lost.get(ai_team, 0))))
		LAW_LAVA_FLOW:
			events.append_array(_tick_flows())
		LAW_HAMMER:
			events.append_array(_tick_hammer())
		LAW_CAULDRON:
			events.append_array(_tick_cauldron(int(lost.get(ai_team, 0)) + int(lost.get(human_team, 0))))
	# o que as próprias leis destruíram/criaram não conta como perda da próxima vez
	_last_counts = {human_team: _count(human_team), ai_team: _count(ai_team)}
	return events

func get_status_text() -> String:
	if board == null:
		return ""
	match law_id:
		LAW_LAVA_FLOW:
			if flow_warn_col >= 0:
				return "A LAVA ESCORRE EM %d RODADA(S)" % _rounds_to(FLOW_INTERVAL_PLIES)
		LAW_HAMMER:
			if hammer_pos.x >= 0:
				return "MARTELADA EM %d RODADA(S)" % _rounds_to(HAMMER_INTERVAL_PLIES)
		LAW_CAULDRON:
			if cauldron_fuse >= 0:
				return "O CALDEIRÃO VAI TRANSBORDAR!"
	return ""

func _rounds_to(interval: int) -> int:
	var left: int = interval - (_ply % interval)
	return maxi(1, int(ceil(left / 2.0)))

# --- Ajudantes ------------------------------------------------------------

func _is_real_piece(p: BoardPiece) -> bool:
	return p != Board.EMPTY and not p.is_tree and p.owner_team != Board.NEUTRAL

func _count(team: int) -> int:
	var n: int = 0
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if _is_real_piece(p) and p.owner_team == team:
				n += 1
	return n

# Quantas peças cada lado perdeu desde o último fim de turno (por qualquer motivo).
func _losses() -> Dictionary:
	var out: Dictionary = {}
	for team in [human_team, ai_team]:
		out[team] = maxi(0, int(_last_counts.get(team, 0)) - _count(team))
	return out

func _both_can_move() -> bool:
	return not board.get_all_valid_moves(human_team).is_empty() and not board.get_all_valid_moves(ai_team).is_empty()

func _is_dark(p: Vector2i) -> bool:
	return (p.x + p.y) % 2 == 1

func _free_dark(p: Vector2i) -> bool:
	return _is_dark(p) and board.grid[p.y][p.x] == Board.EMPTY and not board.scorched_tiles.has(p) and not board.fire_tiles.has(p)

func _has_ally_touching(pos: Vector2i, team: int, except: BoardPiece = null) -> bool:
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var q: Vector2i = pos + d
		if board.is_valid_pos(q.y, q.x):
			var p: BoardPiece = board.grid[q.y][q.x]
			if _is_real_piece(p) and p.owner_team == team and p != except:
				return true
	return false

# Sorteio espalhado com bastante acaso: prefere casas longe das já escolhidas (e
# de `avoid`), nunca duas coladas, e o desenho muda muito de uma vez para outra.
func _pick_scattered(cands: Array, count: int, avoid: Array = []) -> Array:
	var pool: Array = cands.duplicate()
	pool.shuffle()
	var chosen: Array = []
	var near: Array = avoid.duplicate()
	while chosen.size() < count and not pool.is_empty():
		var best: Vector2i = pool[0]
		var best_score: float = -INF
		for p in pool:
			var d: float = 6.0
			for a in near:
				d = minf(d, float(maxi(absi(p.x - a.x), absi(p.y - a.y))))
			var score: float = minf(d, 4.0) + randf() * 3.0
			if d < 2.0:
				score -= 10.0
			if score > best_score:
				best_score = score
				best = p
		chosen.append(best)
		near.append(best)
		pool.erase(best)
	return chosen

# --- Bigorna ----------------------------------------------------------------

# Duas bigornas no miolo, espelhadas (uma mais perto de cada lado).
func _place_anvils() -> void:
	board.anvil_tiles.clear()
	@warning_ignore("integer_division")
	var mid: int = board.rows / 2
	var cands: Array = []
	for c in range(2, board.cols - 2):
		var p := Vector2i(c, mid)
		if _free_dark(p):
			cands.append(p)
	cands.shuffle()
	for p in cands:
		var q := Vector2i(board.cols - 1 - p.x, board.rows - 1 - p.y)
		if q == p or not _free_dark(q) or absi(q.x - p.x) < 2:
			continue
		board.anvil_tiles[p] = 0
		board.anvil_tiles[q] = 0
		return
	var free: Array = []
	for r in range(mid - 1, mid + 1):
		for c in range(board.cols):
			if _free_dark(Vector2i(c, r)):
				free.append(Vector2i(c, r))
	for p3 in _pick_scattered(free, ANVIL_COUNT):
		board.anvil_tiles[p3] = 0

# Fim do turno de `mover_team`: quem está numa bigorna pronta e é do lado que VAI
# jogar agora aguentou uma vez inteira do adversário ali -> é martelada e vira Dama.
func _tick_anvils() -> Array:
	var events: Array = []
	var next_team: int = human_team if mover_team == ai_team else ai_team
	var crowned: Array = []
	for pos in board.anvil_tiles.keys():
		var cool: int = int(board.anvil_tiles[pos])
		if cool > 0:
			board.anvil_tiles[pos] = cool - 1
			continue
		var p: BoardPiece = board.grid[pos.y][pos.x]
		if _is_real_piece(p) and p.owner_team == next_team and not p.is_king:
			p.is_king = true
			board.anvil_tiles[pos] = ANVIL_COOL_PLIES
			crowned.append(pos)
	if not crowned.is_empty():
		events.append({"type": "anvil_crown", "tiles": crowned, "team": next_team})
	return events

# --- Fundição -----------------------------------------------------------------

func _tick_foundry(boss_lost: int) -> Array:
	var events: Array = []
	if foundry_poured >= FOUNDRY_MAX or boss_lost <= 0:
		return events
	foundry_count += boss_lost
	if foundry_count < FOUNDRY_NEED:
		events.append({"type": "foundry_fill", "count": foundry_count})
		return events
	var pos: Vector2i = _foundry_spawn_cell()
	if pos.x < 0:
		foundry_count = FOUNDRY_NEED - 1   # sem lugar: derrama na próxima perda
		return events
	foundry_count = 0
	foundry_poured += 1
	board.grid[pos.y][pos.x] = BoardPiece.new(ai_team, false)
	events.append({"type": "foundry_pour", "tiles": [pos], "left": FOUNDRY_MAX - foundry_poured})
	return events

# Casa livre o mais perto possível da fileira de trás do chefe, de preferência no meio.
func _foundry_spawn_cell() -> Vector2i:
	var mid: float = (board.cols - 1) / 2.0
	for r in range(0, board.rows - 1):
		var best := Vector2i(-1, -1)
		var best_s: float = INF
		for c in range(board.cols):
			var p := Vector2i(c, r)
			if not _free_dark(p) or board.anvil_tiles.has(p):
				continue
			var s: float = absf(c - mid) + randf() * 1.5
			if s < best_s:
				best_s = s
				best = p
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

# --- Escorrida ----------------------------------------------------------------

func _tick_flows() -> Array:
	var events: Array = []
	# a lava que já passou vai esfriando em basalto, e o basalto some
	for pos in _flow_lava_left.keys():
		_flow_lava_left[pos] -= 1
		if _flow_lava_left[pos] <= 0:
			_flow_lava_left.erase(pos)
			board.lava_tiles.erase(pos)
			board.flow_tiles.erase(pos)
			board.crust_tiles[pos] = true
			_flow_crust_left[pos] = FLOW_CRUST_PLIES
	for pos in _flow_crust_left.keys():
		_flow_crust_left[pos] -= 1
		if _flow_crust_left[pos] <= 0:
			_flow_crust_left.erase(pos)
			board.crust_tiles.erase(pos)
			board.scorched_tiles.erase(pos)
	# aviso e nascimento de uma língua nova (a fonte brota na casa marcada)
	var killed: Array = []
	var heads: Array = []
	var phase: int = _ply % FLOW_INTERVAL_PLIES
	if phase == FLOW_INTERVAL_PLIES - FLOW_WARN_PLIES:
		flow_warn_col = _pick_flow_col()
		if flow_warn_col >= 0:
			flow_warn_row = _flow_source_row(flow_warn_col)
			events.append({"type": "lava_warn", "col": flow_warn_col, "tiles": [Vector2i(flow_warn_col, flow_warn_row)]})
	elif phase == 0 and flow_warn_col >= 0:
		flows.append({"col": flow_warn_col, "up": flow_warn_row, "down": flow_warn_row})
		_last_flow_col = flow_warn_col
		_pour(Vector2i(flow_warn_col, flow_warn_row), heads, killed)
		flow_warn_col = -1
		flow_warn_row = -1
	elif mover_team == ai_team:
		# fim do turno do chefe: as duas pontas escorrem uma casa
		for i in range(flows.size() - 1, -1, -1):
			var f: Dictionary = flows[i]
			f["up"] = int(f["up"]) - 1
			f["down"] = int(f["down"]) + 1
			var alive := false
			for r in [int(f["up"]), int(f["down"])]:
				if r >= 0 and r < board.rows:
					_pour(Vector2i(int(f["col"]), r), heads, killed)
					alive = true
			if not alive:
				flows.remove_at(i)
	_unblock_if_stuck()
	if not heads.is_empty():
		events.append({"type": "lava_flow", "tiles": heads, "killed": killed})
	return events

# A lava toma a casa: destrói o que estiver nela e bloqueia.
func _pour(pos: Vector2i, heads: Array, killed: Array) -> void:
	var victim: BoardPiece = board.grid[pos.y][pos.x]
	if victim != Board.EMPTY:
		board.grid[pos.y][pos.x] = Board.EMPTY
		if _is_real_piece(victim):
			killed.append([pos, victim])
	board.lava_tiles[pos] = true
	board.flow_tiles[pos] = true
	board.scorched_tiles[pos] = FLOW_FOREVER
	board.crust_tiles.erase(pos)
	board.ember_tiles.erase(pos)
	_flow_crust_left.erase(pos)
	_flow_lava_left[pos] = FLOW_LAVA_PLIES
	heads.append(pos)

# Fonte no miolo da coluna: a casa escura do meio, de preferência vazia.
func _flow_source_row(col: int) -> int:
	@warning_ignore("integer_division")
	var mid: int = board.rows / 2
	var best: int = mid
	var best_s: float = INF
	for r in range(mid - 2, mid + 2):
		if r < 1 or r > board.rows - 2:
			continue
		var p := Vector2i(col, r)
		var s: float = absf(r - (board.rows - 1) / 2.0) + (3.0 if board.grid[r][col] != Board.EMPTY else 0.0) + randf() * 0.8
		if not _is_dark(p):
			s += 1.5
		if s < best_s:
			best_s = s
			best = r
	return best

# Coluna da próxima língua: uma das mais abertas, com bastante acaso, sem repetir
# a anterior nem a de uma língua ainda escorrendo.
func _pick_flow_col() -> int:
	var busy: Dictionary = {}
	for f in flows:
		busy[int(f["col"])] = true
	var best: int = -1
	var best_s: float = -INF
	for c in range(board.cols):
		if c == _last_flow_col or busy.has(c):
			continue
		var n: int = 0
		for r in range(board.rows):
			if _is_real_piece(board.grid[r][c]):
				n += 1
		# lava prefere as colunas mais abertas (vira um muro que corta o tabuleiro),
		# mas com bastante acaso
		var s: float = -float(n) + randf() * 3.0
		if c == 0 or c == board.cols - 1:
			s -= 2.0
		if s > best_s:
			best_s = s
			best = c
	return best

# Lava e basalto nunca deixam um lado sem jogada: libera o basalto mais antigo (e,
# no limite, a lava parada) até os dois lados voltarem a ter jogada.
func _unblock_if_stuck() -> void:
	if _both_can_move():
		return
	var crust: Array = _flow_crust_left.keys()
	crust.sort_custom(func(a, b): return _flow_crust_left[a] < _flow_crust_left[b])
	for pos in crust:
		_flow_crust_left.erase(pos)
		board.crust_tiles.erase(pos)
		board.scorched_tiles.erase(pos)
		if _both_can_move():
			return
	var lava: Array = _flow_lava_left.keys()
	lava.sort_custom(func(a, b): return _flow_lava_left[a] < _flow_lava_left[b])
	for pos in lava:
		_flow_lava_left.erase(pos)
		board.lava_tiles.erase(pos)
		board.flow_tiles.erase(pos)
		board.scorched_tiles.erase(pos)
		if _both_can_move():
			return

# Próxima casa de cada língua (o renderer marca onde a lava chega no fim do turno).
func flow_next_tiles() -> Array:
	var out: Array = []
	for f in flows:
		for r in [int(f["up"]) - 1, int(f["down"]) + 1]:
			if r >= 0 and r < board.rows:
				out.append(Vector2i(int(f["col"]), r))
	if flow_warn_col >= 0 and flow_warn_row >= 0:
		out.append(Vector2i(flow_warn_col, flow_warn_row))
	return out

# --- Martelada ----------------------------------------------------------------
# A Ferreira marca uma peça do jogador (a Dama mais adiantada; sem Dama, a peça
# comum mais adiantada — de preferência uma sem aliada colada) e o martelo SEGUE
# essa peça. No golpe, se ela não tiver nenhuma aliada colada na diagonal: Dama
# perde a coroa (que vai para o chefe) e peça comum é esmagada. Fugir não adianta;
# a defesa é encostar uma aliada (ou trocar a peça antes).

func _tick_hammer() -> Array:
	var events: Array = []
	var phase: int = _ply % HAMMER_INTERVAL_PLIES
	if phase == HAMMER_INTERVAL_PLIES - HAMMER_WARN_PLIES:
		var tgt: Vector2i = _pick_hammer_target()
		if tgt.x >= 0:
			hammer_piece = board.grid[tgt.y][tgt.x]
			events.append({"type": "hammer_warn" if hammer_piece.is_king else "hammer_mark", "tiles": [tgt]})
	elif phase == 0 and hammer_piece != null:
		var pos: Vector2i = hammer_pos
		var p: BoardPiece = hammer_piece
		hammer_piece = null
		if pos.x < 0:
			return events   # a peça marcada já saiu do tabuleiro (capturada/destruída)
		var saved: bool = _has_ally_touching(pos, human_team, p)
		var crown := Vector2i(-1, -1)
		var smashed: bool = false
		if not saved:
			if p.is_king:
				p.is_king = false
				p.temp_king_turns = 0
				crown = board._crown_most_advanced(ai_team)
			else:
				board.grid[pos.y][pos.x] = Board.EMPTY
				smashed = true
		events.append({"type": "hammer", "tiles": [pos], "hit": not saved, "crown": crown, "saved": saved,
			"smashed": smashed, "piece": p})
	return events

func _find_piece(piece: BoardPiece) -> Vector2i:
	if piece == null or board == null:
		return Vector2i(-1, -1)
	for r in range(board.rows):
		for c in range(board.cols):
			if board.grid[r][c] == piece:
				return Vector2i(c, r)
	return Vector2i(-1, -1)

# Dama do jogador mais adiantada (a mais perto do lado do chefe); sem Dama, a peça
# comum mais adiantada. Prefere peças sem aliada colada (sozinhas), com acaso.
func _pick_hammer_target() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_k: float = INF
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if not (_is_real_piece(p) and p.owner_team == human_team):
				continue
			var k: float = float(r) + randf() * 0.8
			if _has_ally_touching(Vector2i(c, r), human_team, p):
				k += 3.0
			if p.is_king:
				k -= 1000.0
			if k < best_k:
				best_k = k
				best = Vector2i(c, r)
	return best

# --- Caldeirão Fervente ---------------------------------------------------------

func _tick_cauldron(lost: int) -> Array:
	var events: Array = []
	if cauldron_fuse >= 0:
		cauldron_fuse -= 1
		if cauldron_fuse <= 0:
			events.append(_overflow())
		return events
	if lost <= 0:
		return events
	cauldron = mini(CAULDRON_MAX, cauldron + lost)
	events.append({"type": "cauldron_fill", "count": cauldron})
	if cauldron >= CAULDRON_MAX:
		cauldron_targets = _pick_cauldron_targets()
		cauldron_fuse = CAULDRON_FUSE_PLIES
		events.append({"type": "cauldron_warn", "tiles": cauldron_targets.duplicate()})
	return events

# Casas espalhadas pelo tabuleiro INTEIRO, ao acaso (vazias ou com peça), nunca
# coladas umas nas outras. No máximo CAULDRON_MAX_HITS peças de cada lado ficam
# na mira: dá para tirar uma a tempo, mas só uma por turno.
const CAULDRON_MAX_HITS := 2

func _pick_cauldron_targets() -> Array:
	var n: int = 4 + int(board.rows * board.cols / 40.0)
	var cands: Array = []
	for r in range(board.rows):
		for c in range(board.cols):
			var p := Vector2i(c, r)
			if not _is_dark(p) or board.scorched_tiles.has(p) or board.anvil_tiles.has(p):
				continue
			var q: BoardPiece = board.grid[r][c]
			if q == Board.EMPTY or _is_real_piece(q):
				cands.append(p)
	var chosen: Array = []
	var hits: Dictionary = {human_team: 0, ai_team: 0}
	var pool: Array = cands.duplicate()
	while chosen.size() < n and not pool.is_empty():
		var pick: Array = _pick_scattered(pool, 1, chosen)
		if pick.is_empty():
			break
		var p2: Vector2i = pick[0]
		pool.erase(p2)
		var q2: BoardPiece = board.grid[p2.y][p2.x]
		if q2 != Board.EMPTY:
			if int(hits[q2.owner_team]) >= CAULDRON_MAX_HITS:
				continue
			hits[q2.owner_team] = int(hits[q2.owner_team]) + 1
		chosen.append(p2)
	return chosen

func _overflow() -> Dictionary:
	var killed: Array = []
	var new_embers: Array = []
	for pos in cauldron_targets:
		var p: BoardPiece = board.grid[pos.y][pos.x]
		if _is_real_piece(p):
			board.grid[pos.y][pos.x] = Board.EMPTY
			killed.append([pos, p])
		elif p != Board.EMPTY:
			continue   # árvore/obstáculo segura o respingo
		if not board.scorched_tiles.has(pos):
			board.scorched_tiles[pos] = CAULDRON_EMBER_ROUNDS
			board.ember_tiles[pos] = true
			new_embers.append(pos)
	# brasa nunca pode travar um lado: apaga as que for preciso
	for pos in new_embers.duplicate():
		if _both_can_move():
			break
		board.scorched_tiles.erase(pos)
		board.ember_tiles.erase(pos)
		new_embers.erase(pos)
	var tiles: Array = cauldron_targets.duplicate()
	cauldron = 0
	cauldron_targets = []
	cauldron_fuse = -1
	return {"type": "cauldron", "tiles": tiles, "killed": killed, "embers": new_embers}
