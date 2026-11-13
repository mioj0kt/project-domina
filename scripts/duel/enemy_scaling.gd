class_name EnemyScaling
extends RefCounted

# Quanto o inimigo vem preparado, conforme o ponto da run: o BIOMA (floresta,
# deserto, mina) pesa mais, e a segunda metade de cada mapa (camada 4 em diante)
# soma um pouco. Antes os números eram fixos por tipo de duelo, então o fim da
# mina tinha o mesmo tanto de Cartas e Leis que o começo da floresta.
#
# Leis = quantas Leis ALEATÓRIAS a IA ganha (as fixas do modo — Coroa de Ferro,
# Lei exclusiva do Duelo Forte, lei do chefe — vêm por cima).
# Cartas = tamanho do baralho de Cartas de Ação da IA.

const BIOMES: Array[String] = ["floresta", "deserto", "mina"]
const LATE_LAYER: int = 4        # camada a partir da qual conta como "fim do mapa"

# [começo do mapa, fim do mapa] por bioma
const STANDARD_RULES: Array = [[0, 0], [1, 1], [2, 2]]
const STANDARD_CARDS: Array = [[2, 3], [3, 4], [4, 5]]
# Duelo Forte e Chefe: um valor por bioma
const HARD_RULES: Array = [1, 2, 2]
const HARD_CARDS: Array = [3, 4, 5]
const BOSS_RULES: Array = [1, 2, 3]
const BOSS_CARDS: Array = [3, 4, 5]

static func biome_index() -> int:
	return maxi(0, BIOMES.find(RunManager.map_biome))

static func layer() -> int:
	return RunManager.current_node.id.x if RunManager.current_node != null else 0

static func is_late() -> bool:
	return layer() >= LATE_LAYER

static func standard_rules() -> int:
	return int(STANDARD_RULES[biome_index()][1 if is_late() else 0])

static func standard_cards() -> int:
	return int(STANDARD_CARDS[biome_index()][1 if is_late() else 0])

static func hard_rules() -> int:
	return int(HARD_RULES[biome_index()])

static func hard_cards() -> int:
	return int(HARD_CARDS[biome_index()])

static func boss_rules() -> int:
	return int(BOSS_RULES[biome_index()])

static func boss_cards() -> int:
	return int(BOSS_CARDS[biome_index()])

# Profundidade usada para sortear a RARIDADE das cartas da IA
# (LootTables.AI_RARITY_BY_DEPTH, 1 = só comuns ... 7 = muitas lendárias).
# Floresta 1-4, deserto 3-6, mina 4-7; Duelo Forte +1; chefes 5 / 6 / 7.
static func card_depth(kind: String) -> int:
	var b: int = biome_index()
	if kind == "boss":
		return 5 + b
	var d: int
	match b:
		0: d = mini(layer(), 4)
		1: d = mini(layer() + 2, 6)
		_: d = mini(layer() + 3, 7)
	if kind == "hard":
		d += 1
	return clampi(d, 1, 7)
