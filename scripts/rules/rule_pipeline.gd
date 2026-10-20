class_name RulePipeline
extends RefCounted

const MAX_ACTIVE_RULES: int = 6

var active_rules: Array[RuleCard] = []
# Id da última Lei que impediu uma captura (a HUD usa para animar o slot dela).
var last_preventer_id: String = ""

# Única fonte da validação de limite (6) e incompatibilidade — usada tanto
# por add_rule quanto por quem precisa perguntar ANTES (ex: a loja, pra não
# cobrar por uma Lei que não vai entrar).
func can_add_rule(rule: RuleCard) -> bool:
	if rule == null:
		return false
	if active_rules.size() >= MAX_ACTIVE_RULES:
		return false

	for existing in active_rules:
		if existing.id in rule.incompatible_with or rule.id in existing.incompatible_with:
			return false
	return true

func add_rule(rule: RuleCard) -> bool:
	if not can_add_rule(rule):
		return false

	active_rules.append(rule)
	_sort_rules()
	return true

func remove_rule(rule_id: String) -> void:
	for i in range(active_rules.size() - 1, -1, -1):
		if active_rules[i].id == rule_id:
			active_rules.remove_at(i)
			break
	_sort_rules()

# Adiciona uma regra sem checar o limite de 6 nem incompatibilidade. Usado
# pelas Leis concedidas à IA (dificuldade do duelo) — esse limite é um
# mecanismo de progressão do JOGADOR e não deveria bloquear regras dadas ao
# inimigo por fora dessa progressão.
func add_rule_unchecked(rule: RuleCard) -> void:
	if rule == null:
		return
	active_rules.append(rule)
	_sort_rules()

func clear_rules() -> void:
	active_rules.clear()

func has_rule(rule_id: String) -> bool:
	for r in active_rules:
		if r.id == rule_id:
			return true
	return false

func _sort_rules() -> void:
	active_rules.sort_custom(func(a: RuleCard, b: RuleCard):
		return a.priority < b.priority
	)

# =========================================================
# MÉTODOS DE CONSULTA DO TABULEIRO (PIPELINE RUNNERS)
# =========================================================

func filter_move_directions(piece: BoardPiece, dirs: Array[Vector2i], human_team: int, board: RefCounted) -> Array[Vector2i]:
	var current_dirs: Array[Vector2i] = dirs.duplicate()
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			var result = rule.modify_move_directions(piece, current_dirs, human_team, board)
			current_dirs = Array(result, TYPE_VECTOR2I, "", null)
	return current_dirs

func can_capture_backwards(piece: BoardPiece, human_team: int) -> bool:
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			if rule.id == "backward_capture" or rule.id == "reverse_movement":
				return true
	return false

func can_hop_allies(piece: BoardPiece, human_team: int) -> bool:
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			if rule.id == "ally_hop":
				return true
	return false

func filter_step_distance(piece: BoardPiece, base_distance: int, human_team: int, board: RefCounted) -> int:
	var dist = base_distance
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			dist = rule.modify_step_distance(piece, dist, board)
	return dist

func filter_capture_reach(piece: BoardPiece, base_reach: int, human_team: int, board: RefCounted) -> int:
	var reach = base_reach
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			reach = rule.modify_capture_reach(piece, reach, board)
	return reach

func filter_king_range(piece: BoardPiece, human_team: int) -> int:
	var r = 0
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			r = rule.modify_king_range(piece, r)
	return r

func king_lands_before_victim(piece: BoardPiece, human_team: int) -> bool:
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			if rule.king_lands_before_victim(piece):
				return true
	return false

func get_rule(rule_id: String) -> RuleCard:
	for r in active_rules:
		if r.id == rule_id:
			return r
	return null

func is_capture_mandatory(team: int, human_team: int) -> bool:
	var mandatory = true
	for rule in active_rules:
		if rule.applies_to_team(team, human_team):
			mandatory = rule.evaluate_mandatory_capture(team, mandatory)
	return mandatory

func should_promote_to_king(piece: BoardPiece, to_pos: Vector2i, human_team: int, board: RefCounted) -> bool:
	for rule in active_rules:
		if rule.applies_to_team(piece.owner_team, human_team):
			if rule.check_custom_promotion(piece, to_pos, board):
				return true
	return false

func emit_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	for rule in active_rules:
		rule.on_game_event(event_name, context, board)

func try_prevent_capture(victim: BoardPiece, human_team: int, board: RefCounted) -> bool:
	if victim == null:
		return false
	for rule in active_rules:
		if rule.applies_to_team(victim.owner_team, human_team):
			if rule.try_prevent_capture(victim, board):
				last_preventer_id = rule.id
				return true
	return false
