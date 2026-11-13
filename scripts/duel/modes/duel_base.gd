class_name DuelBase
extends RefCounted

var board: Board
var human_team: int = Board.WHITE
var ai_team: int = Board.BLACK
var captures_by_player: int = 0
# Duelo dentro de uma tempestade de areia (mapa do Deserto). null = duelo normal.
var sandstorm: SandstormMod = null

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
	return sandstorm.get_status_text() if sandstorm != null else ""

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

func calculate_reward_gold() -> Dictionary:
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
	if sandstorm != null:
		storm_gold = 8 if self is DuelHard else 5

	var total = base_gold + capture_gold + surviving_pieces + bonus_gold + storm_gold

	if RunManager != null:
		RunManager.add_gold(total)

	return {
		"base": base_gold,
		"captures": capture_gold,
		"survival": surviving_pieces,
		"bonus": bonus_gold,
		"storm": storm_gold,
		"total": total
	}
