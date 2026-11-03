class_name DuelBoss
extends DuelHard

# Leis temáticas do chefe da floresta: cada run sorteia UMA (RunManager).
const LAW_FROG := "frog_devourer"
const LAW_OWL := "owl_night"
const LAW_FOREST := "closing_forest"
const LAW_VINES := "vines"
const LAW_FIREFLIES := "fireflies"
const LAW_ROOTS := "hungry_roots"
const LAWS := [LAW_FROG, LAW_OWL, LAW_FOREST, LAW_VINES, LAW_FIREFLIES, LAW_ROOTS]

# Leis das casas CLARAS (Cipós / Vaga-lumes): quantos e de quanto em quanto tempo.
const VINE_COUNT := 3
const VINE_INTERVAL_PLIES := 8       # 8 jogadas = 4 rodadas
const FIREFLY_COUNT := 3
const FIREFLY_INTERVAL_PLIES := 2    # 1 passo por rodada
const FIREFLY_ANIM_MS := 600

# Ciclo em "jogadas" (cada lado que termina o turno = 1): 6 jogadas = 3 rodadas.
const DAY_PLIES := 6
const NIGHT_PLIES := 6
const FOG_RADIUS := 2
const TREE_INTERVAL_PLIES := 6
const TREE_MAX := 6
const TREE_START_COUNT := 2

var law_id: String = LAW_FROG
var is_night: bool = false
var _phase_ply: int = 0
var _tree_ply: int = 0
var _vine_ply: int = 0
var _firefly_ply: int = 0
# Próximo passo de cada vaga-lume (Vector2i origem -> destino), mostrado no tabuleiro.
var firefly_plan: Dictionary = {}
# Último passo (pra o renderer deslizar a luz): [{"from","to","t0"(ms)}]
var firefly_moves: Array = []

func _init() -> void:
	if RunManager != null:
		law_id = RunManager.get_forest_boss_law_id(LAWS)

var hazard_tiles: Array = []
const FLIES_PER_TURN: int = 3
const TURNS_BETWEEN_FLIES: int = 3

var _turns_since_last_bite: int = 0
var should_trigger_devour: bool = false
var should_spawn_new_flies: bool = false
var pending_devour_tiles: Array = []

func setup(p_board: Board, p_human_team: int, p_ai_team: int, p_sudden_death_mgr: SuddenDeathManager) -> void:
	super.setup(p_board, p_human_team, p_ai_team, p_sudden_death_mgr)
	if p_sudden_death_mgr != null:
		p_sudden_death_mgr.stall_only = true
	hazard_tiles = []
	_turns_since_last_bite = 0
	should_trigger_devour = false
	should_spawn_new_flies = false
	pending_devour_tiles.clear()
	is_night = false
	_phase_ply = 0
	_tree_ply = 0
	_vine_ply = 0
	_firefly_ply = 0
	firefly_plan = {}
	firefly_moves = []

func apply_board_modifiers() -> void:
	board.night_boost_team = 0
	match law_id:
		LAW_FROG:
			_roll_fly_tiles()
			should_spawn_new_flies = true
		LAW_FOREST:
			for i in range(TREE_START_COUNT):
				_spawn_tree(true)
		LAW_VINES:
			_roll_vines()
		LAW_FIREFLIES:
			_spawn_fireflies()
		LAW_ROOTS:
			board.hungry_roots_team = human_team

# O chefe não herda a Coroa de Ferro do Duelo Forte: o slot inimigo mostra
# o Sapo Devorador (Lei só descritiva — a mecânica vive aqui e na view do sapo).
func get_enemy_fixed_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = []
	match law_id:
		LAW_OWL:
			rules.append(RuleOwlNight.new())
		LAW_FOREST:
			rules.append(RuleClosingForest.new())
		LAW_VINES:
			rules.append(RuleVines.new())
		LAW_FIREFLIES:
			rules.append(RuleFireflies.new())
		LAW_ROOTS:
			rules.append(RuleHungryRoots.new())
		_:
			rules.append(RuleFrogDevourer.new())
	return rules

# O Chefe usa a Morte Súbita só como anti-impasse (poucas peças/só Damas e
# ninguém captura): ver SuddenDeathManager.stall_only. Vitória normal continua
# sendo a eliminação total.
func uses_sudden_death() -> bool:
	return true

func requires_full_elimination() -> bool:
	return true

# Cerco total: o Chefe exige eliminação, mas se TODAS as peças dele ficam
# bloqueadas (por si mesmas / bordas / árvores) e continuam assim por vários
# turnos seguidos, o duelo nunca acabaria (ele não joga e o jogador não
# consegue capturar nada). Isso conta como vitória do jogador.
const BLOCKED_TURNS_TO_WIN: int = 2
var _ai_blocked_streak: int = 0

func note_ai_turn(had_move: bool) -> void:
	_ai_blocked_streak = 0 if had_move else _ai_blocked_streak + 1

func on_turn_end(_board: Board) -> void:
	if law_id != LAW_FROG:
		return
	_turns_since_last_bite += 1

	if _turns_since_last_bite >= TURNS_BETWEEN_FLIES:
		should_trigger_devour = true
		pending_devour_tiles = hazard_tiles.duplicate()
		should_spawn_new_flies = true
		_turns_since_last_bite = 0

# Chamado de fora (duel_turn_controller) bem na hora de nascer as moscas
# novas — NÃO em on_turn_end(), porque rolar ali de imediato deixava
# hazard_tiles apontando pra fileira seguinte de casas ENQUANTO o ataque
# de língua nas casas antigas (pending_devour_tiles) ainda nem tinha
# começado a animar. Como o destaque vermelho do tabuleiro é desenhado a
# partir de hazard_tiles, isso fazia as casas novas aparecerem vermelhas
# cedo demais, antes de qualquer mosca ter nascido lá.
func roll_next_hazard_tiles() -> void:
	_roll_fly_tiles()

func _roll_fly_tiles() -> void:
	hazard_tiles.clear()

	var candidates: Array = []
	for r in range(board.rows):
		for c in range(board.cols):
			if (r + c) % 2 == 1:
				candidates.append(Vector2i(c, r))

	candidates.shuffle()
	var count = min(FLIES_PER_TURN, candidates.size())
	for i in range(count):
		hazard_tiles.append(candidates[i])

func check_custom_victory() -> Dictionary:
	var ai_pieces_remaining = board.count_pieces(ai_team)

	if ai_pieces_remaining > 0 and _ai_blocked_streak >= BLOCKED_TURNS_TO_WIN:
		return {
			"ended": true,
			"won": true,
			"title": "CHEFAO ENCURRALADO!",
			"details": ""
		}

	if ai_pieces_remaining == 0:
		return {
			"ended": true,
			"won": true,
			"title": "CHEFAO DERROTADO!",
			"details": ""
		}

	return {"ended": false, "won": false, "title": "", "details": ""}

# --- Noite da Coruja / A Floresta Fecha ---

# Chamado UMA vez por fim de turno (de qualquer lado) pelo controller. Muda o
# estado (fase, árvores) e devolve os eventos pra view animar:
# [{"type": "night"|"dawn"|"trees", "tiles": [...]}]
func advance_turn() -> Array:
	var events: Array = []
	match law_id:
		LAW_OWL:
			_phase_ply += 1
			var limit = NIGHT_PLIES if is_night else DAY_PLIES
			if _phase_ply >= limit:
				_phase_ply = 0
				is_night = not is_night
				board.night_boost_team = ai_team if is_night else 0
				events.append({"type": "night" if is_night else "dawn", "tiles": []})
		LAW_FOREST:
			_tree_ply += 1
			if _tree_ply >= TREE_INTERVAL_PLIES:
				_tree_ply = 0
				var pos = _spawn_tree(false)
				if pos != Vector2i(-1, -1):
					events.append({"type": "trees", "tiles": [pos]})
		LAW_VINES:
			_vine_ply += 1
			if _vine_ply >= VINE_INTERVAL_PLIES:
				_vine_ply = 0
				_roll_vines()
				events.append({"type": "vines", "tiles": board.vine_tiles.keys()})
		LAW_FIREFLIES:
			_firefly_ply += 1
			if _firefly_ply >= FIREFLY_INTERVAL_PLIES:
				_firefly_ply = 0
				_move_fireflies()
				events.append({"type": "fireflies", "tiles": board.firefly_tiles.keys()})
	return events

# --- Cipós / Vaga-lumes (casas CLARAS: (r+c) par; nenhuma peça pisa nelas) ---

# Casas claras do miolo do tabuleiro (a travessia do cipó precisa de casa dos
# dois lados, então ficam longe das bordas).
func _light_tiles(margin: int) -> Array:
	var out: Array = []
	for r in range(margin, board.rows - margin):
		for c in range(margin, board.cols - margin):
			if (r + c) % 2 == 0:
				out.append(Vector2i(c, r))
	return out

func _roll_vines() -> void:
	board.vine_tiles.clear()
	var tiles: Array = _light_tiles(1)
	tiles.shuffle()
	for i in range(mini(VINE_COUNT, tiles.size())):
		board.vine_tiles[tiles[i]] = true

func _spawn_fireflies() -> void:
	board.firefly_tiles.clear()
	var tiles: Array = _light_tiles(1)
	tiles.shuffle()
	for i in range(mini(FIREFLY_COUNT, tiles.size())):
		board.firefly_tiles[tiles[i]] = true
	firefly_moves = []
	_plan_fireflies()

# Sorteia o próximo passo de cada vaga-lume (diagonal = casa clara vizinha).
func _plan_fireflies() -> void:
	firefly_plan = {}
	var taken: Dictionary = board.firefly_tiles.duplicate()
	var flies: Array = board.firefly_tiles.keys()
	flies.shuffle()
	for pos in flies:
		var options: Array = []
		for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var q: Vector2i = pos + d
			if q.x < 0 or q.y < 0 or q.x >= board.cols or q.y >= board.rows:
				continue
			if taken.has(q):
				continue
			options.append(q)
		if options.is_empty():
			firefly_plan[pos] = pos
			continue
		var dest: Vector2i = options[randi() % options.size()]
		taken[dest] = true
		firefly_plan[pos] = dest

func _move_fireflies() -> void:
	var now: int = Time.get_ticks_msec()
	firefly_moves = []
	var new_tiles: Dictionary = {}
	for pos in board.firefly_tiles.keys():
		var dest: Vector2i = firefly_plan.get(pos, pos)
		new_tiles[dest] = true
		if dest != pos:
			firefly_moves.append({"from": pos, "to": dest, "t0": now})
	board.firefly_tiles = new_tiles
	_plan_fireflies()

func count_trees() -> int:
	var n = 0
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.is_tree:
				n += 1
	return n

# Planta uma árvore numa casa escura vazia (nunca nas fileiras de promoção) sem
# deixar nenhum dos lados sem jogada. Devolve a casa, ou (-1,-1) se não deu.
func _spawn_tree(initial: bool) -> Vector2i:
	if count_trees() >= TREE_MAX:
		return Vector2i(-1, -1)
	var deploy = board.get_max_deployment_rows()
	var r_min = deploy if initial else 1
	var r_max = board.rows - 1 - deploy if initial else board.rows - 2
	var candidates: Array = []
	for r in range(r_min, r_max + 1):
		for c in range(board.cols):
			if (r + c) % 2 == 1 and board.grid[r][c] == Board.EMPTY and not board.scorched_tiles.has(Vector2i(c, r)):
				candidates.append(Vector2i(c, r))
	candidates.shuffle()
	for pos in candidates:
		board.grid[pos.y][pos.x] = BoardPiece.make_tree()
		if not board.get_all_valid_moves(human_team).is_empty() and not board.get_all_valid_moves(ai_team).is_empty():
			return pos
		board.grid[pos.y][pos.x] = Board.EMPTY
	return Vector2i(-1, -1)

func get_darkness() -> float:
	return 0.45 if (law_id == LAW_OWL and is_night) else 0.0

func get_status_text() -> String:
	if law_id != LAW_OWL:
		return ""
	var limit = NIGHT_PLIES if is_night else DAY_PLIES
	var rounds_left = int(ceil((limit - _phase_ply) / 2.0))
	if is_night:
		return "NOITE - amanhece em %d rodada(s)" % rounds_left
	return "DIA - anoitece em %d rodada(s)" % rounds_left

# Névoa da Noite da Coruja: é uma propriedade da CASA (não de quem está nela):
# toda casa a mais de FOG_RADIUS de qualquer peça do jogador está no escuro. O
# renderer cobre todas elas igual e só esconde a peça do chefe que estiver lá —
# assim a névoa não entrega onde há peças.
func is_fogged(pos: Vector2i) -> bool:
	return fog_strength(pos) > 0.0

# 0 = visível; sobe com a distância até a peça do jogador mais próxima.
func fog_strength(pos: Vector2i) -> float:
	if law_id != LAW_OWL or not is_night or board == null:
		return 0.0
	var best = 99
	for r in range(board.rows):
		for c in range(board.cols):
			var q: BoardPiece = board.grid[r][c]
			if q != Board.EMPTY and q.owner_team == human_team:
				best = min(best, max(abs(r - pos.y), abs(c - pos.x)))
	if best <= FOG_RADIUS:
		return 0.0
	return clampf(0.45 + 0.15 * (best - FOG_RADIUS - 1), 0.45, 0.8)
