class_name MapGenerator
extends Node

# Mapa de 8 camadas: 0 = começo, 1..6 = intermediárias, 7 = chefe. Cada camada
# intermediária tem um "papel" fixo (ver LAYER_ROLES): garante o que não pode
# faltar (Loja antes do chefe, um duelo forte no meio) e sorteia o resto com
# pesos. Evento é a casa "?" (EventView); Altar é o altar de leis.
@export var layers_count: int = 8
@export var max_nodes_per_layer: int = 4
@export var min_nodes_per_layer: int = 2

# "must": tipos garantidos (1 nó cada, em posição aleatória). "fill": pesos do
# resto. "caps": máximo de nós de um tipo na camada (por padrão só Loja/Aposta: 1).
# "max_nodes": teto de largura da camada (a antes do chefe é mais estreita).
const LAYER_ROLES: Dictionary = {
	1: {"must": [], "fill": {MapNode.NodeType.Duelo: 65, MapNode.NodeType.Evento: 35}},
	2: {"must": [MapNode.NodeType.Evento], "fill": {MapNode.NodeType.Duelo: 50, MapNode.NodeType.Aposta: 20, MapNode.NodeType.Evento: 15, MapNode.NodeType.Altar: 32}},
	3: {"must": [MapNode.NodeType.Loja], "fill": {MapNode.NodeType.Duelo: 45, MapNode.NodeType.Evento: 40, MapNode.NodeType.Altar: 32}},
	4: {"must": [MapNode.NodeType.DueloForte], "fill": {MapNode.NodeType.Duelo: 40, MapNode.NodeType.Evento: 35, MapNode.NodeType.Aposta: 25, MapNode.NodeType.Altar: 26}},
	5: {"must": [MapNode.NodeType.Evento], "fill": {MapNode.NodeType.Duelo: 35, MapNode.NodeType.DueloForte: 20, MapNode.NodeType.Evento: 20, MapNode.NodeType.Aposta: 10, MapNode.NodeType.Altar: 32}},
	6: {"must": [MapNode.NodeType.Loja], "fill": {MapNode.NodeType.Duelo: 40, MapNode.NodeType.DueloForte: 35, MapNode.NodeType.Evento: 25}, "max_nodes": 3},
}
# Biomas cujos eventos "?" ainda não existem: ali o mapa não sorteia casas de
# Evento (viram duelos). Tire o bioma da lista quando houver eventos dele.
const BIOMES_WITHOUT_EVENTS: Array[String] = []
var biome: String = "floresta"

# Largura sorteada das camadas intermediárias (nº de nós: peso).
const WIDTH_WEIGHTS: Dictionary = {2: 30, 3: 45, 4: 25}
const SINGLE_PER_LAYER: Array = [MapNode.NodeType.Loja, MapNode.NodeType.Aposta, MapNode.NodeType.Altar]

# Lista com tabuleiros quadrados e retangulares: Vector2i(Linhas, Colunas)
const POSSIBLE_BOARD_SIZES: Array[Vector2i] = [
	Vector2i(6, 6),
	Vector2i(8, 8),
	Vector2i(10, 10),
	Vector2i(4, 8),
	Vector2i(6, 8),
	Vector2i(8, 6),
	Vector2i(8, 10),
	Vector2i(7, 7),
	Vector2i(9, 9),
	Vector2i(6, 10)
]
# Chance de um duelo sortear uma disposição diferente da clássica.
const SPECIAL_LAYOUT_CHANCE: float = 0.8

func generate_map() -> Array[Array]:
	var layers: Array[Array] = []

	for layer_index in range(layers_count):
		var current_layer: Array[MapNode] = []
		if layer_index == 0 or layer_index == layers_count - 1:
			current_layer.append(_make_node(layer_index, 0, _edge_type(layer_index)))
		else:
			var types = _roll_layer_types(layer_index)
			for node_index in range(types.size()):
				current_layer.append(_make_node(layer_index, node_index, types[node_index]))
		layers.append(current_layer)

	_ensure_altar(layers)
	_connect_layers(layers)
	return layers

# Toda run tem pelo menos um Altar de Leis nas camadas 2..5 (o sorteio por
# peso sozinho deixava ~65% das runs sem nenhum). Troca um nó "dispensável":
# nunca um tipo garantido pelo papel da camada nem o último nó de combate.
func _ensure_altar(layers: Array[Array]) -> void:
	var mid: Array = []
	for l in range(2, 6):
		if l < layers.size():
			mid.append(l)
	for l in mid:
		for n in layers[l]:
			if n.type == MapNode.NodeType.Altar:
				return
	mid.shuffle()
	for l in mid:
		var layer: Array = layers[l]
		var must: Array = LAYER_ROLES.get(l, {"must": []})["must"]
		var combat: int = 0
		for n in layer:
			if n.type == MapNode.NodeType.Duelo or n.type == MapNode.NodeType.DueloForte:
				combat += 1
		var candidates: Array = []
		for n in layer:
			var of_type: int = 0
			for m in layer:
				if m.type == n.type:
					of_type += 1
			var protected: bool = of_type <= must.count(n.type)
			if n.type == MapNode.NodeType.Duelo or n.type == MapNode.NodeType.DueloForte:
				protected = protected or combat <= 1
			if n.type in [MapNode.NodeType.Duelo, MapNode.NodeType.DueloForte, MapNode.NodeType.Evento, MapNode.NodeType.Aposta] and not protected:
				candidates.append(n)
		if not candidates.is_empty():
			var chosen: MapNode = candidates.pick_random()
			chosen.type = MapNode.NodeType.Altar
			return

func _edge_type(layer: int) -> int:
	return MapNode.NodeType.Começo if layer == 0 else MapNode.NodeType.Chefe

func _make_node(layer: int, index: int, type: int) -> MapNode:
	var node = MapNode.new()
	node.id = Vector2i(layer, index)
	node.type = type
	match type:
		MapNode.NodeType.Começo:
			node.board_size = Vector2i(8, 8)
		MapNode.NodeType.Chefe:
			node.board_size = Vector2i(10, 10)   # chefe em tabuleiro maior
		MapNode.NodeType.Duelo, MapNode.NodeType.DueloForte:
			node.board_size = POSSIBLE_BOARD_SIZES.pick_random()
			node.board_layout = _roll_layout(node.board_size)
	return node

# Disposição inicial do duelo: clássica ou uma das que servem para o tamanho.
func _roll_layout(size: Vector2i) -> String:
	if randf() >= SPECIAL_LAYOUT_CHANCE:
		return Board.LAYOUT_CLASSIC
	var options: Array[String] = Board.layouts_for_size(size.x, size.y)
	if options.is_empty():
		return Board.LAYOUT_CLASSIC
	return options.pick_random()

# Sorteia os tipos de uma camada intermediária seguindo LAYER_ROLES.
func _roll_layer_types(layer: int) -> Array:
	var role: Dictionary = LAYER_ROLES.get(layer, {"must": [], "fill": {MapNode.NodeType.Duelo: 100}})
	var must: Array = (role["must"] as Array).duplicate()
	var fill: Dictionary = (role["fill"] as Dictionary).duplicate()
	if biome in BIOMES_WITHOUT_EVENTS:
		for i in range(must.size()):
			if must[i] == MapNode.NodeType.Evento:
				must[i] = MapNode.NodeType.Duelo
		fill.erase(MapNode.NodeType.Evento)
	var width: int = _roll_width(mini(int(role.get("max_nodes", max_nodes_per_layer)), max_nodes_per_layer))
	width = maxi(width, must.size())
	var types: Array = must.duplicate()
	while types.size() < width:
		var t: int = _pick_weighted(fill)
		# Loja/Aposta: no máximo uma por camada (senão troca por duelo).
		if t in SINGLE_PER_LAYER and types.has(t):
			t = MapNode.NodeType.Duelo
		types.append(t)
	# Garante ao menos um nó de combate comum para o caminho "seguro".
	if not types.has(MapNode.NodeType.Duelo) and not types.has(MapNode.NodeType.DueloForte):
		types[types.size() - 1] = MapNode.NodeType.Duelo
	types.shuffle()
	return types

func _roll_width(max_w: int) -> int:
	var pool: Dictionary = {}
	for w in WIDTH_WEIGHTS:
		if w >= min_nodes_per_layer and w <= max_w:
			pool[w] = WIDTH_WEIGHTS[w]
	if pool.is_empty():
		return min_nodes_per_layer
	return _pick_weighted(pool)

func _pick_weighted(weights: Dictionary) -> int:
	var total: float = 0.0
	for k in weights:
		total += float(weights[k])
	var roll: float = randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return weights.keys()[0]

func _connect_layers(layers: Array[Array]) -> void:
	for i in range(layers.size() - 1):
		var current_layer = layers[i]
		var next_layer = layers[i + 1]
		
		var min_target_idx = 0 
		
		for node_idx in range(current_layer.size()):
			var node = current_layer[node_idx]
			
			var ratio = float(node_idx) / float(max(1, current_layer.size() - 1))
			var ideal_target = int(round(ratio * (next_layer.size() - 1)))
			
			var start_idx = max(min_target_idx, ideal_target - 1)
			var max_reach = ideal_target + 1
			
			if node_idx == current_layer.size() - 1:
				max_reach = next_layer.size() - 1
				
			var end_idx = clamp(max_reach, start_idx, next_layer.size() - 1)
			
			var num_connections = randi_range(1, 2)
			if start_idx == end_idx:
				num_connections = 1
				
			var highest_child_idx = start_idx
			
			for step in range(num_connections):
				var target_idx = clamp(start_idx + step, 0, end_idx)
				var target_node = next_layer[target_idx]
				
				if not node.children.has(target_node):
					node.children.append(target_node)
					target_node.parents.append(node)
					
				highest_child_idx = max(highest_child_idx, target_idx)
			
			min_target_idx = highest_child_idx

	for i in range(1, layers.size()):
		var next_layer = layers[i]
		var current_layer = layers[i - 1]
		
		for target_idx in range(next_layer.size()):
			var target = next_layer[target_idx]
			
			if target.parents.is_empty():
				var ratio = float(target_idx) / float(max(1, next_layer.size() - 1))
				var parent_idx = clamp(int(round(ratio * (current_layer.size() - 1))), 0, current_layer.size() - 1)
				var parent = current_layer[parent_idx]
				
				parent.children.append(target)
				target.parents.append(parent)
