class_name ForestBackground
extends Node2D

# Fundo procedural do mapa da floresta: um tabuleiro de casas (alternando
# claras = grama/madeira e escuras = terra/musgo) com moldura de madeira,
# árvores e detalhes espalhados (mais árvores nas bordas, nada em cima das
# trilhas) e uma clareira sob cada nó. Tudo é gerado a partir dos sprites de
# res://assets/sprites/map/forest/ com uma semente derivada do próprio mapa,
# então o mesmo mapa sempre gera o mesmo fundo.

const DIR := "res://assets/sprites/map/forest/"
const BOARD_DIR := "tabuleiro/"
const NATIVE_TILE: int = 26
const FRAME: int = 10
const FRAME_CORNER: int = 12
const FRAME_SRC_COLS: int = 9
const FRAME_SRC_ROWS: int = 13

# Arte do tabuleiro da floresta (cream/ameixa): casas + detalhes pequenos em
# res://assets/sprites/map/forest/tabuleiro/<pasta>/<nome>.png
const LIGHT_TILES: Array[String] = [
	"casas/casa_clara_grama", "casas/casa_clara_grama", "casas/casa_clara_tabuas",
	"casas/casa_madeira_textura_1", "casas/casa_madeira_textura_2", "casas/casa_madeira_textura_3",
	"casas/casa_madeira_textura_4", "casas/casa_madeira_textura_5", "casas/casa_madeira_textura_6",
]
const DARK_TILES: Array[String] = ["casas/casa_escura"]

# Árvores e arbustos (já vêm com a sombra e o chão da cor da casa).
const TREES_LIGHT: Array[String] = [
	"arvores/arvore_copa_1_chao_claro", "arvores/arvore_copa_3_chao_claro",
	"arvores/arvore_copa_6_chao_claro", "arvores/arvore_copa_3_chao_claro",
]
const TREES_DARK: Array[String] = [
	"arvores/arvore_copa_2_chao_escuro", "arvores/arvore_copa_4_chao_escuro",
	"arvores/arvore_copa_5_chao_escuro", "arvores/arvore_copa_4_chao_escuro",
]
const BUSHES_LIGHT: Array[String] = [
	"vegetacao/arbusto_4_chao_claro", "vegetacao/arbusto_6_chao_claro",
	"vegetacao/arbusto_8_chao_claro", "vegetacao/arbusto_11_chao_claro",
]
const BUSHES_DARK: Array[String] = [
	"vegetacao/arbusto_1_chao_escuro", "vegetacao/arbusto_2_chao_escuro",
	"vegetacao/arbusto_3_chao_escuro", "vegetacao/arbusto_5_chao_escuro",
	"vegetacao/arbusto_7_chao_escuro", "vegetacao/arbusto_9_chao_escuro",
	"vegetacao/arbusto_10_chao_escuro", "vegetacao/arbusto_12_chao_escuro",
]

# As árvores são grandes (copa de ~2 casas de largura): a base do tronco fica
# a TREE_GROUND_Y da altura da arte, e é ela que se ancora na casa sorteada.
const TREE_GROUND_Y: float = 0.78
const TREE_MIN_SPACING: float = 1.2   # em casas, entre troncos
const TREE_PATH_CLEAR: float = 0.6   # copa a pelo menos isto (em casas) das trilhas
const TREE_NODE_CLEAR: float = 0.85   # copa a pelo menos isto (em casas) dos nós

# Mato: sorteado à parte (e várias vezes por casa) pra casa ficar bem verde.
const GRASS_LIGHT: Array[String] = [
	"vegetacao/tufo_grama_claro_1", "vegetacao/tufo_grama_claro_2", "vegetacao/tufo_grama_claro_alto",
	"vegetacao/samambaia_clara", "vegetacao/moitinha_clara", "vegetacao/trevo",
	"vegetacao/grama_fresta", "vegetacao/flor_branca_clara",
]
const GRASS_DARK: Array[String] = [
	"vegetacao/tufo_grama_escuro_1", "vegetacao/tufo_grama_escuro_2", "vegetacao/tufo_grama_escuro_3",
	"vegetacao/tufo_grama_escuro_alto", "vegetacao/samambaia", "vegetacao/moita_pequena",
	"vegetacao/flor_branca", "vegetacao/flor_vermelha",
]
const GRASS_ATTEMPTS: int = 6
const GRASS_CHANCE: float = 0.6

# Peças "grandes" (tocos, moitas, pedras): mais comuns perto da borda lateral.
# Separadas por cor da casa pra o contorno ficar tom sobre tom.
const BIG_LIGHT: Array[String] = [
	"madeira/toco_cortado_chao_claro", "vegetacao/moita_grande", "vegetacao/samambaia_grande",
	"madeira/tora_deitada", "vegetacao/moita", "pedras/pedra_grande_2",
	"pedras/rocha", "pedras/pedra_musgo", "pedras/rochas_grupo", "pedras/pedra_media_1",
]
const BIG_DARK: Array[String] = [
	"madeira/toco_cortado_chao_escuro", "vegetacao/moita_grande", "vegetacao/samambaia_grande",
	"madeira/tronco_caido", "vegetacao/moita_frutos", "pedras/pedra_grande_3",
	"pedras/pedra_rachada", "pedras/pedra_lisa", "pedras/pedra_media_2", "pedras/rochas_grupo",
]
const SMALL_LIGHT: Array[String] = [
	"vegetacao/tufo_grama_claro_1", "vegetacao/tufo_grama_claro_2", "vegetacao/tufo_grama_claro_alto",
	"vegetacao/flor_branca_clara", "vegetacao/samambaia_clara", "vegetacao/moitinha_clara",
	"pedras/pedrinha_clara", "pedras/seixos", "vegetacao/trevo", "folhas/folha_verde_clara", "folhas/folha_seca",
	"vegetacao/grama_fresta", "cogumelos/cogumelo", "madeira/galho_1", "madeira/no_madeira",
]
const SMALL_DARK: Array[String] = [
	"vegetacao/tufo_grama_escuro_1", "vegetacao/tufo_grama_escuro_2", "vegetacao/tufo_grama_escuro_3",
	"vegetacao/tufo_grama_escuro_alto", "vegetacao/flor_branca", "vegetacao/flor_vermelha",
	"vegetacao/samambaia", "vegetacao/moita_pequena", "pedras/pedra", "pedras/pedrinha", "pedras/seixos",
	"folhas/folha_verde_1", "folhas/folha_verde_2", "folhas/folha_seca_2", "folhas/folhas_mistas",
	"cogumelos/cogumelos_duplo", "madeira/galho_2", "madeira/raiz", "madeira/rachadura",
	"madeira/toco_pequeno", "madeira/toco_em_pe",
]


# --- Deserto das Torres (res://assets/sprites/map/deserto/) ---------------
# Areia clara / arenito escuro. Os "grandes" do cenário são monólitos de pedra
# com hieróglifos de damas e torres de xadrez meio enterradas (no lugar das
# árvores). Moldura fina de pedra com areia acumulada nos cantos.
const DESERT_LIGHT_TILES: Array[String] = [
	"casas/casa_clara_areia", "casas/casa_clara_areia", "casas/casa_clara_ondulada",
	"casas/casa_clara_rachada", "casas/casa_clara_textura_1", "casas/casa_clara_textura_2",
	"casas/casa_clara_textura_3", "casas/casa_clara_textura_4", "casas/casa_clara_textura_5",
	"casas/casa_clara_textura_6",
]
const DESERT_DARK_TILES: Array[String] = ["casas/casa_escura", "casas/casa_escura_2", "casas/casa_escura_3"]
const DESERT_TREES_LIGHT: Array[String] = [
	"monolitos/monolito_1_chao_claro", "monolitos/monolito_3_chao_claro", "monolitos/monolito_6_chao_claro",
	"torres/torre_enterrada_1_chao_claro", "torres/torre_enterrada_3_chao_claro", "torres/torre_enterrada_6_chao_claro",
	"monolitos/monolito_1_chao_claro", "monolitos/monolito_3_chao_claro",
]
const DESERT_TREES_DARK: Array[String] = [
	"monolitos/monolito_2_chao_escuro", "monolitos/monolito_4_chao_escuro", "monolitos/monolito_5_chao_escuro",
	"torres/torre_enterrada_2_chao_escuro", "torres/torre_enterrada_4_chao_escuro", "torres/torre_enterrada_5_chao_escuro",
	"monolitos/monolito_2_chao_escuro", "monolitos/monolito_4_chao_escuro",
]
const DESERT_BUSHES_LIGHT: Array[String] = [
	"vegetacao/arbusto_4_chao_claro", "vegetacao/arbusto_6_chao_claro",
	"vegetacao/arbusto_8_chao_claro", "vegetacao/arbusto_11_chao_claro",
]
const DESERT_BUSHES_DARK: Array[String] = [
	"vegetacao/arbusto_1_chao_escuro", "vegetacao/arbusto_2_chao_escuro",
	"vegetacao/arbusto_3_chao_escuro", "vegetacao/arbusto_5_chao_escuro",
	"vegetacao/arbusto_7_chao_escuro", "vegetacao/arbusto_9_chao_escuro",
	"vegetacao/arbusto_10_chao_escuro", "vegetacao/arbusto_12_chao_escuro",
]
const DESERT_GRASS: Array[String] = [
	"vegetacao/tufo_seco_1", "vegetacao/tufo_seco_2", "vegetacao/tufo_seco_3",
	"vegetacao/tufo_seco_alto", "vegetacao/capim_ralo", "vegetacao/grama_fresta",
	"vegetacao/ondinha_de_areia", "vegetacao/ondinha_de_areia", "vegetacao/cacto_mini",
	"vegetacao/flor_do_deserto", "vegetacao/flor_do_deserto_2",
]
const DESERT_BIG_LIGHT: Array[String] = [
	"ruinas/coluna_quebrada_chao_claro", "ruinas/coluna_caida_chao_claro", "ruinas/tora_de_ruina_chao_claro",
	"ruinas/carcaca_de_vaso_grande_chao_claro", "ruinas/laje_inclinada_chao_claro", "ruinas/degrau_soterrado_chao_claro",
	"pedras/rocha", "pedras/rochas_grupo", "pedras/pedra_grande_2", "pedras/pedra_rachada", "ruinas/escada_de_ruina",
]
const DESERT_BIG_DARK: Array[String] = [
	"ruinas/coluna_quebrada_chao_escuro", "ruinas/coluna_caida_chao_escuro", "ruinas/tora_de_ruina_chao_escuro",
	"ruinas/carcaca_de_vaso_grande_chao_escuro", "ruinas/laje_inclinada_chao_escuro", "ruinas/degrau_soterrado_chao_escuro",
	"pedras/rocha", "pedras/rochas_grupo", "pedras/pedra_grande_3", "pedras/pedra_lisa", "ruinas/escada_de_ruina",
]
const DESERT_SMALL: Array[String] = [
	"pedras/pedrinha", "pedras/pedrinha_clara", "pedras/pedra", "pedras/seixos", "pedras/pedra_media_1",
	"pedras/pedra_media_2", "folhas/folha_seca_1", "folhas/folha_seca_2", "folhas/folha_seca_clara",
	"ossos_e_restos/osso", "ossos_e_restos/caco_de_vaso", "ossos_e_restos/corda_velha",
	"ossos_e_restos/cranio_pequeno", "ossos_e_restos/escaravelho", "ossos_e_restos/peca_de_xadrez_quebrada",
	"ruinas/bloco_de_ruina", "ruinas/bloco_de_ruina_2", "ruinas/bloco_de_ruina_3",
	"ruinas/hieroglifo_no_chao", "ruinas/laje_com_coroa",
	"poeira/areia_soprada_1", "poeira/areia_soprada_2", "poeira/areia_soprada_3",
]

# Tudo que muda de um bioma de mapa para outro. "floresta" usa as constantes de
# cima; "deserto" as DESERT_*. `frame`: "moldura" = faixa 9x13 repetida (floresta);
# "bordas" = moldura fina em folha (deserto), ver _draw_frame_sheet.
const THEMES: Dictionary = {
	"floresta": {
		"dir": "res://assets/sprites/map/forest/",
		"trail_dir": "res://assets/sprites/map/forest/trilhas_grade/",
		"tiles_light": LIGHT_TILES, "tiles_dark": DARK_TILES,
		"trees_light": TREES_LIGHT, "trees_dark": TREES_DARK,
		"bushes_light": BUSHES_LIGHT, "bushes_dark": BUSHES_DARK,
		"grass_light": GRASS_LIGHT, "grass_dark": GRASS_DARK,
		"big_light": BIG_LIGHT, "big_dark": BIG_DARK,
		"small_light": SMALL_LIGHT, "small_dark": SMALL_DARK,
		"tree_ground_y": 0.78, "tree_density": 1.0, "grass_scale": 1.0,
		"frame": "moldura", "frame_pad": Vector2(10, 10),
		"clearing_node": "decoracao/clareira_nodo", "clearing_boss": "decoracao/clareira_boss",
	},
	"deserto": {
		"dir": "res://assets/sprites/map/deserto/",
		"trail_dir": "res://assets/sprites/map/deserto/tabuleiro/trilhas_grade/",
		"tiles_light": DESERT_LIGHT_TILES, "tiles_dark": DESERT_DARK_TILES,
		"trees_light": DESERT_TREES_LIGHT, "trees_dark": DESERT_TREES_DARK,
		"bushes_light": DESERT_BUSHES_LIGHT, "bushes_dark": DESERT_BUSHES_DARK,
		"grass_light": DESERT_GRASS, "grass_dark": DESERT_GRASS,
		"big_light": DESERT_BIG_LIGHT, "big_dark": DESERT_BIG_DARK,
		"small_light": DESERT_SMALL, "small_dark": DESERT_SMALL,
		"tree_ground_y": 0.82, "tree_density": 0.8, "grass_scale": 0.7,
		"frame": "bordas", "frame_pad": Vector2(8, 10),
		"clearing_node": "", "clearing_boss": "",
		"swirls": "tabuleiro/poeira/redemoinho_pequeno",
	},
}

# Resultado público: retângulo (coords do mundo) ocupado pela moldura.
var world_rect: Rect2 = Rect2()

var _tile: float = 78.0
var _scale: int = 3
var _tiles: Array = []      # [Texture2D, Rect2, flip_h, flip_v]
var _decor: Array = []      # [Texture2D, Vector2 centro, y_ordem]
var _clearings: Array = []  # [Texture2D, Vector2 centro]
var _board_rect: Rect2 = Rect2()
var _frame_tex: Texture2D = null

# Bioma do mapa ("floresta" | "deserto"); defina ANTES de build().
var biome: String = "floresta"
var _th: Dictionary = THEMES["floresta"]
var _dir: String = DIR
var _swirls: Array = []     # [Vector2 base, float fase]
var _swirl_t: float = 0.0
var _swirl_frame: int = -1
const SWIRL_FRAME_PX: int = 8
const SWIRL_FRAMES: int = 4
var _swirl_tex: Texture2D = null

static var _tex_cache: Dictionary = {}

static func _tex(sub: String, dir: String = DIR) -> Texture2D:
	var key = dir + sub
	if not _tex_cache.has(key):
		var path = dir + sub + ".png"
		_tex_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[key]

# layers: RunManager.map_data (Array[Array] de MapNode já posicionados).
func build(layers: Array, tile_px: float, sprite_scale: int, min_col: int, max_col: int, min_row: int, max_row: int) -> void:
	_tile = tile_px
	_scale = sprite_scale
	_tiles.clear()
	_decor.clear()
	_clearings.clear()
	_swirls.clear()
	_th = THEMES.get(biome, THEMES["floresta"])
	_dir = _th["dir"]
	_swirl_tex = null
	var frame_name: String = "moldura" if _th["frame"] == "moldura" else "tabuleiro/borda/borda_tabuleiro_13x12"
	_frame_tex = _tex(frame_name, _dir)

	var rng = RandomNumberGenerator.new()
	rng.seed = _layout_seed(layers)

	_board_rect = Rect2(
		Vector2(min_col * _tile - _tile / 2.0, min_row * _tile - _tile / 2.0),
		Vector2((max_col - min_col + 1) * _tile, (max_row - min_row + 1) * _tile))
	var pad_v: Vector2 = (_th["frame_pad"] as Vector2) * float(_scale)
	world_rect = Rect2(_board_rect.position - pad_v, _board_rect.size + pad_v * 2.0)

	# Segmentos das trilhas e posições dos nós (pra manter decoração longe).
	var segments: Array = []
	var node_points: Array = []
	for layer in layers:
		for node in layer:
			node_points.append([node.position, node.type == MapNode.NodeType.Chefe])
			for child in node.children:
				segments.append([node.position, child.position])

	var half_cols = maxf(float(max_col), float(-min_col))
	var tree_grounds: Array[Vector2] = []
	for r in range(min_row, max_row + 1):
		for c in range(min_col, max_col + 1):
			var center = Vector2(c * _tile, r * _tile)
			var rect = Rect2(center - Vector2(_tile, _tile) / 2.0, Vector2(_tile, _tile))
			var is_light = ((r + c) % 2 + 2) % 2 == 0
			var pool: Array = _th["tiles_light"] if is_light else _th["tiles_dark"]
			var tex = _tex(BOARD_DIR + pool[rng.randi() % pool.size()], _dir)
			if tex != null:
				_tiles.append([tex, rect, rng.randf() < 0.5, rng.randf() < 0.5])

			var d_path = _distance_to_paths(center, segments)
			var d_node = _distance_to_nodes(center, node_points)
			var edge_w = clampf(absf(float(c)) / maxf(half_cols, 1.0), 0.0, 1.0)

			# Árvore (mais comum quanto mais perto da borda lateral); se não
			# vier árvore, às vezes um arbusto ou uma peça grande (toco, moita...).
			var p_tree = (0.12 + 0.45 * edge_w * edge_w) * float(_th["tree_density"])
			var placed_tree = false
			var tree_roll: float = rng.randf()
			var trees: Array = _th["trees_light"] if is_light else _th["trees_dark"]
			var t = _tex(BOARD_DIR + trees[rng.randi() % trees.size()], _dir)
			var tree_ground: Vector2 = _snap(center + _jitter(rng, 0.12))
			if tree_roll < p_tree and t != null and _tree_fits(t, tree_ground, segments, node_points, tree_grounds):
				_decor.append([t, _tree_center(t, tree_ground), tree_ground.y])
				tree_grounds.append(tree_ground)
				placed_tree = true
			elif d_path > 0.8 * _tile and d_node > 1.2 * _tile and rng.randf() < 0.20 + 0.15 * edge_w:
				var pool_big: Array[String] = []
				pool_big.append_array(_th["bushes_light"] if is_light else _th["bushes_dark"])
				pool_big.append_array(_th["big_light"] if is_light else _th["big_dark"])
				var bt = _tex(BOARD_DIR + pool_big[rng.randi() % pool_big.size()], _dir)
				if bt != null:
					_decor.append([bt, _snap(center + _jitter(rng, 0.2)), center.y])
					placed_tree = true

			# Detalhes pequenos (até 2 por casa), só fora da trilha/clareira.
			if not placed_tree and d_path > 0.75 * _tile and d_node > 1.1 * _tile:
				var smalls: Array = _th["small_light"] if is_light else _th["small_dark"]
				for attempt in range(4):
					if rng.randf() < 0.36:
						var st = _tex(BOARD_DIR + smalls[rng.randi() % smalls.size()], _dir)
						if st != null:
							var pos = _snap(center + _jitter(rng, 0.34))
							_decor.append([st, pos, pos.y])
				var grass: Array = _th["grass_light"] if is_light else _th["grass_dark"]
				for attempt in range(GRASS_ATTEMPTS):
					if rng.randf() < GRASS_CHANCE * float(_th["grass_scale"]):
						var gt = _tex(BOARD_DIR + grass[rng.randi() % grass.size()], _dir)
						if gt != null:
							var gpos = _snap(center + _jitter(rng, 0.36))
							_decor.append([gt, gpos, gpos.y])

	_decor.sort_custom(func(a, b): return a[2] < b[2])
	if _th["frame"] == "bordas":
		_clear_decor_from_frame_band()

	for np in node_points:
		var cname: String = String(_th["clearing_boss"] if np[1] else _th["clearing_node"])
		var ct = _tex(cname, _dir) if cname != "" else null
		if ct != null:
			_clearings.append([ct, np[0]])

	# Redemoinhos de areia (só no deserto): poucos, longe das trilhas, animados em _process.
	var swirl_name: String = String(_th.get("swirls", ""))
	if swirl_name != "":
		_swirl_tex = _tex(swirl_name, _dir)
		if _swirl_tex != null:
			var n_swirls: int = clampi(int(_board_rect.size.x * _board_rect.size.y / (_tile * _tile) / 30.0), 3, 8)
			var tries := 0
			while _swirls.size() < n_swirls and tries < 80:
				tries += 1
				var sp := Vector2(
					rng.randf_range(_board_rect.position.x + _tile, _board_rect.end.x - _tile),
					rng.randf_range(_board_rect.position.y + _tile, _board_rect.end.y - _tile))
				if _distance_to_paths(sp, segments) < 0.9 * _tile or _distance_to_nodes(sp, node_points) < 1.3 * _tile:
					continue
				_swirls.append([sp, rng.randf() * TAU])
	set_process(not _swirls.is_empty())

	queue_redraw()

func _process(delta: float) -> void:
	_swirl_t += delta
	var f: int = int(_swirl_t * 6.0) % SWIRL_FRAMES
	if f != _swirl_frame:
		_swirl_frame = f
		queue_redraw()

# Centro do sprite de uma árvore cuja base do tronco está em `ground`.
# Deserto: a moldura de areia entra sobre as casas; sprites com base de areia
# (monólitos, torres...) ou detalhes miúdos que PISAM nessa faixa batiam com a
# areia da borda. Descarta a decoração cuja "pegada" (parte de baixo) toca a
# faixa; a parte alta de um sprite alto pode passar por cima, sem problema.
func _clear_decor_from_frame_band() -> void:
	var S := float(_scale)
	var inner := _board_rect
	inner.position += Vector2(FRAME_BAND_SIDE, FRAME_BAND_TOP) * S
	inner.size -= Vector2(FRAME_BAND_SIDE * 2.0, FRAME_BAND_TOP + FRAME_BAND_BOTTOM) * S
	var kept: Array = []
	var big_feet: Array[Rect2] = []   # pegadas dos sprites grandes já aceitos
	for d in _decor:
		var dtex: Texture2D = d[0]
		var dsz := dtex.get_size() * S
		var drect := Rect2(d[1] - dsz / 2.0, dsz)
		var foot := Rect2(drect.position.x, drect.end.y - dsz.y * 0.35, dsz.x, dsz.y * 0.35)
		if not inner.encloses(foot):
			continue
		# Sprites grandes (monólitos, torres, ruínas) trazem uma base de areia:
		# duas bases não podem se sobrepor.
		if dsz.x >= LARGE_DECOR_NATIVE * S:
			var clash := false
			for bf in big_feet:
				if bf.intersects(foot.grow(8.0 * S)):
					clash = true
					break
			if clash:
				continue
			big_feet.append(foot)
		kept.append(d)
	_decor = kept

func _tree_center(tex: Texture2D, ground: Vector2) -> Vector2:
	return _snap(ground + Vector2(0.0, (0.5 - float(_th["tree_ground_y"])) * tex.get_height() * float(_scale)))

# A árvore cabe? Copa inteira dentro do tabuleiro, longe das trilhas e dos nós
# e sem encostar demais em outra árvore.
func _tree_fits(tex: Texture2D, ground: Vector2, segments: Array, node_points: Array, others: Array[Vector2]) -> bool:
	var sz: Vector2 = tex.get_size() * float(_scale)
	var ctr: Vector2 = _tree_center(tex, ground)
	var rect := Rect2(ctr - sz / 2.0, sz)
	# A copa pode passar da borda (fica por cima da moldura), mas
	# a base do tronco precisa estar bem dentro do tabuleiro.
	if not _board_rect.grow(-0.3 * _tile).has_point(ground):
		return false
	for o in others:
		if o.distance_to(ground) < TREE_MIN_SPACING * _tile:
			return false
	# Pontos da copa e do tronco contra as trilhas.
	var probes: Array[Vector2] = [ground, ctr, ctr + Vector2(sz.x * 0.35, 0.0), ctr - Vector2(sz.x * 0.35, 0.0)]
	for pr in probes:
		if _distance_to_paths(pr, segments) < TREE_PATH_CLEAR * _tile:
			return false
	for np in node_points:
		var q := Vector2(clampf(np[0].x, rect.position.x, rect.end.x), clampf(np[0].y, rect.position.y, rect.end.y))
		if q.distance_to(np[0]) < TREE_NODE_CLEAR * _tile:
			return false
	return true

func _layout_seed(layers: Array) -> int:
	var s = ""
	for layer in layers:
		for node in layer:
			s += "%d,%d,%d;" % [int(node.position.x), int(node.position.y), int(node.type)]
	return hash(s)

func _jitter(rng: RandomNumberGenerator, amount: float) -> Vector2:
	return Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)) * _tile

func _snap(p: Vector2) -> Vector2:
	return (p / float(_scale)).round() * float(_scale)

func _distance_to_paths(p: Vector2, segments: Array) -> float:
	var best = INF
	for seg in segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var q = Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, p.distance_to(q))
	return best

func _distance_to_nodes(p: Vector2, node_points: Array) -> float:
	var best = INF
	for np in node_points:
		best = minf(best, p.distance_to(np[0]))
	return best

func _draw() -> void:
	if _board_rect.size == Vector2.ZERO:
		return

	for t in _tiles:
		var tex: Texture2D = t[0]
		var rect: Rect2 = t[1]
		var half = rect.size / 2.0
		draw_set_transform(rect.position + half, 0.0, Vector2(-1.0 if t[2] else 1.0, -1.0 if t[3] else 1.0))
		draw_texture_rect(tex, Rect2(-half, rect.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Deserto: a areia acumulada da moldura entra 14 px (nativos) sobre as casas,
	# então vai ANTES da decoração (nada do mapa pode ficar escondido por ela).
	if _th["frame"] == "bordas":
		_draw_frame_sheet()
	else:
		# Floresta: a moldura vai ANTES da decoração, então a copa das árvores
		# que passam da borda fica NA FRENTE dela (não por trás).
		_draw_frame()

	for c in _clearings:
		var ctex: Texture2D = c[0]
		var sz = ctex.get_size() * float(_scale)
		draw_texture_rect(ctex, Rect2(_snap(c[1]) - sz / 2.0, sz), false)

	for d in _decor:
		var dtex: Texture2D = d[0]
		var dsz = dtex.get_size() * float(_scale)
		var drect := Rect2(d[1] - dsz / 2.0, dsz)
		# Deserto: corta no limite do tabuleiro (a areia da moldura fica por cima das
		# casas). Floresta: a copa passa por cima da moldura e só é cortada no limite
		# externo do mapa.
		var clip_rect: Rect2 = _board_rect if _th["frame"] == "bordas" else world_rect
		if clip_rect.encloses(drect):
			draw_texture_rect(dtex, drect, false)
		else:
			var clip := drect.intersection(clip_rect)
			if clip.size.x > 0.0 and clip.size.y > 0.0:
				var k := 1.0 / float(_scale)
				draw_texture_rect_region(dtex, clip, Rect2((clip.position - drect.position) * k, clip.size * k))

	_draw_swirls()

# Redemoinhos: 4 quadros de 8x8 numa faixa; vagam devagar pelo tabuleiro.
func _draw_swirls() -> void:
	if _swirl_tex == null or _swirls.is_empty():
		return
	var S: float = float(_scale)
	var f: int = maxi(_swirl_frame, 0)
	var sz: Vector2 = Vector2(SWIRL_FRAME_PX, SWIRL_FRAME_PX) * S
	for sw in _swirls:
		var base: Vector2 = sw[0]
		var ph: float = sw[1]
		var p := base + Vector2(sin(_swirl_t * 0.35 + ph) * 0.5 * _tile, cos(_swirl_t * 0.27 + ph) * 0.2 * _tile)
		p = _snap(p)
		var rect := Rect2(p - sz / 2.0, sz)
		draw_texture_rect_region(_swirl_tex, rect, Rect2(float(f * SWIRL_FRAME_PX), 0, float(SWIRL_FRAME_PX), float(SWIRL_FRAME_PX)))

# Moldura do deserto: uma folha 13x12 casas (354x332) que se repete casa a casa,
# como a da floresta, mas com as bordas por cima das casas (areia acumulada).
# Medidas nativas: laterais 8 px fora do tabuleiro (peça de 22), topo 10 px
# (peça de 22 de altura), base 10 px (peça de 26 de altura; parede mais grossa).
const SHEET_COLS: int = 13
const SHEET_ROWS: int = 12
const SHEET_MARGIN_X: float = 8.0
const SHEET_MARGIN_Y: float = 10.0
const SHEET_SIDE_W: float = 22.0
const SHEET_TOP_H: float = 22.0
const SHEET_BOT_H: float = 26.0
# Quanto a moldura entra sobre as casas (px nativos, + 1 de folga): lados, topo, base.
const FRAME_BAND_SIDE: float = 15.0
const FRAME_BAND_TOP: float = 13.0
const FRAME_BAND_BOTTOM: float = 17.0
# Largura nativa a partir da qual um sprite conta como "grande" (tem base de areia).
const LARGE_DECOR_NATIVE: float = 11.0
func _draw_frame_sheet() -> void:
	if _frame_tex == null:
		return
	var S := float(_scale)
	var tw := float(NATIVE_TILE)
	var W := float(_frame_tex.get_width())
	var H := float(_frame_tex.get_height())
	var outer := world_rect
	var cols := int(round(_board_rect.size.x / _tile))
	var rows := int(round(_board_rect.size.y / _tile))
	for i in range(cols):
		var sx := SHEET_MARGIN_X + tw * float(i % SHEET_COLS)
		var dx := _board_rect.position.x + float(i) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(dx, outer.position.y, _tile, SHEET_TOP_H * S), Rect2(sx, 0, tw, SHEET_TOP_H))
		draw_texture_rect_region(_frame_tex, Rect2(dx, outer.end.y - SHEET_BOT_H * S, _tile, SHEET_BOT_H * S), Rect2(sx, H - SHEET_BOT_H, tw, SHEET_BOT_H))
	for j in range(rows):
		var sy := SHEET_MARGIN_Y + tw * float(j % SHEET_ROWS)
		var dy := _board_rect.position.y + float(j) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(outer.position.x, dy, SHEET_SIDE_W * S, _tile), Rect2(0, sy, SHEET_SIDE_W, tw))
		draw_texture_rect_region(_frame_tex, Rect2(outer.end.x - SHEET_SIDE_W * S, dy, SHEET_SIDE_W * S, _tile), Rect2(W - SHEET_SIDE_W, sy, SHEET_SIDE_W, tw))
	# Cantos
	draw_texture_rect_region(_frame_tex, Rect2(outer.position, Vector2(SHEET_SIDE_W, SHEET_TOP_H) * S), Rect2(0, 0, SHEET_SIDE_W, SHEET_TOP_H))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.end.x - SHEET_SIDE_W * S, outer.position.y), Vector2(SHEET_SIDE_W, SHEET_TOP_H) * S), Rect2(W - SHEET_SIDE_W, 0, SHEET_SIDE_W, SHEET_TOP_H))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.position.x, outer.end.y - SHEET_BOT_H * S), Vector2(SHEET_SIDE_W, SHEET_BOT_H) * S), Rect2(0, H - SHEET_BOT_H, SHEET_SIDE_W, SHEET_BOT_H))
	draw_texture_rect_region(_frame_tex, Rect2(outer.end - Vector2(SHEET_SIDE_W, SHEET_BOT_H) * S, Vector2(SHEET_SIDE_W, SHEET_BOT_H) * S), Rect2(W - SHEET_SIDE_W, H - SHEET_BOT_H, SHEET_SIDE_W, SHEET_BOT_H))

func _draw_frame() -> void:
	if _frame_tex == null:
		return
	var S = float(_scale)
	var fw = float(FRAME) * S
	var cols = int(round(_board_rect.size.x / _tile))
	var rows = int(round(_board_rect.size.y / _tile))
	var outer = world_rect
	var tw = float(NATIVE_TILE)
	var tex_w = float(_frame_tex.get_width())
	var tex_h = float(_frame_tex.get_height())

	for i in range(cols):
		var sx = float(FRAME) + tw * float(i % FRAME_SRC_COLS)
		var dx = _board_rect.position.x + float(i) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(dx, outer.position.y, _tile, fw), Rect2(sx, 0, tw, float(FRAME)))
		draw_texture_rect_region(_frame_tex, Rect2(dx, _board_rect.end.y, _tile, fw), Rect2(sx, tex_h - float(FRAME), tw, float(FRAME)))
	for j in range(rows):
		var sy = float(FRAME) + tw * float(j % FRAME_SRC_ROWS)
		var dy = _board_rect.position.y + float(j) * _tile
		draw_texture_rect_region(_frame_tex, Rect2(outer.position.x, dy, fw, _tile), Rect2(0, sy, float(FRAME), tw))
		draw_texture_rect_region(_frame_tex, Rect2(_board_rect.end.x, dy, fw, _tile), Rect2(tex_w - float(FRAME), sy, float(FRAME), tw))

	# Cantos (12x12 nativos, sobrepõem 2 px do tabuleiro).
	var cs = float(FRAME_CORNER)
	var cd = cs * S
	draw_texture_rect_region(_frame_tex, Rect2(outer.position, Vector2(cd, cd)), Rect2(0, 0, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.end.x - cd, outer.position.y), Vector2(cd, cd)), Rect2(tex_w - cs, 0, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(Vector2(outer.position.x, outer.end.y - cd), Vector2(cd, cd)), Rect2(0, tex_h - cs, cs, cs))
	draw_texture_rect_region(_frame_tex, Rect2(outer.end - Vector2(cd, cd), Vector2(cd, cd)), Rect2(tex_w - cs, tex_h - cs, cs, cs))
