class_name DuelBase
extends RefCounted

var board: Board
var human_team: int = Board.WHITE
var ai_team: int = Board.BLACK
var captures_by_player: int = 0
# Duelo dentro de uma tempestade de areia (mapa do Deserto). null = duelo normal.
var sandstorm: SandstormMod = null
# Cume: duelo em cima de uma ponte de corda (null = normal) / num glaciar de gelo fino.
var bridge: BridgeMod = null
var thin_ice: bool = false
# Caldeira: duelo chamuscado pela erupção (casas em brasa) / na ilha de basalto da maré.
var embers: bool = false
var island: bool = false
const EMBER_PAIRS: int = 2            # pares espelhados de casas em brasa (+1 em tabuleiro grande)
const EMBER_TURNS := Vector2i(3, 6)   # rodadas até cada par esfriar

func setup(p_board: Board, p_human_team: int, p_ai_team: int, _sudden_death_mgr: SuddenDeathManager) -> void:
	board = p_board
	human_team = p_human_team
	ai_team = p_ai_team
	captures_by_player = 0
	if RunManager != null:
		RunManager.reset_effect_gold()
	sandstorm = null
	if RunManager != null and RunManager.current_node_storm and not TutorialManager.is_active and not (self is DuelBoss):
		sandstorm = SandstormMod.new()
		sandstorm.setup(p_board, p_human_team, p_ai_team, self is DuelHard)
	bridge = null
	thin_ice = false
	if RunManager != null and not TutorialManager.is_active and not (self is DuelBoss):
		if RunManager.current_node_bridge:
			bridge = BridgeMod.new()
			bridge.setup(p_board, p_human_team, p_ai_team)
		if RunManager.current_node_glacier:
			thin_ice = true
			p_board.thin_ice = true
	embers = false
	island = false
	if RunManager != null and not TutorialManager.is_active and not (self is DuelBoss):
		if RunManager.current_node_island:
			island = true
			_place_island_lava(p_board)
		if RunManager.current_node_scorched:
			embers = true
			_place_embers(p_board)

# Ilha de basalto: as três casas de cada quina do tabuleiro viram lava (até o fim do
# duelo), menos as que já começam com peça (ninguém perde peça; o desenho é simétrico
# por meia-volta e as disposições também, então os dois lados ficam iguais).
func _place_island_lava(b: Board) -> void:
	var r1: int = b.rows - 1
	var c1: int = b.cols - 1
	var cells: Array = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(c1, 0), Vector2i(c1 - 1, 0), Vector2i(c1, 1),
		Vector2i(0, r1), Vector2i(1, r1), Vector2i(0, r1 - 1),
		Vector2i(c1, r1), Vector2i(c1 - 1, r1), Vector2i(c1, r1 - 1),
	]
	for pos in cells:
		if not b.is_valid_pos(pos.y, pos.x) or b.grid[pos.y][pos.x] != Board.EMPTY:
			continue
		b.scorched_tiles[pos] = Board.WATER_ROUNDS
		b.lava_tiles[pos] = true

# Duelo chamuscado: pares de casas escuras (onde as peças andam) em brasa no miolo,
# espelhados por meia-volta; cada par esfria depois de algumas rodadas.
func _place_embers(b: Board) -> void:
	var pairs: int = EMBER_PAIRS + (1 if b.rows * b.cols >= 80 else 0)
	var cand: Array = []
	for r in range(2, b.rows - 2):
		for c in range(b.cols):
			var pos := Vector2i(c, r)
			var mirror := Vector2i(b.cols - 1 - c, b.rows - 1 - r)
			if (r + c) % 2 == 0 or pos == mirror:
				continue
			if b.grid[r][c] != Board.EMPTY or b.grid[mirror.y][mirror.x] != Board.EMPTY:
				continue
			if b.scorched_tiles.has(pos) or b.scorched_tiles.has(mirror):
				continue
			if r * b.cols + c < mirror.y * b.cols + mirror.x:
				cand.append(pos)
	cand.shuffle()
	var used: Array = []
	for pos in cand:
		if used.size() >= pairs:
			break
		var near := false
		for u in used:
			if absi(u.x - pos.x) + absi(u.y - pos.y) < 3:
				near = true
		if near:
			continue
		used.append(pos)
		var turns: int = randi_range(EMBER_TURNS.x, EMBER_TURNS.y)
		for p in [pos, Vector2i(b.cols - 1 - pos.x, b.rows - 1 - pos.y)]:
			b.scorched_tiles[p] = turns
			b.ember_tiles[p] = true

# Duelo com perigo de terreno (tempestade, ponte, gelo fino): paga mais e dá Lei.
func is_hazard() -> bool:
	return sandstorm != null or bridge != null or thin_ice or embers or island

func hazard_label() -> String:
	if island:
		return "ILHA:"
	if embers:
		return "BRASA:"
	if bridge != null:
		return "PONTE:"
	if thin_ice:
		return "GELO FINO:"
	return "TEMPESTADE:"

func apply_board_modifiers() -> void:
	pass

# Chamado só quando o JOGADOR captura uma peça (e ela de fato morre) — base
# do ouro de capturas. Capturas da IA e capturas impedidas não passam por aqui.
func on_piece_captured(captured_piece: BoardPiece) -> void:
	if captured_piece != null and captured_piece.is_tree:
		return # árvores não rendem ouro
	captures_by_player += 1

func on_turn_end(_board: Board) -> void:
	pass

func check_custom_victory() -> Dictionary:
	return {"ended": false, "won": false, "title": "", "details": ""}

# Visual do tabuleiro (lido pelo BoardRenderer): escuridão 0..1 sobre o
# tabuleiro, texto de status acima dele e névoa por casa.
func get_darkness() -> float:
	return 0.0

func get_status_text() -> String:
	if sandstorm != null:
		return sandstorm.get_status_text()
	if bridge != null:
		return bridge.get_status_text()
	if island:
		return "ILHA DE BASALTO: CANTOS EM LAVA · OURO EM DOBRO"
	if embers and board != null:
		return "CHAMUSCADO: CASAS EM BRASA ESFRIAM COM AS RODADAS (%d)" % board.ember_tiles.size()
	if thin_ice and board != null:
		return "GELO FINO: A CASA TRINCA NA 1ª SAÍDA E AFUNDA NA 2ª (%d/%d)" % [board.water_tiles.size(), board.thin_ice_hole_cap()]
	return ""

func is_fogged(pos: Vector2i) -> bool:
	return fog_strength(pos) > 0.0

# 0 = visível; > 0 = casa encoberta (a peça inimiga ali some).
func fog_strength(pos: Vector2i) -> float:
	return sandstorm.fog_strength(pos) if sandstorm != null else 0.0

# Cor da névoa: azulada (noite) por padrão; areia na tempestade.
func fog_color() -> Color:
	return Color(0.86, 0.66, 0.38) if sandstorm != null else Color(0.42, 0.48, 0.66)

func uses_sudden_death() -> bool:
	return true

func requires_full_elimination() -> bool:
	return false

# Chamado pelo controller a cada turno da IA: false = ela não tinha nenhum
# movimento válido (exército totalmente bloqueado). Só o Chefe usa.
func note_ai_turn(_had_move: bool) -> void:
	pass

# --- Lado inimigo (configurado por dificuldade; main.gd monta o duelo a partir daqui) ---

# Leis fixas do modo (ex: Coroa de Ferro, Sapo Devorador). Aparecem na HUD inimiga.
func get_enemy_fixed_rules() -> Array[RuleCard]:
	return []

# Quantas Leis aleatórias (LootTables.get_random_ai_rules) a IA recebe além das fixas.
func get_enemy_random_rule_count() -> int:
	return EnemyScaling.standard_rules()

# Tamanho do baralho de Cartas de Ação da IA (LootTables.get_ai_starting_deck).
func get_enemy_card_count() -> int:
	return EnemyScaling.standard_cards()

# Recompensa em ouro (economia: duelo comum ~7-18, elite ~13-26): base fixa +
# capturas (com teto) + peças vivas (1 de ouro a cada 3, com teto).
const CAPTURE_GOLD_CAP: int = 6
const SURVIVAL_GOLD_CAP: int = 6

func get_base_gold() -> int:
	return 6

func get_capture_gold() -> int:
	return mini(captures_by_player, CAPTURE_GOLD_CAP)

func get_survival_gold(alive: int) -> int:
	return mini(int(ceil(float(alive) / 3.0)), SURVIVAL_GOLD_CAP)

# Bônus pelo JEITO de vencer: capturar todas as peças ("elimination") ou deixar o
# inimigo sem nenhuma jogada ("blockade", mais difícil, paga mais).
const FINISH_ELIMINATION_GOLD: int = 3
const FINISH_BLOCKADE_GOLD: int = 6

func get_finish_gold(win_kind: String) -> int:
	var hard: bool = self is DuelHard
	match win_kind:
		"elimination": return FINISH_ELIMINATION_GOLD + (2 if hard else 0)
		"blockade": return FINISH_BLOCKADE_GOLD + (4 if hard else 0)
	return 0

static func finish_label(win_kind: String) -> String:
	match win_kind:
		"elimination": return "ELIMINAÇÃO TOTAL:"
		"blockade": return "BLOQUEIO TOTAL:"
	return ""

func calculate_reward_gold(win_kind: String = "") -> Dictionary:
	var base_gold = get_base_gold()
	var capture_gold = get_capture_gold()
	var surviving_pieces = get_survival_gold(board.count_pieces(human_team))

	# Saque da Emboscada (Evento "?"): pago só na vitória, uma vez.
	var bonus_gold = 0
	if RunManager != null and RunManager.is_ambush_pending():
		bonus_gold = RunManager.ambush_bonus_gold
		RunManager.clear_ambush()

	# Tempestade de areia: o risco paga mais.
	var storm_gold = 0
	if is_hazard():
		storm_gold = 8 if self is DuelHard else 5
	# Ilha de basalto (maré de lava): o ouro do duelo vem em dobro.
	if island:
		storm_gold += base_gold + capture_gold + surviving_pieces

	var finish_gold: int = get_finish_gold(win_kind)
	var total = base_gold + capture_gold + surviving_pieces + bonus_gold + storm_gold + finish_gold

	if RunManager != null:
		RunManager.add_gold(total)

	return {
		"base": base_gold,
		"captures": capture_gold,
		"survival": surviving_pieces,
		"bonus": bonus_gold,
		"storm": storm_gold,
		"storm_label": hazard_label(),
		"finish": finish_gold,
		"finish_label": finish_label(win_kind),
		"total": total
	}
