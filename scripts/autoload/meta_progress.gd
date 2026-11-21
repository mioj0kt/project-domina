extends Node
# Meta-progressão (autoload "MetaProgress"): tudo que sobrevive entre runs.
#  - COROAS: moeda de meta, ganha ao fim da run (vitória, derrota ou abandono).
#  - Desbloqueios: Leis/Cartas que entram na loot pool (loja, recompensas).
#    O que não está desbloqueado NÃO aparece na run (ver LootTables).
#    Só o conjunto INICIAL vem liberado; o resto sai de MONTES viradas: o
#    jogador escolhe o monte (Cartas: por raridade; Leis: por categoria),
#    paga e sorteia uma peça ainda bloqueada dele.
#  - MOCHILA: Cartas/Leis que o jogador PAGA para levar na próxima run. O
#    preço sai da raridade e SOBE a cada item já na mochila (começar a run
#    com o inventário cheio fica caro). Paga-se de novo a cada run.
# Salvo em user://meta.cfg. O tutorial ignora tudo isso (usa run própria).

signal changed()

const SAVE_PATH: String = "user://meta.cfg"

# Ganho por run
const COROAS_PER_DUEL: int = 3
const COROAS_PER_STRONG: int = 7
const COROAS_BOSS_WIN: int = 30

# Preço de desbloqueio por raridade (0 comum, 1 raro, 2 épico, 3 lendário)
const RULE_UNLOCK_COST: Array[int] = [8, 15, 25, 40]
const CARD_UNLOCK_COST: Array[int] = [6, 12, 20, 32]

# MOCHILA: preço base de LEVAR um item para a próxima run, por raridade
# (0 comum, 1 raro, 2 épico, 3 lendário). Leis pesam mais que cartas.
const CARD_CARRY_COST: Array[int] = [3, 5, 8, 12]
const RULE_CARRY_COST: Array[int] = [4, 7, 11, 16]
# Cada item JÁ na mochila encarece o próximo em +35% do preço base.
const CARRY_ESCALATION: float = 0.35
const BAG_MAX: int = 8

# Conjunto INICIAL (já liberado). O resto se desbloqueia nos montes.
const STARTER_CARDS: Array[String] = [
	"ambush", "lucky_duel", "pause", "heroic_advance", "vision"]
const STARTER_RULES: Array[String] = [
	"early_promotion", "reverse_movement", "optional_capture", "power_center", "ascension_law"]

# Monte de Leis: o preço é a MÉDIA do custo de desbloqueio do que ainda resta
# no monte (o sorteio é uniforme), então um monte com peças raras sai mais caro.

var _coroas: int = 0
# Com DebugFlags ligadas: infinitas (leitura fixa, escritas ignoradas; o save usa _coroas).
var coroas: int:
	get:
		return DebugFlags.INFINITE_VALUE if DebugFlags.infinite_resources() else _coroas
	set(v):
		if not DebugFlags.infinite_resources():
			_coroas = v
var unlocked_rules: Array[String] = []
var unlocked_cards: Array[String] = []
# Mochila da próxima run: [{"t": "card"|"rule", "id", "paid": int}]
var bag: Array[Dictionary] = []
var oficina_tour_seen: bool = false   # guia do Grimório já exibido
var run_over_tour_seen: bool = false   # mini guia das Coroas (1ª tela de fim de run) já exibido
var alpha_end_seen: bool = false      # mensagem de fim da alpha (1º Chefe derrotado) já exibida
var tutorial_warned: bool = false     # jogador escolheu 'jogar mesmo assim' sem o tutorial (aviso não volta)
var tutorial_done: bool = false       # jogador já concluiu o tutorial até o fim
var map_drag_seen: bool = false       # jogador já rolou o mapa (a dica "arraste" não volta)
# O Grimório começa BLOQUEADO e abre ao fim da 1ª run (derrota ou vitória).
var grimorio_unlocked: bool = false
# Biomas que o jogador já pisou pelo menos uma vez (decide quais ilhas voam no fundo).
var visited_biomes: Array[String] = []
# Selo NOVA: o que o jogador já LEVOU para alguma run (recompensa, loja, evento, mochila).
var taken_rules: Array[String] = []
var taken_cards: Array[String] = []
# Bônus de descoberta: Leis/Cartas com que o jogador já VENCEU um duelo.
var won_rules: Array[String] = []
var won_cards: Array[String] = []
# Biomas cujo Chefe o jogador já derrotou (a 1ª vitória libera Leis e Cartas).
var defeated_bosses: Array[String] = []
# Só na sessão: o que a 1ª vitória sobre o Chefe acabou de liberar (a cena do
# duelo mostra e limpa). {biome, rules, cards, coroas}
var pending_boss_unlock: Dictionary = {}
var grimorio_just_unlocked: bool = false   # só na sessão: mostra o aviso "desbloqueado" uma vez

# Estatísticas da run em andamento (zeradas em RunManager.start_new_run).
var run_duels_won: int = 0
var run_strong_won: int = 0
var run_boss_won: bool = false
var run_discovery_coroas: int = 0
var run_discoveries: Array = []   # [{name, coroas}] da run, para o resumo

# Resumo da última run paga (lido pela tela de fim de run).
# {won, duels, strong, boss, total, before, after, gold, laws, cards}
var last_summary: Dictionary = {}

func _ready() -> void:
	load_data()

# ---------------------------------------------------------------------
# Persistência
# ---------------------------------------------------------------------
func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_coroas = int(cfg.get_value("meta", "coroas", cfg.get_value("meta", "selos", 0)))
	unlocked_rules = _to_str_array(cfg.get_value("meta", "unlocked_rules", []))
	unlocked_cards = _to_str_array(cfg.get_value("meta", "unlocked_cards", []))
	bag.clear()
	var raw = cfg.get_value("meta", "bag", [])
	if raw is Array:
		for e in raw:
			if e is Dictionary and e.has("id") and e.has("t"):
				bag.append({"t": str(e["t"]), "id": str(e["id"]), "paid": int(e.get("paid", 0))})
	oficina_tour_seen = bool(cfg.get_value("meta", "oficina_tour_seen", false))
	tutorial_done = bool(cfg.get_value("meta", "tutorial_done", false))
	run_over_tour_seen = bool(cfg.get_value("meta", "run_over_tour_seen", false))
	alpha_end_seen = bool(cfg.get_value("meta", "alpha_end_seen", false))
	tutorial_warned = bool(cfg.get_value("meta", "tutorial_warned", false))
	map_drag_seen = bool(cfg.get_value("meta", "map_drag_seen", false))
	# Saves antigos (sem a chave) já jogaram: quem tem qualquer progresso começa com o Grimório aberto.
	var legacy_open: bool = _coroas > 0 or not unlocked_rules.is_empty() or not unlocked_cards.is_empty() or oficina_tour_seen or run_over_tour_seen or alpha_end_seen
	grimorio_unlocked = bool(cfg.get_value("meta", "grimorio_unlocked", legacy_open))
	# Saves antigos: quem já tinha progresso certamente passou pela floresta.
	visited_biomes = _to_str_array(cfg.get_value("meta", "visited_biomes", ["floresta"] if (legacy_open or tutorial_done) else []))
	taken_rules = _to_str_array(cfg.get_value("meta", "taken_rules", []))
	taken_cards = _to_str_array(cfg.get_value("meta", "taken_cards", []))
	won_rules = _to_str_array(cfg.get_value("meta", "won_rules", []))
	won_cards = _to_str_array(cfg.get_value("meta", "won_cards", []))
	defeated_bosses = _to_str_array(cfg.get_value("meta", "defeated_bosses", []))
	_sanitize()

func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "coroas", _coroas)
	cfg.set_value("meta", "unlocked_rules", unlocked_rules)
	cfg.set_value("meta", "unlocked_cards", unlocked_cards)
	cfg.set_value("meta", "bag", bag)
	cfg.set_value("meta", "oficina_tour_seen", oficina_tour_seen)
	cfg.set_value("meta", "tutorial_done", tutorial_done)
	cfg.set_value("meta", "run_over_tour_seen", run_over_tour_seen)
	cfg.set_value("meta", "alpha_end_seen", alpha_end_seen)
	cfg.set_value("meta", "tutorial_warned", tutorial_warned)
	cfg.set_value("meta", "map_drag_seen", map_drag_seen)
	cfg.set_value("meta", "grimorio_unlocked", grimorio_unlocked)
	cfg.set_value("meta", "visited_biomes", visited_biomes)
	cfg.set_value("meta", "taken_rules", taken_rules)
	cfg.set_value("meta", "taken_cards", taken_cards)
	cfg.set_value("meta", "won_rules", won_rules)
	cfg.set_value("meta", "won_cards", won_cards)
	cfg.set_value("meta", "defeated_bosses", defeated_bosses)
	cfg.save(SAVE_PATH)

func _to_str_array(v) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		for x in v:
			out.append(str(x))
	return out

# Tira da mochila o que não está mais desbloqueado.
func _sanitize() -> void:
	bag = bag.filter(func(e): return (is_rule_unlocked(e["id"]) if e["t"] == "rule" else is_card_unlocked(e["id"])))

func mark_oficina_tour_seen() -> void:
	if not oficina_tour_seen:
		oficina_tour_seen = true
		save_data()

func mark_alpha_end_seen() -> void:
	if not alpha_end_seen:
		alpha_end_seen = true
		save_data()

func mark_run_over_tour_seen() -> void:
	if not run_over_tour_seen:
		run_over_tour_seen = true
		save_data()

func mark_tutorial_warned() -> void:
	if not tutorial_warned:
		tutorial_warned = true
		save_data()

func mark_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		save_data()

func mark_biome_visited(b: String) -> void:
	if b != "" and not visited_biomes.has(b):
		visited_biomes.append(b)
		save_data()

func reset_all() -> void:
	_coroas = 0
	unlocked_rules.clear()
	unlocked_cards.clear()
	bag.clear()
	oficina_tour_seen = false
	tutorial_done = false
	run_over_tour_seen = false
	alpha_end_seen = false
	tutorial_warned = false
	grimorio_unlocked = false
	grimorio_just_unlocked = false
	visited_biomes.clear()
	taken_rules.clear()
	taken_cards.clear()
	won_rules.clear()
	won_cards.clear()
	defeated_bosses.clear()
	pending_boss_unlock = {}
	last_summary = {}
	reset_run_stats()
	save_data()
	changed.emit()

# ---------------------------------------------------------------------
# Desbloqueios
# ---------------------------------------------------------------------
func _tutorial_on() -> bool:
	return TutorialManager != null and TutorialManager.is_active

func is_rule_unlocked(id: String) -> bool:
	return unlocked_rules.has(id) or STARTER_RULES.has(id)

func is_card_unlocked(id: String) -> bool:
	return unlocked_cards.has(id) or STARTER_CARDS.has(id)

func rule_unlock_cost(rule: RuleCard) -> int:
	return RULE_UNLOCK_COST[clampi(int(rule.rarity), 0, 3)]

# ---- Itens ainda bloqueados ----
func locked_cards(rarity: int) -> Array[ActionCard]:
	var out: Array[ActionCard] = []
	for c in LootTables.get_all_action_cards():
		if int(c.rarity) == rarity and not is_card_unlocked(c.id):
			out.append(c)
	return out

# ---- Sorteio (Oráculo) ----
# Raridade sorteada por peso; o item sai dos AINDA BLOQUEADOS dessa raridade
# (nunca repete). Raridade esgotada cai para a mais próxima com itens.
const ODDS: Array[int] = [60, 28, 10, 2]   # comum, rara, épica, lendária (pesos)

func locked_rules_of_rarity(rarity: int) -> Array[RuleCard]:
	var out: Array[RuleCard] = []
	for r in LootTables.get_all_rules():
		if int(r.rarity) == rarity and not is_rule_unlocked(r.id):
			out.append(r)
	return out

func locked_of(is_rule: bool, rarity: int) -> Array:
	if is_rule:
		return locked_rules_of_rarity(rarity)
	return locked_cards(rarity)

# Total de itens que dá para desbloquear (tudo menos os iniciais).
func lockable_cards_total() -> int:
	var n := 0
	for c in LootTables.get_all_action_cards():
		if not STARTER_CARDS.has(c.id):
			n += 1
	return n

func lockable_rules_total() -> int:
	var n := 0
	for r in LootTables.get_all_rules():
		if not STARTER_RULES.has(r.id):
			n += 1
	return n

func lockable_total() -> int:
	return lockable_cards_total() + lockable_rules_total()

# Quantos itens (Cartas ou Leis) ainda faltam desbloquear.
func remaining_of(is_rule: bool) -> int:
	var n := 0
	for r in range(4):
		n += locked_of(is_rule, r).size()
	return n

# ---- MÁQUINA (um sorteio só: Carta OU Lei) ----
# A raridade é sorteada pelas mesmas chances (ODDS)
# considerando TUDO que ainda está bloqueado (Cartas + Leis); o item é sorteado
# uniformemente entre os bloqueados dessa raridade, seja Carta ou Lei.
# Preço do sorteio: média do "peso" dos itens AINDA BLOQUEADOS (Cartas + Leis).
# Cada raridade puxa o preço para o seu valor em MACHINE_RARITY_PRICE: muitos
# comuns disponíveis = mais barato; muitas épicas/lendárias = mais caro. Fica
# sempre entre MACHINE_PRICE_MIN e MACHINE_PRICE_MAX.
const MACHINE_PRICE_MIN: int = 15
const MACHINE_PRICE_MAX: int = 30
const MACHINE_RARITY_PRICE: Array[float] = [15.0, 20.0, 25.0, 30.0]   # comum, rara, épica, lendária

func machine_price() -> int:
	var total: int = 0
	var acc: float = 0.0
	for r in range(4):
		var n: int = machine_items_of(r).size()
		total += n
		acc += float(n) * MACHINE_RARITY_PRICE[r]
	if total <= 0:
		return MACHINE_PRICE_MIN
	return clampi(int(round(acc / float(total))), MACHINE_PRICE_MIN, MACHINE_PRICE_MAX)

# Itens bloqueados de uma raridade: [{"id", "is_rule", "rarity"}]
func machine_items_of(rarity: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in locked_cards(rarity):
		out.append({"id": c.id, "is_rule": false, "rarity": rarity})
	for r in locked_rules_of_rarity(rarity):
		out.append({"id": r.id, "is_rule": true, "rarity": rarity})
	return out

# Tudo que ainda falta desbloquear (para a máquina mostrar em órbita).
func machine_all_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in range(4):
		out.append_array(machine_items_of(r))
	return out

func machine_remaining() -> int:
	return machine_all_items().size()

func roll_machine_rarity(roll: int = -1) -> int:
	var total := 0
	for r in range(4):
		if not machine_items_of(r).is_empty():
			total += ODDS[r]
	if total <= 0:
		return -1
	var x: int = randi() % total if roll < 0 else roll
	var acc := 0
	for r in range(4):
		if machine_items_of(r).is_empty():
			continue
		acc += ODDS[r]
		if x < acc:
			return r
	return -1

# Usa a máquina. Devolve {"id", "is_rule", "rarity"}; vazio = sem Coroas ou esgotada.
func draw_machine(roll: int = -1) -> Dictionary:
	var price: int = machine_price()
	if coroas < price:
		return {}
	var rarity := roll_machine_rarity(roll)
	if rarity < 0:
		return {}
	var items := machine_items_of(rarity)
	var pick: Dictionary = items[randi() % items.size()]
	coroas -= price
	if bool(pick["is_rule"]):
		unlocked_rules.append(pick["id"])
	else:
		unlocked_cards.append(pick["id"])
	save_data()
	changed.emit()
	return pick

# ---------------------------------------------------------------------
# Mochila da próxima run
# ---------------------------------------------------------------------
func bag_has(t: String, id: String) -> bool:
	return bag.any(func(e): return e["t"] == t and e["id"] == id)

func bag_count(t: String = "") -> int:
	if t == "":
		return bag.size()
	return bag.filter(func(e): return e["t"] == t).size()

func bag_total_paid() -> int:
	var n := 0
	for e in bag:
		n += int(e["paid"])
	return n

func _base_carry(t: String, rarity: int) -> int:
	var table: Array[int] = RULE_CARRY_COST if t == "rule" else CARD_CARRY_COST
	return table[clampi(rarity, 0, 3)]

func _escalate(base: int, already: int) -> int:
	return int(round(float(base) * (1.0 + CARRY_ESCALATION * float(already))))

# Preço de LEVAR este item agora (já com a escalada da mochila atual).
func carry_price(t: String, rarity: int) -> int:
	return _escalate(_base_carry(t, rarity), bag.size())

func _rarity_of(t: String, id: String) -> int:
	if t == "rule":
		for r in LootTables.get_all_rules():
			if r.id == id:
				return int(r.rarity)
	else:
		for c in LootTables.get_all_action_cards():
			if c.id == id:
				return int(c.rarity)
	return 0

func _unlocked(t: String, id: String) -> bool:
	return is_rule_unlocked(id) if t == "rule" else is_card_unlocked(id)

func add_to_bag(t: String, id: String) -> bool:
	if bag_has(t, id) or not _unlocked(t, id) or bag.size() >= BAG_MAX:
		return false
	var price := carry_price(t, _rarity_of(t, id))
	if coroas < price:
		return false
	coroas -= price
	bag.append({"t": t, "id": id, "paid": price})
	save_data()
	changed.emit()
	return true

# Tira da mochila devolvendo o que foi pago por ele.
func remove_from_bag(t: String, id: String) -> void:
	for i in range(bag.size()):
		if bag[i]["t"] == t and bag[i]["id"] == id:
			coroas += int(bag[i]["paid"])
			bag.remove_at(i)
			save_data()
			changed.emit()
			return

func clear_bag() -> void:
	coroas += bag_total_paid()
	bag.clear()
	save_data()
	changed.emit()

# Entrega a mochila a uma run NOVA (chamado por JOGAR depois de
# RunManager.start_new_run) e esvazia: a próxima run paga de novo.
func consume_bag_into_run() -> void:
	if _tutorial_on():
		return
	for e in bag:
		if e["t"] == "rule":
			for rule in LootTables.get_all_rules():
				if rule.id == e["id"]:
					RunManager.add_rule(rule)
		else:
			for card in LootTables.get_all_action_cards():
				if card.id == e["id"] and not RunManager.player_deck.any(func(c): return c.id == card.id):
					RunManager.add_card_to_deck(card)
	bag.clear()
	save_data()
	changed.emit()

# ---------------------------------------------------------------------
# Ganho de Coroas
# ---------------------------------------------------------------------
func reset_run_stats() -> void:
	run_duels_won = 0
	run_strong_won = 0
	run_boss_won = false
	run_discovery_coroas = 0
	run_discoveries = []

# ---------------------------------------------------------------------
# 1ª vitória sobre o Chefe de cada bioma
# ---------------------------------------------------------------------
const BOSS_FIRST_RULES: int = 3
const BOSS_FIRST_CARDS: int = 5
# Se já não houver o que liberar, cada vaga que sobrar vira Coroas.
const BOSS_LEFTOVER_COROAS: int = 8

## Chamado na vitória sobre o Chefe. Na 1ª vez em cada bioma libera Leis e
## Cartas ainda bloqueadas (entram no Grimório e já podem aparecer nesta run).
## Devolve {biome, rules, cards, coroas} ou {} se não for a 1ª vez.
func claim_boss_first_win(biome: String) -> Dictionary:
	if _tutorial_on() or biome == "" or defeated_bosses.has(biome):
		return {}
	defeated_bosses.append(biome)
	var rules: Array = _pick_unlocks(true, BOSS_FIRST_RULES, biome)
	var cards: Array = _pick_unlocks(false, BOSS_FIRST_CARDS, biome)
	for r in rules:
		unlocked_rules.append(r.id)
		if RunManager != null and not RunManager.acervo_rules.is_empty():
			RunManager.acervo_rules.append(r.id)
	for c in cards:
		unlocked_cards.append(c.id)
		if RunManager != null and not RunManager.acervo_cards.is_empty():
			RunManager.acervo_cards.append(c.id)
	var missing: int = (BOSS_FIRST_RULES - rules.size()) + (BOSS_FIRST_CARDS - cards.size())
	var bonus: int = missing * BOSS_LEFTOVER_COROAS
	if bonus > 0:
		coroas += bonus
	save_data()
	changed.emit()
	return {"biome": biome, "rules": rules, "cards": cards, "coroas": bonus}

# Sorteia `count` itens bloqueados: primeiro os ligados ao bioma (cartas de
# terreno), depois 1 garantido de raridade rara ou maior, e o resto pelo peso de
# raridade de sempre.
func _pick_unlocks(is_rule: bool, count: int, biome: String) -> Array:
	var locked: Array = []
	if is_rule:
		for r in LootTables.get_all_rules():
			if not is_rule_unlocked(r.id):
				locked.append(r)
	else:
		for c in LootTables.get_all_action_cards():
			if not is_card_unlocked(c.id):
				locked.append(c)
	var out: Array = []
	if not is_rule:
		for c in locked:
			if out.size() < count and String(LootTables.CARD_BIOME.get(c.id, "")) == biome:
				out.append(c)
	var rest: Array = locked.filter(func(it): return not out.has(it))
	var rare: Array = rest.filter(func(it): return int(it.rarity) >= 1)
	if out.size() < count and not rare.is_empty() and not out.any(func(it): return int(it.rarity) >= 1):
		var g: Array = []
		if is_rule:
			g = LootTables.pick_weighted_rules(LootTables._typed_rules(rare), 1)
		else:
			g = LootTables.pick_weighted_actions(LootTables._typed_cards(rare), 1)
		out.append_array(g)
		rest.erase(g[0])
	var need: int = count - out.size()
	if need > 0 and not rest.is_empty():
		var more: Array = []
		if is_rule:
			more = LootTables.pick_weighted_rules(LootTables._typed_rules(rest), need)
		else:
			more = LootTables.pick_weighted_actions(LootTables._typed_cards(rest), need)
		out.append_array(more)
	return out

# ---------------------------------------------------------------------
# Selo NOVA e bônus de descoberta
# ---------------------------------------------------------------------
# Coroas pela 1ª vitória com uma Lei / Carta [comum, rara, épica, lendária].
const DISCOVERY_RULE_COROAS: Array[int] = [3, 5, 8, 12]
const DISCOVERY_CARD_COROAS: Array[int] = [2, 3, 5, 8]

## NOVA = liberada, fora do conjunto inicial e nunca levada para uma run.
func is_new(is_rule: bool, id: String) -> bool:
	if _tutorial_on():
		return false
	if is_rule:
		return not STARTER_RULES.has(id) and unlocked_rules.has(id) and not taken_rules.has(id)
	return not STARTER_CARDS.has(id) and unlocked_cards.has(id) and not taken_cards.has(id)

## Chamado quando a Lei/Carta entra na run do jogador (RunManager).
func mark_taken(is_rule: bool, id: String) -> void:
	if _tutorial_on() or id == "":
		return
	var arr: Array[String] = taken_rules if is_rule else taken_cards
	if arr.has(id):
		return
	arr.append(id)
	save_data()

## Fim de duelo vencido: Leis ativas e Cartas jogadas com que o jogador nunca
## tinha vencido rendem Coroas (pagas no fim da run, com o resto). Devolve
## [{name, coroas, rule}] do que foi descoberto agora.
func register_discoveries(rules: Array, cards: Array) -> Array:
	var found: Array = []
	if _tutorial_on():
		return found
	for r in rules:
		if r == null or STARTER_RULES.has(r.id) or not unlocked_rules.has(r.id) or won_rules.has(r.id):
			continue
		won_rules.append(r.id)
		found.append({"name": str(r.name), "coroas": DISCOVERY_RULE_COROAS[clampi(int(r.rarity), 0, 3)], "rule": true})
	for c in cards:
		if c == null or STARTER_CARDS.has(c.id) or not unlocked_cards.has(c.id) or won_cards.has(c.id):
			continue
		won_cards.append(c.id)
		found.append({"name": str(c.name), "coroas": DISCOVERY_CARD_COROAS[clampi(int(c.rarity), 0, 3)], "rule": false})
	for f in found:
		run_discovery_coroas += int(f["coroas"])
		run_discoveries.append(f)
	if not found.is_empty():
		save_data()
	return found

func register_duel_win(node_type: int) -> void:
	if _tutorial_on():
		return
	if node_type == MapNode.NodeType.Chefe:
		run_boss_won = true
	elif node_type == MapNode.NodeType.DueloForte:
		run_strong_won += 1
	else:
		run_duels_won += 1

# Quanto a run vale agora (sem pagar). O Chefe derrotado já está contado.
func preview_run_coroas() -> int:
	if _tutorial_on():
		return 0
	var total := run_duels_won * COROAS_PER_DUEL + run_strong_won * COROAS_PER_STRONG
	if run_boss_won:
		total += COROAS_BOSS_WIN
	total += run_discovery_coroas
	return total

# [{name, rarity}] das Leis/Cartas da run, para a tela de fim de run.
func _snapshot_names(items: Array) -> Array:
	var out: Array = []
	for it in items:
		out.append({"name": str(it.name), "rarity": int(it.rarity)})
	return out

# Paga as Coroas da run, guarda o resumo em last_summary e zera as estatísticas
# (não paga duas vezes). `won` = a run terminou com o Chefe derrotado.
# `ends_run`: false ao ABANDONAR a run (paga o que rendeu, mas não abre o Grimório).
func settle_run(won: bool = false, ends_run: bool = true) -> int:
	var amount := preview_run_coroas()
	last_summary = {
		"won": won, "duels": run_duels_won, "strong": run_strong_won,
		"boss": run_boss_won, "total": amount, "before": coroas, "after": coroas + amount,
		"gold": RunManager.gold, "laws": _snapshot_names(RunManager.active_rules),
		"cards": _snapshot_names(RunManager.player_deck),
		"discovery": run_discovery_coroas, "discoveries": run_discoveries.duplicate(),
	}
	var opened := false
	if ends_run and not grimorio_unlocked and not _tutorial_on():
		grimorio_unlocked = true
		grimorio_just_unlocked = true
		opened = true
	if amount > 0:
		coroas += amount
	if amount > 0 or opened:
		save_data()
		changed.emit()
	reset_run_stats()
	return amount
