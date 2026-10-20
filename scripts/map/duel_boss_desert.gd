class_name DuelBossDesert
extends DuelBoss

# Chefe do Deserto das Torres: cada run sorteia UMA destas leis (RunManager).
# Reaproveita do chefe da floresta tudo que não é a lei em si (vitória por
# eliminação, cerco, Morte Súbita anti-impasse) e as mecânicas do tabuleiro:
# casas em brasa (fire_tiles), casas bloqueadas (scorched_tiles), peça presa
# (rooted_turns) e peça neutra derrubável (is_tree).
const LAW_SUN := "scorching_sun"
const LAW_STORM := "sandstorm"
const LAW_QUICKSAND := "quicksand"
const LAW_HOURGLASS := "hourglass"
const LAW_SARCOPHAGI := "sarcophagi"
const LAW_CACTI := "cacti"
const DESERT_LAWS := [LAW_SUN, LAW_STORM, LAW_QUICKSAND, LAW_HOURGLASS, LAW_SARCOPHAGI, LAW_CACTI]

# Tudo em "jogadas" (cada lado que termina o turno = 1; 2 jogadas = 1 rodada).
const SUN_INTERVAL_PLIES := 8
const SUN_BURN_TURNS := 2             # rodadas em brasa
const STORM_INTERVAL_PLIES := 6
const STORM_COUNT := 4
const STORM_TURNS := 2                # rodadas de casa coberta
const QUICKSAND_COUNT := 4
const QUICKSAND_INTERVAL_PLIES := 8
const HOURGLASS_INTERVAL_PLIES := 8
const HOURGLASS_MIN_COLS := 4         # colunas que nunca são soterradas
const HOURGLASS_FOREVER := 9999
const SARCOPHAGUS_INTERVAL_PLIES := 6
const SARCOPHAGUS_MAX := 4
const SARCOPHAGUS_START := 2
const CACTUS_INTERVAL_PLIES := 6
const CACTUS_MAX := 5
const CACTUS_START := 3

# Casas que a lei vai afetar no próximo ciclo (o renderer as destaca).
var telegraph_tiles: Array = []
var _desert_ply: int = 0
var _buried_per_side: int = 0
var _last_sun_row: int = -1

func _init() -> void:
	if RunManager != null:
		law_id = RunManager.get_desert_boss_law_id(DESERT_LAWS)

func setup(p_board: Board, p_human_team: int, p_ai_team: int, p_sudden_death_mgr: SuddenDeathManager) -> void:
	super.setup(p_board, p_human_team, p_ai_team, p_sudden_death_mgr)
	telegraph_tiles = []
	_desert_ply = 0
	_buried_per_side = 0
	_last_sun_row = -1

func apply_board_modifiers() -> void:
	board.night_boost_team = 0
	board.mummy_team = ai_team if law_id == LAW_SARCOPHAGI else 0
	match law_id:
		LAW_SUN:
			telegraph_tiles = _plan_sun_row()
		LAW_STORM:
			telegraph_tiles = _pick_empty_dark_tiles(STORM_COUNT)
		LAW_QUICKSAND:
			_roll_quicksand()
		LAW_HOURGLASS:
			telegraph_tiles = _next_hourglass_tiles()
		LAW_SARCOPHAGI:
			for i in range(SARCOPHAGUS_START):
				_spawn_sarcophagus(true)
		LAW_CACTI:
			for i in range(CACTUS_START):
				_spawn_neutral(true, true)

func get_enemy_fixed_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = []
	match law_id:
		LAW_STORM:
			rules.append(RuleSandstorm.new())
		LAW_QUICKSAND:
			rules.append(RuleQuicksand.new())
		LAW_HOURGLASS:
			rules.append(RuleHourglass.new())
		LAW_SARCOPHAGI:
			rules.append(RuleSarcophagi.new())
		LAW_CACTI:
			rules.append(RuleCacti.new())
		_:
			rules.append(RuleScorchingSun.new())
	return rules

# Chamado UMA vez por fim de turno (de qualquer lado). Muda o estado e devolve
# os eventos pra view mostrar: [{"type": "sun"|"storm"|"quicksand"|"hourglass"|
# "sarcophagus"|"mummy", "tiles": [...]}].
func advance_turn() -> Array:
	var events: Array = []
	_desert_ply += 1
	match law_id:
		LAW_SUN:
			if _desert_ply % SUN_INTERVAL_PLIES == 0:
				for pos in telegraph_tiles:
					board.fire_tiles[pos] = SUN_BURN_TURNS
				events.append({"type": "sun", "tiles": telegraph_tiles.duplicate()})
				telegraph_tiles = _plan_sun_row()
		LAW_STORM:
			if _desert_ply % STORM_INTERVAL_PLIES == 0:
				var covered: Array = _bury(telegraph_tiles, STORM_TURNS)
				if not covered.is_empty():
					events.append({"type": "storm", "tiles": covered})
				telegraph_tiles = _pick_empty_dark_tiles(STORM_COUNT)
		LAW_QUICKSAND:
			if _desert_ply % QUICKSAND_INTERVAL_PLIES == 0:
				_roll_quicksand()
				events.append({"type": "quicksand", "tiles": board.quicksand_tiles.keys()})
		LAW_HOURGLASS:
			var new_tiles: Array = []
			if _desert_ply % HOURGLASS_INTERVAL_PLIES == 0 and _buried_per_side < _max_buried_per_side():
				_buried_per_side += 1
				new_tiles = _buried_tiles_for(_buried_per_side - 1)
			# Casas de colunas já soterradas que estavam ocupadas e esvaziaram.
			var late: Array = []
			for k in range(_buried_per_side):
				late.append_array(_buried_tiles_for(k))
			var closed: Array = _bury(late, HOURGLASS_FOREVER)
			if not new_tiles.is_empty():
				events.append({"type": "hourglass", "tiles": closed})
				telegraph_tiles = _next_hourglass_tiles()
		LAW_SARCOPHAGI:
			if _desert_ply % SARCOPHAGUS_INTERVAL_PLIES == 0:
				var pos: Vector2i = _spawn_sarcophagus(false)
				if pos != Vector2i(-1, -1):
					events.append({"type": "sarcophagus", "tiles": [pos]})
			# Múmias dos sarcófagos derrubados (por qualquer lado).
			var born: Array = []
			for pos2 in board.released_mummies:
				if board.grid[pos2.y][pos2.x] == Board.EMPTY and not board.scorched_tiles.has(pos2):
					board.grid[pos2.y][pos2.x] = BoardPiece.new(ai_team, false)
					born.append(pos2)
			board.released_mummies.clear()
			if not born.is_empty():
				events.append({"type": "mummy", "tiles": born})
		LAW_CACTI:
			if _desert_ply % CACTUS_INTERVAL_PLIES == 0:
				var cpos: Vector2i = _spawn_neutral(false, true)
				if cpos != Vector2i(-1, -1):
					events.append({"type": "cactus", "tiles": [cpos]})
	return events

func get_status_text() -> String:
	if board == null:
		return ""
	var interval: int = 0
	var label: String = ""
	match law_id:
		LAW_SUN:
			interval = SUN_INTERVAL_PLIES
			label = "O SOL ACENDE"
		LAW_STORM:
			interval = STORM_INTERVAL_PLIES
			label = "A TEMPESTADE CHEGA"
		LAW_QUICKSAND:
			interval = QUICKSAND_INTERVAL_PLIES
			label = "A AREIA SE MOVE"
		LAW_HOURGLASS:
			if _buried_per_side >= _max_buried_per_side():
				return ""
			interval = HOURGLASS_INTERVAL_PLIES
			label = "A AREIA FECHA"
		_:
			return ""
	var left: int = interval - (_desert_ply % interval)
	return "%s EM %d RODADA(S)" % [label, int(ceil(left / 2.0))]

# --- Ajudantes de casas ---------------------------------------------------

# Faixa de fileiras "do meio" (fora das fileiras de formação).
func _mid_rows() -> Vector2i:
	var deploy: int = board.get_max_deployment_rows()
	var lo: int = deploy
	var hi: int = board.rows - 1 - deploy
	if lo > hi:
		lo = 1
		hi = board.rows - 2
	return Vector2i(lo, hi)

func _is_free_dark(pos: Vector2i) -> bool:
	return (pos.x + pos.y) % 2 == 1 and board.grid[pos.y][pos.x] == Board.EMPTY \
		and not board.scorched_tiles.has(pos) and not board.fire_tiles.has(pos) and not board.quicksand_tiles.has(pos)

func _pick_empty_dark_tiles(count: int) -> Array:
	var span: Vector2i = _mid_rows()
	var cands: Array = []
	for r in range(span.x, span.y + 1):
		for c in range(board.cols):
			var p := Vector2i(c, r)
			if _is_free_dark(p):
				cands.append(p)
	cands.shuffle()
	return cands.slice(0, mini(count, cands.size()))

# Sol: uma fileira do meio inteira (casas escuras), diferente da última.
func _plan_sun_row() -> Array:
	var span: Vector2i = _mid_rows()
	var rows_ok: Array = []
	for r in range(span.x, span.y + 1):
		if r != _last_sun_row:
			rows_ok.append(r)
	if rows_ok.is_empty():
		rows_ok.append(span.x)
	_last_sun_row = rows_ok[randi() % rows_ok.size()]
	var out: Array = []
	for c in range(board.cols):
		if (c + _last_sun_row) % 2 == 1:
			out.append(Vector2i(c, _last_sun_row))
	return out

func _roll_quicksand() -> void:
	board.quicksand_tiles.clear()
	for pos in _pick_empty_dark_tiles(QUICKSAND_COUNT):
		board.quicksand_tiles[pos] = true

# Cobre de areia as casas VAZIAS dadas (bloqueio em scorched_tiles + marca visual).
# Desfaz tudo se algum lado ficasse sem jogada. Devolve as casas cobertas agora.
func _bury(tiles: Array, turns: int) -> Array:
	var applied: Array = []
	for pos in tiles:
		if board.grid[pos.y][pos.x] == Board.EMPTY and not board.scorched_tiles.has(pos):
			board.scorched_tiles[pos] = turns
			board.sand_tiles[pos] = true
			applied.append(pos)
	if applied.is_empty():
		return applied
	if board.get_all_valid_moves(human_team).is_empty() or board.get_all_valid_moves(ai_team).is_empty():
		for pos in applied:
			board.scorched_tiles.erase(pos)
			board.sand_tiles.erase(pos)
		return []
	return applied

# Ampulheta: colunas k e cols-1-k (as k-ésimas a partir de cada lado).
func _max_buried_per_side() -> int:
	return maxi(0, (board.cols - HOURGLASS_MIN_COLS) / 2)

func _buried_tiles_for(k: int) -> Array:
	var out: Array = []
	for r in range(board.rows):
		for c in [k, board.cols - 1 - k]:
			if (c + r) % 2 == 1:
				out.append(Vector2i(c, r))
	return out

func _next_hourglass_tiles() -> Array:
	if _buried_per_side >= _max_buried_per_side():
		return []
	return _buried_tiles_for(_buried_per_side)

# --- Sarcófagos ---------------------------------------------------------

func count_sarcophagi() -> int:
	var n := 0
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.is_sarcophagus:
				n += 1
	return n

# Planta um neutro (sarcófago ou cacto) numa casa escura vazia (nunca nas
# fileiras de formação) sem deixar nenhum dos lados sem jogada. Devolve a casa,
# ou (-1,-1) se não deu.
func _spawn_sarcophagus(initial: bool) -> Vector2i:
	return _spawn_neutral(initial, false)

func count_cacti() -> int:
	var n := 0
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.is_cactus:
				n += 1
	return n

func _spawn_neutral(initial: bool, cactus: bool) -> Vector2i:
	if cactus and count_cacti() >= CACTUS_MAX:
		return Vector2i(-1, -1)
	if not cactus and count_sarcophagi() >= SARCOPHAGUS_MAX:
		return Vector2i(-1, -1)
	var span: Vector2i = _mid_rows()
	var r_min: int = span.x if initial else 1
	var r_max: int = span.y if initial else board.rows - 2
	var cands: Array = []
	for r in range(r_min, r_max + 1):
		for c in range(board.cols):
			var p := Vector2i(c, r)
			if (c + r) % 2 == 1 and board.grid[r][c] == Board.EMPTY and not board.scorched_tiles.has(p) and not board.fire_tiles.has(p):
				cands.append(p)
	cands.shuffle()
	for pos in cands:
		board.grid[pos.y][pos.x] = BoardPiece.make_cactus() if cactus else BoardPiece.make_sarcophagus()
		if not board.get_all_valid_moves(human_team).is_empty() and not board.get_all_valid_moves(ai_team).is_empty():
			return pos
		board.grid[pos.y][pos.x] = Board.EMPTY
	return Vector2i(-1, -1)
