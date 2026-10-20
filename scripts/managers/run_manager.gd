extends Node

var current_board_size: Vector2i = Vector2i(8, 8)
# Disposição inicial das peças do duelo atual (Board.LAYOUT_*); só duelos sorteados usam outra.
var current_board_layout: String = Board.LAYOUT_CLASSIC
var current_node_type: int = 1
var gold: int = 0

# Inflação da Loja: cada Lei/Carta comprada na run encarece as próximas em 6%
# (até 8 compras). Fora do tutorial. Reroll/remoção têm escalada própria.
const PRICE_INFLATION_STEP: float = 0.06
const PRICE_INFLATION_MAX_PURCHASES: int = 8
var shop_purchases: int = 0

func get_shop_price(base_cost: int) -> int:
	if TutorialManager != null and TutorialManager.is_active:
		return base_cost
	var n: int = mini(shop_purchases, PRICE_INFLATION_MAX_PURCHASES)
	return int(round(float(base_cost) * (1.0 + PRICE_INFLATION_STEP * float(n))))

func register_shop_purchase() -> void:
	shop_purchases += 1

# Bioma do mapa desta run ("floresta" | "deserto"; ver ForestBackground.THEMES).
var map_biome: String = "floresta"
# true logo depois de entrar num bioma novo: o mapa mostra o título dele uma vez.
var biome_intro_pending: bool = false

# Nomes e ordem dos biomas da run (a floresta vem primeiro; o último termina a run).
const BIOME_ORDER: Array[String] = ["floresta", "deserto"]
const BIOME_TITLES: Dictionary = {"floresta": "FLORESTA", "deserto": "DESERTO DAS TORRES"}

func has_next_biome() -> bool:
	return BIOME_ORDER.find(map_biome) >= 0 and BIOME_ORDER.find(map_biome) < BIOME_ORDER.size() - 1

# Chefe derrotado e ainda há outro mapa: gera o próximo bioma mantendo ouro,
# baralho e Leis da run (o mapa novo é sorteado quando a cena do mapa abre).
func advance_to_next_biome() -> void:
	if not has_next_biome():
		return
	map_biome = BIOME_ORDER[BIOME_ORDER.find(map_biome) + 1]
	biome_intro_pending = true
	map_data = []
	current_node = null
	visited_connections = []
	current_board_size = Vector2i(8, 8)
	current_board_layout = Board.LAYOUT_CLASSIC
	current_node_type = 1
	clear_ambush()

var map_data: Array[Array] = []
var current_node: MapNode = null
var visited_connections: Array[String] = []

# RunManager é a fonte única da verdade para as Leis (RuleCard) ativas no run.
# A validação de limite (6) e de incompatibilidade entre leis vive só aqui dentro,
# no RulePipeline — nenhum outro lugar do jogo deve manter sua própria cópia
# dessa lista. Consumidores que precisam de um RulePipeline "ao vivo" (ex: o
# duelo em main.gd) devem escutar o sinal `rules_updated` e reconstruir o
# pipeline do duelo a partir de `active_rules`, em vez de duplicar chamadas
# de add/remove em duas listas paralelas.
var rule_pipeline: RulePipeline = RulePipeline.new()

var active_rules: Array[RuleCard]:
	get:
		return rule_pipeline.active_rules

var player_deck: Array[ActionCard] = []

# Lei do chefe da floresta sorteada para ESTE run (id; "" = ainda não sorteada).
# Fica fixa durante o run (derrota/retentativa enfrentam a mesma) e muda no próximo.
var forest_boss_law_id: String = ""

func get_forest_boss_law_id(options: Array) -> String:
	if forest_boss_law_id == "" or not options.has(forest_boss_law_id):
		forest_boss_law_id = options[randi() % options.size()]
	return forest_boss_law_id

signal rules_updated()

# Eventos (nó "?") já vistos nesta run — não se repetem (ver EventView).
var seen_event_ids: Array = []

# Emboscada (desfecho de um Evento "?"): o próximo duelo é uma escaramuça
# 6x6 forçada. kind: "" = nenhuma, "ambushed" = o jogador foi pego de surpresa
# (inimigo com 1 carta a mais), "setup" = o jogador armou a emboscada (inimigo
# com 1 carta a menos). ambush_bonus_gold é pago na vitória (linha "SAQUE").
const AMBUSH_BOARD_SIZE: Vector2i = Vector2i(6, 6)
var ambush_kind: String = ""
var ambush_bonus_gold: int = 0

func is_ambush_pending() -> bool:
	return ambush_kind != ""

func clear_ambush() -> void:
	ambush_kind = ""
	ambush_bonus_gold = 0

func _ready():
	start_new_run()
	if player_deck.is_empty():
		_init_default_deck()

func can_add_rule(rule: RuleCard) -> bool:
	return rule_pipeline.can_add_rule(rule)

func can_add_card_to_deck() -> bool:
	return player_deck.size() < MAX_PLAYER_DECK_SIZE

func add_rule(rule: RuleCard) -> bool:
	var added = rule_pipeline.add_rule(rule)
	if added:
		rules_updated.emit()
	return added

func remove_rule(rule_id: String) -> void:
	rule_pipeline.remove_rule(rule_id)
	rules_updated.emit()

func start_new_run():
	gold = 0
	shop_purchases = 0
	current_board_size = Vector2i(8, 8)
	current_board_layout = Board.LAYOUT_CLASSIC
	current_node_type = 1
	map_data = []
	current_node = null
	visited_connections = []
	forest_boss_law_id = ""
	map_biome = "floresta"
	biome_intro_pending = false
	clear_ambush()
	seen_event_ids.clear()
	rule_pipeline.clear_rules()
	_init_default_deck()
	MetaProgress.reset_run_stats()
	# A mochila do Grimório é entregue só pelo botão JOGAR (MetaProgress.consume_bag_into_run).
	

# ==========================


# DEBUG: DE TODAS AS CARTAS
const DEBUG_ALL_CARDS: bool = false


# ==========================

func _init_default_deck() -> void:
	player_deck.clear()
	if DEBUG_ALL_CARDS:
		for card in LootTables.get_all_action_cards():
			# Debug ignora o limite de 20.
			player_deck.append(card)
		return
	player_deck.append(CardSecondChance.new())
	player_deck.append(CardLuckyDuel.new())
	player_deck.append(CardCoinOfDestiny.new())
	
func add_gold(amount: int) -> void:
	gold += amount

# Ouro vindo de EFEITOS (Leis e Cartas: Carnificina, Vingança, Sacrifício,
# Retaliação) tem teto por duelo, para não superar o ouro "normal" do duelo
# (base ~6-12 + capturas/sobreviventes). Devolve quanto realmente entrou.
const EFFECT_GOLD_CAP_PER_DUEL: int = 12
var effect_gold_this_duel: int = 0

func reset_effect_gold() -> void:
	effect_gold_this_duel = 0

func add_effect_gold(amount: int) -> int:
	var room: int = maxi(0, EFFECT_GOLD_CAP_PER_DUEL - effect_gold_this_duel)
	var granted: int = mini(amount, room)
	effect_gold_this_duel += granted
	gold += granted
	return granted

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false

const MAX_PLAYER_DECK_SIZE: int = 20

# Ponto único de entrada pra adicionar uma carta ao inventário do jogador —
# respeita o limite máximo de 20 cartas. Devolve false (e não adiciona
# nada) se o inventário já estiver cheio.
func add_card_to_deck(card: ActionCard) -> bool:
	if not can_add_card_to_deck():
		return false
	player_deck.append(card)
	return true
