class_name DuelBossCaldeira
extends DuelBoss

# Chefe da Caldeira (A Ferreira da Caldeira). PROVISÓRIO: ainda sem Leis
# próprias. Herda do chefe da floresta a vitória por eliminação, o cerco e a
# Morte Súbita anti-impasse, mas nenhuma lei da floresta é aplicada (law_id não
# bate com nenhuma delas). As leis planejadas (Forja, Lava, Fundição, Cinzas)
# entram em CALDEIRA_LAWS quando forem implementadas; o sorteio por run já está
# pronto em RunManager.get_caldeira_boss_law_id.
const CALDEIRA_LAWS: Array = []

func _init() -> void:
	law_id = ""
	if RunManager != null and not CALDEIRA_LAWS.is_empty():
		law_id = RunManager.get_caldeira_boss_law_id(CALDEIRA_LAWS)

func apply_board_modifiers() -> void:
	board.night_boost_team = 0

func get_enemy_fixed_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = []
	return rules

func advance_turn() -> Array:
	return []
