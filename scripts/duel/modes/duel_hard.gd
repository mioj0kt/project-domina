class_name DuelHard
extends DuelBase

func setup(p_board: Board, p_human_team: int, p_ai_team: int, p_sudden_death_mgr: SuddenDeathManager) -> void:
	super.setup(p_board, p_human_team, p_ai_team, p_sudden_death_mgr)

func apply_board_modifiers() -> void:
	# Nenhum modificador aplicado ao tabuleiro
	pass

func get_base_gold() -> int:
	return 12

func get_capture_gold() -> int:
	return mini(captures_by_player, CAPTURE_GOLD_CAP + 1)

func get_survival_gold(alive: int) -> int:
	return mini(int(ceil(float(alive) / 3.0)), SURVIVAL_GOLD_CAP + 1)

func get_enemy_fixed_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = [RuleIronCrown.new()]
	# + 1 Lei exclusiva de inimigo, sorteada (Guarda Real / Contra-Ataque / Veneno).
	var unique: Array[RuleCard] = LootTables.get_enemy_unique_rules()
	rules.append(unique[randi() % unique.size()])
	return rules

func get_enemy_random_rule_count() -> int:
	return 1

func get_enemy_card_count() -> int:
	return 3
