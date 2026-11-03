class_name TutorialTrail
extends Node2D

# Trilha do mapa do tutorial (estilo "plástico", casa a casa). Cada peça de
# res://assets/sprites/tutorial/trilha_mapa/ ocupa UMA casa do tabuleiro
# (32 px nativos + 4 px de sobra de cada lado pra emendar) e vem em duas
# cores: "clara" nas casas claras e "escura" nas casas escuras (tom sobre tom).
#
# O caminho entre dois nós é uma sequência de movimentos "pra cima" — reto (V),
# diagonal pra direita (D+) ou pra esquerda (D-) —, com os retos nas pontas e
# as diagonais no meio. A peça de cada casa depende de por onde o caminho
# entra e sai dela (reto, diagonal ou curva).

const DIR := "res://assets/sprites/tutorial/trilha_mapa/"
const NATIVE_TILE: float = 32.0

static var _tex_cache: Dictionary = {}

var _sprites: Array[Sprite2D] = []

static func _tex(name: String, on_light_square: bool) -> Texture2D:
	var file = "trilha_%s_%s" % [name, "clara" if on_light_square else "escura"]
	if not _tex_cache.has(file):
		var path = DIR + file + ".png"
		_tex_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[file]

# Peça de uma casa a partir de como o caminho entra (in_m) e sai (out_m).
static func piece_name(in_m: String, out_m: String, variant: int) -> String:
	match [in_m, out_m]:
		["V", "V"]:
			return ["vertical", "vertical_v2", "vertical_v3"][variant % 3]
		["V", "D+"]:
			return "curva_s_ne"
		["V", "D-"]:
			return "curva_s_nw"
		["D+", "D+"]:
			return ["diagonal_dir", "diagonal_dir_v2"][variant % 2]
		["D-", "D-"]:
			return ["diagonal_esq", "diagonal_esq_v2"][variant % 2]
		["D+", "V"]:
			return "curva_n_sw"
		["D-", "V"]:
			return "curva_n_se"
	# Zigue-zague de diagonais (D+ <-> D-) não tem peça: nunca é gerado.
	return "vertical"

# Movimentos de `from_g` até `to_g` (casas = Vector2i(coluna, linha)): retos na
# subida, diagonais no meio. Só sobe (linha menor).
static func build_moves(from_g: Vector2i, to_g: Vector2i) -> Array[String]:
	var moves: Array[String] = []
	var rows = from_g.y - to_g.y
	var dx = to_g.x - from_g.x
	var n_d = mini(absi(dx), rows)
	var n_v = rows - n_d
	var diag = "D+" if dx > 0 else "D-"
	for i in range(n_v / 2):
		moves.append("V")
	for i in range(n_d):
		moves.append(diag)
	for i in range(n_v - n_v / 2):
		moves.append("V")
	return moves

func setup(from_g: Vector2i, to_g: Vector2i, tile_size: float) -> void:
	var moves = build_moves(from_g, to_g)
	var s = tile_size / NATIVE_TILE
	var g = from_g
	for k in range(moves.size()):
		var in_m = "V" if k == 0 else moves[k - 1]
		var out_m = moves[k]
		# As casas dos nós (primeira e última) ficam sob o soquete: sem peça.
		if k > 0:
			_add_piece(g, in_m, out_m, k, tile_size, s)
		g += _step(out_m)
	set_state("normal")

func _add_piece(g: Vector2i, in_m: String, out_m: String, k: int, tile_size: float, s: float) -> void:
	var light = ((g.x + g.y) % 2 + 2) % 2 == 0
	var tex = _tex(piece_name(in_m, out_m, (g.x * 3 + g.y * 7 + k) & 0x7fffffff), light)
	if tex == null:
		return
	var sp = Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale = Vector2(s, s)
	sp.position = Vector2(g.x * tile_size, g.y * tile_size)
	add_child(sp)
	_sprites.append(sp)

static func _step(m: String) -> Vector2i:
	match m:
		"D+":
			return Vector2i(1, -1)
		"D-":
			return Vector2i(-1, -1)
	return Vector2i(0, -1)

# Sem pintar a trilha: só esmaece o que ainda não foi liberado. "percorrido" e
# "selecionado" ficam com a cor original da arte.
func set_state(new_state: String) -> void:
	var tint = Color(1, 1, 1, 0.45) if new_state == "normal" else Color(1, 1, 1, 1)
	for sp in _sprites:
		sp.modulate = tint
