class_name DuelBossMine
extends DuelBoss

# Chefe da Mina dos Cristais (o Garimpeiro Cego): cada run sorteia UMA destas
# leis (RunManager). Herda do chefe da floresta a vitória por eliminação, o
# cerco e a Morte Súbita anti-impasse. As mecânicas de tabuleiro novas vivem em
# Board (crystal_tiles, rail_lines, nugget_tiles, rocha = BoardPiece.is_rock).
const LAW_LANTERN := "lantern"
const LAW_RICOCHET := "ricochet"
const LAW_CAVE_IN := "cave_in"
const LAW_RAILS := "rails"
const LAW_NUGGETS := "nuggets"
const MINE_LAWS := [LAW_LANTERN, LAW_RICOCHET, LAW_CAVE_IN, LAW_RAILS, LAW_NUGGETS]

# Tudo em "jogadas" (cada lado que termina o turno = 1; 2 jogadas = 1 rodada).
# Lampião: acende a cada 2 turnos DO CHEFE (logo depois da jogada dele, para a
# ofuscação valer na sua jogada seguinte).
const LANTERN_EVERY_BOSS_TURNS := 2
const CRYSTAL_START := 3
const CRYSTAL_INTERVAL_PLIES := 6
const CRYSTAL_MAX := 6
const CAVE_INTERVAL_PLIES := 8
const CAVE_WARN_PLIES := 4           # as rachaduras aparecem 2 rodadas antes
const CAVE_COUNT := 3
const ROCK_MAX := 8
const RAIL_COUNT := 2
const RAIL_MIN_LEN := 5
const NUGGET_START := 2
const NUGGET_INTERVAL_PLIES := 4
const NUGGET_MAX := 3

# Casas marcadas para o próximo efeito (Lampião: a diagonal da vez; Desabamento:
# as rachaduras). O renderer desenha.
var telegraph_tiles: Array = []
# Quem acabou de jogar (o controlador preenche antes de advance_turn).
var mover_team: int = 0
# Momento (ms) do último clarão do lampião e as casas dele, para a view.
var lantern_flash_t0: int = -100000
var lantern_flash_tiles: Array = []
var _mine_ply: int = 0
var _boss_turns: int = 0
var _beam_lines: Array = []          # diagonais do lampião, em ordem de varredura
var _beam_idx: int = 0
var _beam_dir: int = 1

func _init() -> void:
	if RunManager != null:
		law_id = RunManager.get_mine_boss_law_id(MINE_LAWS)

func setup(p_board: Board, p_human_team: int, p_ai_team: int, p_sudden_death_mgr: SuddenDeathManager) -> void:
	super.setup(p_board, p_human_team, p_ai_team, p_sudden_death_mgr)
	telegraph_tiles = []
	_mine_ply = 0
	_boss_turns = 0
	lantern_flash_tiles = []
	lantern_flash_t0 = -100000

func apply_board_modifiers() -> void:
	board.night_boost_team = 0
	match law_id:
		LAW_LANTERN:
			_build_beam_lines()
			telegraph_tiles = _beam_lines[_beam_idx] if not _beam_lines.is_empty() else []
		LAW_RICOCHET:
			for i in range(CRYSTAL_START):
				_spawn_crystal()
		LAW_RAILS:
			_build_rails()
		LAW_NUGGETS:
			for i in range(NUGGET_START):
				_spawn_nugget()

func get_enemy_fixed_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = []
	match law_id:
		LAW_RICOCHET:
			rules.append(RuleRicochet.new())
		LAW_CAVE_IN:
			rules.append(RuleCaveIn.new())
		LAW_RAILS:
			rules.append(RuleRails.new())
		LAW_NUGGETS:
			rules.append(RuleNuggets.new())
		_:
			rules.append(RuleLantern.new())
	return rules

# Chamado UMA vez por fim de turno (de qualquer lado). Muda o estado e devolve
# os eventos para a view: [{"type": "lantern"|"crystal"|"cave_warn"|"cave_in"|"nugget_spawn", ...}]
func advance_turn() -> Array:
	var events: Array = []
	_mine_ply += 1
	match law_id:
		LAW_LANTERN:
			if mover_team == ai_team:
				_boss_turns += 1
				if _boss_turns % LANTERN_EVERY_BOSS_TURNS == 0 and not telegraph_tiles.is_empty():
					var hit: Array = _fire_lantern(telegraph_tiles)
					lantern_flash_t0 = Time.get_ticks_msec()
					lantern_flash_tiles = telegraph_tiles.duplicate()
					events.append({"type": "lantern", "tiles": lantern_flash_tiles.duplicate(), "hit": hit})
					_advance_beam()
		LAW_RICOCHET:
			if _mine_ply % CRYSTAL_INTERVAL_PLIES == 0:
				var cpos: Vector2i = _spawn_crystal()
				if cpos != Vector2i(-1, -1):
					events.append({"type": "crystal", "tiles": [cpos]})
		LAW_CAVE_IN:
			var phase: int = _mine_ply % CAVE_INTERVAL_PLIES
			if phase == CAVE_INTERVAL_PLIES - CAVE_WARN_PLIES:
				telegraph_tiles = _pick_cave_tiles()
				if not telegraph_tiles.is_empty():
					events.append({"type": "cave_warn", "tiles": telegraph_tiles.duplicate()})
			elif phase == 0 and not telegraph_tiles.is_empty():
				var res: Dictionary = _collapse(telegraph_tiles)
				telegraph_tiles = []
				events.append({"type": "cave_in", "tiles": res["tiles"], "rocks": res["rocks"], "killed": res["killed"]})
		LAW_NUGGETS:
			if _mine_ply % NUGGET_INTERVAL_PLIES == 0:
				var npos: Vector2i = _spawn_nugget()
				if npos != Vector2i(-1, -1):
					events.append({"type": "nugget_spawn", "tiles": [npos]})
	return events

# Lampião: acende logo depois da próxima jogada do chefe?
func lantern_soon() -> bool:
	return law_id == LAW_LANTERN and (_boss_turns + 1) % LANTERN_EVERY_BOSS_TURNS == 0

func get_status_text() -> String:
	if board == null:
		return ""
	match law_id:
		LAW_LANTERN:
			var left: int = LANTERN_EVERY_BOSS_TURNS - (_boss_turns % LANTERN_EVERY_BOSS_TURNS)
			return "O LAMPIÃO ACENDE EM %d RODADA(S)" % left
		LAW_CAVE_IN:
			var left2: int = CAVE_INTERVAL_PLIES - (_mine_ply % CAVE_INTERVAL_PLIES)
			if telegraph_tiles.is_empty():
				return ""
			return "O TETO DESABA EM %d RODADA(S)" % int(ceil(left2 / 2.0))
	return ""

# --- Ajudantes ------------------------------------------------------------

func _is_free_dark(pos: Vector2i) -> bool:
	return (pos.x + pos.y) % 2 == 1 and board.grid[pos.y][pos.x] == Board.EMPTY \
		and not board.scorched_tiles.has(pos) and not board.fire_tiles.has(pos) and not board.nugget_tiles.has(pos)

func _free_dark_cells() -> Array:
	var cands: Array = []
	for r in range(1, board.rows - 1):
		for c in range(board.cols):
			var p := Vector2i(c, r)
			if _is_free_dark(p):
				cands.append(p)
	return cands

# Escolha espalhada: prefere a casa mais longe de `avoid`, com um pouco de acaso.
func _pick_spread(cands: Array, count: int, avoid_in: Array) -> Array:
	var avoid: Array = avoid_in.duplicate()
	var pool: Array = cands.duplicate()
	var chosen: Array = []
	while chosen.size() < count and not pool.is_empty():
		var best: Vector2i = pool[0]
		var best_score: float = -1.0
		for p in pool:
			var d: float = 99.0
			for a in avoid:
				d = minf(d, absf(p.x - a.x) + 1.5 * absf(p.y - a.y))
			var score: float = d + randf() * 1.6
			if score > best_score:
				best_score = score
				best = p
		chosen.append(best)
		avoid.append(best)
		pool.erase(best)
	return chosen

func _both_can_move() -> bool:
	return not board.get_all_valid_moves(human_team).is_empty() and not board.get_all_valid_moves(ai_team).is_empty()

# --- Lampião ----------------------------------------------------------------

# Diagonais "/" (x + y constante) com 3+ casas escuras jogáveis, da esquerda
# para a direita. O feixe anda uma diagonal por vez e volta ao chegar na ponta.
func _build_beam_lines() -> void:
	_beam_lines = []
	for k in range(1, board.rows + board.cols - 2):
		if k % 2 == 0:
			continue
		var cells: Array = []
		for r in range(1, board.rows - 1):
			var c: int = k - r
			if c >= 0 and c < board.cols:
				cells.append(Vector2i(c, r))
		if cells.size() >= 3:
			_beam_lines.append(cells)
	# começa perto do meio, para não gastar os primeiros acendimentos na ponta
	@warning_ignore("integer_division")
	_beam_idx = clampi(_beam_lines.size() / 2 - 1, 0, maxi(0, _beam_lines.size() - 1))
	_beam_dir = 1 if randf() < 0.5 else -1

func _advance_beam() -> void:
	if _beam_lines.size() < 2:
		return
	var nxt: int = _beam_idx + _beam_dir
	if nxt < 0 or nxt >= _beam_lines.size():
		_beam_dir = -_beam_dir
		nxt = _beam_idx + _beam_dir
	_beam_idx = nxt
	telegraph_tiles = _beam_lines[_beam_idx]

# Ofusca as peças do jogador na diagonal: perdem a próxima jogada (a trava é a
# mesma da Emboscada). Nunca deixa o jogador sem nenhuma jogada.
func _fire_lantern(tiles: Array) -> Array:
	var hit: Array = []
	for pos in tiles:
		var p: BoardPiece = board.grid[pos.y][pos.x]
		if p != Board.EMPTY and p.owner_team == human_team:
			p.rooted_turns = maxi(p.rooted_turns, 1)
			p.dazzled = true
			hit.append(pos)
	if not hit.is_empty() and board.get_all_valid_moves(human_team).is_empty():
		for pos in hit:
			board.grid[pos.y][pos.x].rooted_turns = 0
		return []
	return hit

# --- Ricochete ----------------------------------------------------------------

func count_crystals() -> int:
	return board.crystal_tiles.size()

func _spawn_crystal() -> Vector2i:
	if count_crystals() >= CRYSTAL_MAX:
		return Vector2i(-1, -1)
	var order: Array = _pick_spread(_free_dark_cells(), 999, board.crystal_tiles.keys())
	for pos in order:
		board.crystal_tiles[pos] = true
		board.scorched_tiles[pos] = 99999
		if _both_can_move():
			return pos
		board.crystal_tiles.erase(pos)
		board.scorched_tiles.erase(pos)
	return Vector2i(-1, -1)

# --- Desabamento ----------------------------------------------------------------

func count_rocks() -> int:
	var n := 0
	for r in range(board.rows):
		for c in range(board.cols):
			var p: BoardPiece = board.grid[r][c]
			if p != Board.EMPTY and p.is_rock:
				n += 1
	return n

# Rachaduras: casas escuras jogáveis (com ou sem peça), longe das rochas e umas
# das outras. Nunca em cima de uma rocha/neutro.
func _pick_cave_tiles() -> Array:
	var cands: Array = []
	var rocks: Array = []
	for r in range(1, board.rows - 1):
		for c in range(board.cols):
			var p := Vector2i(c, r)
			if (c + r) % 2 == 0 or board.scorched_tiles.has(p):
				continue
			var q: BoardPiece = board.grid[r][c]
			if q != Board.EMPTY and q.is_tree:
				rocks.append(p)
				continue
			cands.append(p)
	return _pick_spread(cands, CAVE_COUNT, rocks)

# Desaba: destrói a peça que estiver na casa e deixa a rocha. Se a rocha
# deixaria algum lado sem jogada (ou já há rochas demais), a casa fica vazia.
func _collapse(tiles: Array) -> Dictionary:
	var killed: Array = []        # [[pos, peça]]
	var rocks: Array = []
	for pos in tiles:
		var q: BoardPiece = board.grid[pos.y][pos.x]
		if q != Board.EMPTY and q.is_tree:
			continue
		if q != Board.EMPTY:
			killed.append([pos, q])
		board.grid[pos.y][pos.x] = Board.EMPTY
		if count_rocks() < ROCK_MAX:
			board.grid[pos.y][pos.x] = BoardPiece.make_rock()
			rocks.append(pos)
	# rocha que trava alguém sai (de trás para frente)
	while not rocks.is_empty() and not _both_can_move():
		var last: Vector2i = rocks.pop_back()
		board.grid[last.y][last.x] = Board.EMPTY
	return {"tiles": tiles.duplicate(), "rocks": rocks, "killed": killed}

# --- Trilhos ----------------------------------------------------------------

# Duas diagonais longas (uma "/" e uma "\" quando dá), sem as fileiras das
# pontas (assim a vagoneta não coroa ninguém de graça) e sem pontas em comum.
func _build_rails() -> void:
	board.rail_lines.clear()
	var families: Array = [[], []]
	for k in range(-board.rows, board.rows + board.cols):
		if (k % 2 + 2) % 2 == 0:
			continue
		var a: Array = []
		var d: Array = []
		for r in range(1, board.rows - 1):
			var c1: int = k - r          # "/" : x + y = k
			if c1 >= 0 and c1 < board.cols:
				a.append(Vector2i(c1, r))
			var c2: int = k + r          # "\" : x - y = k
			if c2 >= 0 and c2 < board.cols:
				d.append(Vector2i(c2, r))
		if a.size() >= RAIL_MIN_LEN:
			families[0].append(a)
		if d.size() >= RAIL_MIN_LEN:
			families[1].append(d)
	var all: Array = []
	for f in range(2):
		for line in families[f]:
			all.append([f, line])
	all.shuffle()
	var picked: Array = []
	var picked_fam: Array = []
	# 1º passe: famílias diferentes ("/" e "\"); 2º passe: aceita paralelas.
	for pass_i in range(2):
		for item in all:
			if picked.size() >= RAIL_COUNT:
				break
			if pass_i == 0 and picked_fam.has(item[0]):
				continue
			if picked.has(item[1]):
				continue
			# trilhos sem casa em comum (cruzamento confundiria quem embarca onde)
			var ok := true
			for other in picked:
				for e in item[1]:
					if other.has(e):
						ok = false
			if ok:
				picked.append(item[1])
				picked_fam.append(item[0])
	for line in picked:
		board.rail_lines.append({"a": line[0], "b": line[line.size() - 1], "cells": line})

# --- Garimpo ----------------------------------------------------------------

func _spawn_nugget() -> Vector2i:
	if board.nugget_tiles.size() >= NUGGET_MAX:
		return Vector2i(-1, -1)
	# longe das outras pepitas
	var picks: Array = _pick_spread(_free_dark_cells(), 1, board.nugget_tiles.keys())
	if picks.is_empty():
		return Vector2i(-1, -1)
	board.nugget_tiles[picks[0]] = true
	return picks[0]
