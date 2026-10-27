class_name LootTables

# =========================================================
# BANCO DE DADOS CENTRAL (Adicione novas cartas/regras AQUI)
# =========================================================

static func get_all_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = [
		RuleReverseMovement.new(),
		RuleOptionalCapture.new(),
		RuleEarlyPromotion.new(),
		RuleCarnage.new(),
		RuleRevenge.new(),
		RuleAllyHop.new(),
		RuleSoulMirror.new(),
		RuleSecondMove.new(),
		RulePowerCenter.new(),
		RuleBlood.new(),
		RuleAdvance.new(),
		RuleShield.new(),
		RuleShockwave.new(),
		RuleSacredZone.new(),
		RuleVengefulFury.new(),
		RuleAscension.new(),
		RuleImpossibleTie.new(),
		RuleWeight.new(),
		RuleMourning.new(),
		RuleEcho.new(),
		RuleFaithfulCoin.new(),
		RuleLastChance.new()
	]
	return rules

# Leis EXCLUSIVAS de inimigo (nunca vendidas nem sorteadas pro jogador): ficam
# fora de get_all_rules() de propósito. Um Duelo Forte recebe uma delas.
static func get_enemy_unique_rules() -> Array[RuleCard]:
	var rules: Array[RuleCard] = [
		RuleRoyalGuard.new(),
		RuleCounterAttack.new(),
		RulePoison.new()
	]
	return rules

static func get_all_action_cards() -> Array[ActionCard]:
	var cards: Array[ActionCard] = [
		CardExtraTurn.new(),
		CardCoronation.new(),
		CardRetreat.new(),
		CardSacrifice.new(),
		CardRecruit.new(),
		CardVision.new(),
		CardRetaliation.new(),
		CardRebuild.new(),
		CardCorrupt.new(),
		CardFortify.new(),
		CardHeroicAdvance.new(),
		CardVerticalBridge.new(),
		CardLateralBridge.new(),
		CardProphecy.new(),
		CardGrandReinforcement.new(),
		CardCoinOfDestiny.new(),
		CardLuckyDuel.new(),
		CardSecondChance.new(),
		CardRebellion.new(),
		CardPause.new(),
		CardRecycle.new(),
		CardRestock.new(),
		CardLoadedCoin.new(),
		CardDemote.new(),
		CardHeir.new(),
		CardFlyingQueen.new(),
		CardGuillotine.new(),
		CardAmbush.new(),
		CardScorchedEarth.new(),
		CardTripleToss.new(),
		CardLightUp.new()
	]
	return cards

# Pools do JOGADOR: só o que foi desbloqueado no Grimório (MetaProgress).
# No tutorial vale tudo. Use estes (e não get_all_*) em loja, recompensas,
# eventos e apostas; IA, debug e o Grimório seguem usando get_all_*.
static func get_player_rules() -> Array[RuleCard]:
	var out: Array[RuleCard] = []
	var tutorial: bool = TutorialManager != null and TutorialManager.is_active
	for r in get_all_rules():
		if tutorial or MetaProgress.is_rule_unlocked(r.id):
			out.append(r)
	return out

static func get_player_action_cards() -> Array[ActionCard]:
	var out: Array[ActionCard] = []
	var tutorial: bool = TutorialManager != null and TutorialManager.is_active
	for c in get_all_action_cards():
		if tutorial or MetaProgress.is_card_unlocked(c.id):
			out.append(c)
	return out

# =========================================================
# MÉTODOS DE SORTEIO PONDERADO
# =========================================================

static func get_random_rules(count: int, exclude_ids: Array[String] = []) -> Array[RuleCard]:
	var pool = get_player_rules().filter(func(r: RuleCard): return not exclude_ids.has(r.id))
	return pick_weighted_rules(pool, count)

# Leis seguras pra conceder à IA (inimigo). Só as que decidem seu efeito
# através de hooks filtrados por time no RulePipeline (modify_move_directions,
# modify_step_distance, evaluate_mandatory_capture, check_custom_promotion,
# try_prevent_capture) — as demais (Carnificina, Vingança, Espelho de Almas,
# Casas de Poder, Sangue, Onda de Choque, Fúria Vingativa) checam
# "attacker.owner_team == board.human_team_color" direto dentro do próprio
# efeito (on_game_event) ou via id hardcoded em Board, então ficariam
# inertes ou incorretas (beneficiando o jogador por engano) se concedidas
# à IA por fora dessa lista.
const AI_ELIGIBLE_RULE_IDS: Array[String] = [
	"reverse_movement", "optional_capture", "early_promotion",
	"ally_hop", "advance", "shield", "sacred_zone",
	"ascension_law", "impossible_tie_law"
]

static func get_random_ai_rules(count: int) -> Array[RuleCard]:
	var pool = get_all_rules().filter(func(r: RuleCard): return AI_ELIGIBLE_RULE_IDS.has(r.id))
	var chosen = pick_weighted_rules(pool, count)
	for r in chosen:
		r.scope = RuleCard.Scope.AI_ONLY
	return chosen

static func get_random_action_cards(count: int, exclude_ids: Array[String] = []) -> Array[ActionCard]:
	var pool = get_player_action_cards().filter(func(c: ActionCard): return not exclude_ids.has(c.id))
	return pick_weighted_actions(pool, count)

# Cartas seguras pra dar à IA: as que não dependem de um recurso que só o
# jogador tem (Ouro) nem de informação unidirecional (Visão/Profecia só
# fazem sentido de um lado pro outro). Recrutamento/Reconstrução/Recuar/
# Investida Heroica/Segundo Turno já foram ajustadas pra funcionar
# simetricamente pra qualquer time.
const AI_ELIGIBLE_CARD_IDS: Array[String] = [
	"fortify", "grand_reinforcement", "corrupt",
	"recruit", "rebuild", "extra_turn", "retreat", "heroic_advance",
	"coin_of_destiny", "lucky_duel", "second_chance",
	"rebellion", "demote", "heir", "guillotine", "ambush"
]

# Pesos de raridade [comum, rara, épica, lendária] das cartas do inimigo por
# "profundidade" (camada do mapa; 1 = primeiro duelo, 7 = chefe). Cedo o
# inimigo só tem cartas fracas; as lendárias ficam para o fim da run.
const AI_RARITY_BY_DEPTH: Array = [
	[100, 0, 0, 0],   # 0 (tutorial / sem nó)
	[92, 8, 0, 0],    # 1
	[80, 20, 0, 0],   # 2
	[58, 34, 8, 0],   # 3
	[42, 38, 18, 2],  # 4
	[26, 38, 28, 8],  # 5
	[14, 34, 32, 20], # 6
	[8, 28, 34, 30],  # 7 (chefe)
]

static func get_ai_rarity_weights(depth: int) -> Array:
	return AI_RARITY_BY_DEPTH[clampi(depth, 0, AI_RARITY_BY_DEPTH.size() - 1)]

# depth: camada do nó (+1 em Duelo Forte, 7 no chefe). Sorteia a raridade pelo
# peso do estágio e depois a carta dentro dela, sem repetir; se uma raridade
# esgotar, redistribui entre as demais.
static func get_ai_starting_deck(count: int, depth: int = 0) -> Array[ActionCard]:
	var pool: Array = get_all_action_cards().filter(func(c: ActionCard): return AI_ELIGIBLE_CARD_IDS.has(c.id))
	var weights: Array = get_ai_rarity_weights(depth)
	var result: Array[ActionCard] = []
	while result.size() < count and not pool.is_empty():
		# raridades permitidas (peso > 0) que ainda têm carta no monte
		var present: Array = []
		for c in pool:
			if weights[c.rarity] > 0 and not present.has(c.rarity):
				present.append(c.rarity)
		if present.is_empty():
			# permitidas esgotadas: cai para a mais fraca que sobrou
			var lowest: int = 99
			for c in pool:
				lowest = mini(lowest, c.rarity)
			present.append(lowest)
		var rtotal: int = 0
		for r in present:
			rtotal += maxi(weights[r], 1)
		var roll: int = randi_range(1, rtotal)
		var chosen_r: int = present[0]
		var acc: int = 0
		for r in present:
			acc += maxi(weights[r], 1)
			if roll <= acc:
				chosen_r = r
				break
		var bucket: Array = pool.filter(func(c: ActionCard): return c.rarity == chosen_r)
		var pick: ActionCard = bucket[randi() % bucket.size()]
		result.append(pick)
		pool.erase(pick)
	return result

static func pick_weighted_rules(available_pool: Array[RuleCard], count: int) -> Array[RuleCard]:
	var result: Array[RuleCard] = []
	var pool = available_pool.duplicate()

	while result.size() < count and not pool.is_empty():
		var total_weight = 0
		for rule in pool:
			total_weight += RuleCard.get_rarity_weight(rule.rarity)

		var roll = randi_range(1, total_weight)
		var accum = 0
		var chosen_idx = 0

		for i in range(pool.size()):
			accum += RuleCard.get_rarity_weight(pool[i].rarity)
			if roll <= accum:
				chosen_idx = i
				break

		result.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return result

static func pick_weighted_actions(available_pool: Array[ActionCard], count: int) -> Array[ActionCard]:
	var result: Array[ActionCard] = []
	var pool = available_pool.duplicate()

	while result.size() < count and not pool.is_empty():
		var total_weight = 0
		for card in pool:
			total_weight += ActionCard.get_rarity_weight(card.rarity)

		var roll = randi_range(1, total_weight)
		var accum = 0
		var chosen_idx = 0

		for i in range(pool.size()):
			accum += ActionCard.get_rarity_weight(pool[i].rarity)
			if roll <= accum:
				chosen_idx = i
				break

		result.append(pool[chosen_idx])
		pool.remove_at(chosen_idx)

	return result
