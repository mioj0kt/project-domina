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
		RuleLastChance.new(),
		RuleBorrowedTime.new(),
		RuleShortFuse.new(),
		RuleGoldenQueen.new(),
		RuleAdrenaline.new(),
		RuleTrail.new(),
		RuleCinders.new(),
		RuleInferno.new(),
		RuleUsury.new(),
		RuleRetreatBridge.new(),
		RulePressure.new(),
		RuleFrenzy.new(),
		RuleRunningAccount.new(),
		RuleCharge.new(),
		RuleDomino.new()
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
		CardLightUp.new(),
		CardPlantTree.new(),
		CardPlantCactus.new(),
		CardPlaceSarcophagus.new(),
		CardFrogBait.new(),
		CardSuddenStart.new(),
		CardClockCut.new(),
		CardExtension.new(),
		CardEmber.new(),
		CardFlameWall.new(),
		CardFuse.new(),
		CardAshes.new(),
		CardShadowHand.new(),
		CardSquire.new(),
		CardCollapse.new(),
		CardMirrorCrystal.new(),
		CardSwap.new(),
		CardPush.new(),
		CardForcedMarch.new(),
		CardCounterstrike.new(),
		CardAllOrNothing.new(),
		CardSteal.new(),
		CardSilence.new()
	]
	return cards

# Pools do JOGADOR: só o que foi desbloqueado no Grimório (MetaProgress).
# No tutorial vale tudo. Use estes (e não get_all_*) em loja, recompensas,
# eventos e apostas; IA, debug e o Grimório seguem usando get_all_*.
# Tudo o que o jogador já liberou (sem o recorte do acervo da run).
static func get_unlocked_rules() -> Array[RuleCard]:
	var out: Array[RuleCard] = []
	var tutorial: bool = TutorialManager != null and TutorialManager.is_active
	for r in get_all_rules():
		if tutorial or MetaProgress.is_rule_unlocked(r.id):
			out.append(r)
	return out

static func get_unlocked_action_cards() -> Array[ActionCard]:
	var out: Array[ActionCard] = []
	var tutorial: bool = TutorialManager != null and TutorialManager.is_active
	for c in get_all_action_cards():
		if tutorial or MetaProgress.is_card_unlocked(c.id):
			out.append(c)
	return out

# O que pode aparecer para o jogador NESTA run: o acervo da run (um recorte
# sorteado do que está liberado; ver _build_acervo). Usado por recompensas,
# loja, altar, arcano, eventos e apostas.
static func get_player_rules() -> Array[RuleCard]:
	var all := get_unlocked_rules()
	var ids := _acervo(true, all)
	if ids.is_empty():
		return all
	return all.filter(func(r: RuleCard): return ids.has(r.id))

static func get_player_action_cards() -> Array[ActionCard]:
	var all := get_unlocked_action_cards()
	var ids := _acervo(false, all)
	if ids.is_empty():
		return all
	return all.filter(func(c: ActionCard): return ids.has(c.id))

# =========================================================
# ACERVO DA RUN (escondido)
# =========================================================
# Com muita coisa liberada, cada item aparecia cada vez menos e a run ficava
# sempre parecida. No começo da run sorteamos um recorte do que está liberado
# e só ele aparece até o fim. Abaixo do tamanho, vale tudo.
const ACERVO_RULES: int = 20
const ACERVO_CARDS: int = 30
# Fração máxima de cada raridade reservada para itens NOVOS (nunca levados),
# para o selo NOVA sempre ter o que mostrar sem tomar o acervo inteiro.
const ACERVO_NEW_SHARE: float = 0.5

static func _acervo(is_rule: bool, unlocked: Array) -> Array[String]:
	var empty: Array[String] = []
	if RunManager == null or (TutorialManager != null and TutorialManager.is_active):
		return empty
	var size: int = ACERVO_RULES if is_rule else ACERVO_CARDS
	if unlocked.size() <= size:
		return empty
	var cur: Array[String] = RunManager.acervo_rules if is_rule else RunManager.acervo_cards
	if cur.is_empty():
		cur.append_array(_build_acervo(is_rule, unlocked, size))
	return cur

# Sorteio estratificado por raridade (mantém a proporção do que está liberado,
# pelo menos 1 de cada raridade que existir). Em cada raridade, até metade das
# vagas vai primeiro para itens NOVOS; o resto é sorteado entre todos.
static func _build_acervo(is_rule: bool, unlocked: Array, size: int) -> Array[String]:
	var by_rar: Dictionary = {}
	for it in unlocked:
		var k: int = int(it.rarity)
		if not by_rar.has(k):
			by_rar[k] = []
		by_rar[k].append(it.id)
	var out: Array[String] = []
	var total: int = unlocked.size()
	var keys: Array = by_rar.keys()
	keys.sort()
	for k in keys:
		var ids: Array = by_rar[k]
		var slots: int = maxi(1, int(round(float(size) * ids.size() / total)))
		slots = mini(slots, ids.size())
		var news: Array = ids.filter(func(id): return MetaProgress.is_new(is_rule, id))
		var olds: Array = ids.filter(func(id): return not news.has(id))
		news.shuffle()
		olds.shuffle()
		var take_new: int = mini(news.size(), int(ceil(slots * ACERVO_NEW_SHARE)))
		var picked: Array = news.slice(0, take_new)
		var rest: Array = news.slice(take_new) + olds
		rest.shuffle()
		picked.append_array(rest.slice(0, slots - picked.size()))
		for id in picked:
			out.append(str(id))
	return out

# Garante 1 item NOVO entre os sorteados (se o pool tiver algum e nenhum veio):
# troca o último sorteado por um novo, sorteado pelo peso de raridade.
static func _ensure_new(result: Array, pool: Array, is_rule: bool) -> void:
	if result.is_empty():
		return
	for it in result:
		if MetaProgress.is_new(is_rule, it.id):
			return
	var news: Array = pool.filter(func(it): return MetaProgress.is_new(is_rule, it.id) and not result.has(it))
	if news.is_empty():
		return
	var pick: Array = []
	if is_rule:
		pick = pick_weighted_rules(_typed_rules(news), 1)
	else:
		pick = pick_weighted_actions(_typed_cards(news), 1)
	if not pick.is_empty():
		result[result.size() - 1] = pick[0]

static func _typed_rules(a: Array) -> Array[RuleCard]:
	var out: Array[RuleCard] = []
	for x in a:
		out.append(x)
	return out

static func _typed_cards(a: Array) -> Array[ActionCard]:
	var out: Array[ActionCard] = []
	for x in a:
		out.append(x)
	return out

# =========================================================
# MÉTODOS DE SORTEIO PONDERADO
# =========================================================

static func get_random_rules(count: int, exclude_ids: Array[String] = []) -> Array[RuleCard]:
	var pool = get_player_rules().filter(func(r: RuleCard): return not exclude_ids.has(r.id))
	# acervo esgotado (já tem quase tudo dele): completa com o resto do liberado
	if pool.size() < count:
		for r in get_unlocked_rules():
			if not exclude_ids.has(r.id) and not pool.any(func(x): return x.id == r.id):
				pool.append(r)
	var out := pick_weighted_rules(pool, count)
	_ensure_new(out, pool, true)
	return out

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
	"ascension_law", "impossible_tie_law",
	# Escolhem o time pelo hook/pela peça (applies_to_team), então valem para a IA:
	"mourning", "weight", "retreat_bridge", "pressure", "trail"
]

static func get_random_ai_rules(count: int) -> Array[RuleCard]:
	var pool = get_all_rules().filter(func(r: RuleCard): return AI_ELIGIBLE_RULE_IDS.has(r.id))
	var chosen = pick_weighted_rules(pool, count)
	for r in chosen:
		r.scope = RuleCard.Scope.AI_ONLY
	return chosen

static func get_random_action_cards(count: int, exclude_ids: Array[String] = []) -> Array[ActionCard]:
	var pool = get_player_action_cards().filter(func(c: ActionCard): return not exclude_ids.has(c.id))
	var out := pick_weighted_actions(pool, count)
	_ensure_new(out, pool, false)
	return out

# Cartas seguras pra dar à IA: as que não dependem de um recurso que só o
# jogador tem (Ouro) nem de informação unidirecional (Visão/Profecia só
# fazem sentido de um lado pro outro). Recrutamento/Reconstrução/Recuar/
# Investida Heroica/Segundo Turno já foram ajustadas pra funcionar
# simetricamente pra qualquer time.
const AI_ELIGIBLE_CARD_IDS: Array[String] = [
	"fortify", "grand_reinforcement", "corrupt",
	"recruit", "rebuild", "extra_turn", "retreat", "heroic_advance",
	"coin_of_destiny", "lucky_duel", "second_chance",
	"rebellion", "demote", "heir", "guillotine", "ambush",
	"coronation", "plant_tree", "restock", "triple_toss",
	"plant_cactus", "light_up", "ember", "scorched_earth", "shadow_hand", "squire", "fuse",
	# Liberadas depois: cada uma tem alvo/condição própria na IA (duel_turn_controller).
	"ashes", "flame_wall", "clock_cut", "extension", "pause", "sudden_start", "recycle", "place_sarcophagus",
	# Cartas novas que a IA sabe usar (Roubo só quando sua mão tem carta que ela conhece).
	"collapse", "forced_march", "counterstrike", "all_or_nothing", "steal", "silence",
	"mirror_crystal", "swap", "push"
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
# Cartas "do lugar": só fazem sentido no bioma de onde vêm. A IA só recebe (e só
# rouba) essas cartas quando o duelo é naquele bioma — nada de inimigo da
# floresta plantando cacto ou erguendo cristal. Cartas fora daqui servem em qualquer bioma.
const CARD_BIOME: Dictionary = {
	"plant_tree": "floresta", "frog_bait": "floresta",
	"plant_cactus": "deserto", "place_sarcophagus": "deserto",
	"mirror_crystal": "mina", "collapse": "mina",
}

static func card_fits_biome(card_id: String, biome: String) -> bool:
	return not CARD_BIOME.has(card_id) or String(CARD_BIOME[card_id]) == biome

static func current_biome() -> String:
	if TutorialManager != null and TutorialManager.is_active:
		return "floresta"
	return RunManager.map_biome if RunManager != null else "floresta"

static func get_ai_starting_deck(count: int, depth: int = 0) -> Array[ActionCard]:
	var biome: String = current_biome()
	var pool: Array = get_all_action_cards().filter(func(c: ActionCard): return AI_ELIGIBLE_CARD_IDS.has(c.id) and card_fits_biome(c.id, biome))
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
