class_name MapTide
extends Node2D
# MARÉ DE LAVA da Caldeira no mapa. Uma fileira inteira do miolo fica num vale; quando
# a peça está a TIDE_LEAD passos dela, a lava entra por um dos lados (por baixo da
# moldura) e engole um nodo por passo. A lava em si é desenhada pelo fundo do mapa
# (ForestBackground.set_tide_cells, com as peças animadas dos lagos); aqui ficam:
#  - a frente da maré (a crosta empurrando), na coluna logo depois da lava;
#  - as ilhas de basalto embaixo dos nodos engolidos que ficam de pé;
#  - a marca de alvo no próximo nodo que a lava vai pegar;
#  - (no nó `over`, acima das trilhas) os nodos afundando / afundados.

const DIR := "res://assets/sprites/biomas/caldeira/tabuleiro/mare/"
const ALVO_DIR := "res://assets/sprites/biomas/caldeira/tabuleiro/erupcao/"
const HALF_ROWS: int = 1             # a maré ocupa a linha dos nodos e 1 casa acima/abaixo
const COL_STEP_TIME: float = 0.09    # tempo da frente andar uma coluna

signal node_sinking(index: int)    # o nodo começou a afundar (o MapView esconde o soquete)

var forest: ForestBackground = null
var over: Node2D = null
var px: float = 3.0
var tile: float = 78.0

var _row: int = 0
var _dir: int = 1
var _min_col: int = 0
var _max_col: int = 0
var _pts: Array = []                 # posição de cada nodo, na ordem da maré
var _state: Array = []               # por nodo: "" | "ilha" | "afundando" | "afundado"
var _sink_t0: Array = []
var _front_col: float = -999.0       # última coluna coberta (na direção da maré); -999 = sem lava
var _shown_col: int = -9999
var _next: int = -1                  # nodo marcado como próximo alvo
var _t: float = 0.0
var _lava: Dictionary = {}           # casas cobertas agora
var _bridges: Array = []             # [Vector2i casa, String peça] das trilhas que cruzam o vale

static var _cache: Dictionary = {}
static var _badge_tex: ImageTexture = null
var _duel: Array = []                # o nodo i é duelo? (só duelo ganha o selo de ilha)
var _badges: Array = []              # Sprite2D por nodo (null se não é duelo)

# Selo 11x11 (como os do glaciar, da ponte e da tempestade) a partir de linhas de texto.
static func make_badge(rows: Array, pal: Dictionary) -> ImageTexture:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(11):
		for x in range(11):
			var ch: String = String(rows[y])[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)

# Selo do duelo na ilha: ilhota de basalto no meio da lava.
static func _badge_texture() -> ImageTexture:
	if _badge_tex == null:
		_badge_tex = make_badge([
			"...#####...",
			"..#ooooo#..",
			".#oyoooyo#.",
			"#ooo###ooo#",
			"#oo#ggg#oo#",
			"#o#gGGgg#o#",
			"#oo#ggg#oo#",
			"#ooo###ooo#",
			".#oyoooyo#.",
			"..#ooooo#..",
			"...#####...",
		], {"#": Color("#31252f"), "o": Color("#f0662a"), "y": Color("#ffe08a"), "g": Color("#5a4855"), "G": Color("#8a7a88")})
	return _badge_tex

const _CHEVRON: Array = [
	"OH...",
	"OHH..",
	".OHH.",
	"..OHH",
	".OHH.",
	"OHH..",
	"OH...",
]

static func _frames(dir: String, base: String, n: int) -> Array:
	var key := dir + base + str(n)
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	for i in range(1, n + 1):
		var p: String = dir + base + "_f%d.png" % i
		if ResourceLoader.exists(p):
			out.append(load(p))
	_cache[key] = out
	return out

static func _single(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

func setup(p_forest: ForestBackground, row: int, dir: int, node_points: Array, min_col: int, max_col: int, tile_px: float, sprite_scale: float, duel_flags: Array = []) -> void:
	forest = p_forest
	_row = row
	_dir = dir
	_pts = node_points
	_min_col = min_col
	_max_col = max_col
	tile = tile_px
	px = sprite_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var holder := Node2D.new()
	holder.z_index = 15
	add_child(holder)
	for i in range(_pts.size()):
		_state.append("")
		_sink_t0.append(-99.0)
		_duel.append(i < duel_flags.size() and bool(duel_flags[i]))
		var b: Sprite2D = null
		if _duel[i]:
			b = Sprite2D.new()
			b.texture = _badge_texture()
			b.scale = Vector2(px, px)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.visible = false
			holder.add_child(b)
		_badges.append(b)
	if over != null:
		over.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		over.draw.connect(_draw_over)

# Retângulo (mundo) do vale inteiro: o fundo não põe lagos nem marcos ali.
static func band_rect(row: int, min_col: int, max_col: int, tile_px: float) -> Rect2:
	return Rect2(Vector2((min_col - 0.5) * tile_px, (row - HALF_ROWS - 1.5) * tile_px), Vector2((max_col - min_col + 1) * tile_px, (HALF_ROWS * 2 + 3) * tile_px))

# Coluna (na direção da maré) até onde a lava chega com `k` nodos engolidos.
# k = 0: a lava acabou de entrar (só a primeira coluna); depois para no meio do caminho
# entre o último nodo engolido e o próximo; com todos engolidos, cobre a fileira toda.
func _col_for(k: int) -> float:
	if k < 0:
		return -999.0
	var edge: int = _min_col if _dir > 0 else _max_col
	if k == 0:
		return float(edge)
	if k >= _pts.size():
		return float(_max_col if _dir > 0 else _min_col)
	var a: float = (_pts[k - 1] as Vector2).x / tile
	var b: float = (_pts[k] as Vector2).x / tile
	return floorf((a + b) * 0.5) if _dir > 0 else ceilf((a + b) * 0.5)

func _apply_cells(col: int) -> void:
	if col == _shown_col:
		return
	_shown_col = col
	var cells: Dictionary = {}
	var clear: Array = []
	_lava = cells
	if col > -999:
		# uma coluna a mais por fora: a lava vem de baixo da moldura
		var c0: int = (_min_col - 1) if _dir > 0 else col
		var c1: int = col if _dir > 0 else (_max_col + 1)
		for c in range(c0, c1 + 1):
			var r0: int = _row - HALF_ROWS - (1 if _bulge(c, 1) else 0)
			var r1: int = _row + HALF_ROWS + (1 if _bulge(c, 2) else 0)
			for r in range(r0, r1 + 1):
				cells[Vector2i(c, r)] = true
				clear.append(Rect2(Vector2((c - 0.5) * tile, (r - 0.5) * tile), Vector2(tile, tile)).grow(-tile * 0.15))
	if forest != null:
		forest.set_tide_cells(cells)
		if not clear.is_empty():
			forest.clear_decor_in(clear)

# Margem irregular: em algumas colunas o rio avança uma casa a mais para cima/baixo
# (nunca nas colunas dos nodos nem nas vizinhas das pontas, para não comer trilha).
func _bulge(c: int, salt: int) -> bool:
	if c <= _min_col or c >= _max_col:
		return false
	for p in _pts:
		if absi(int(round((p as Vector2).x / tile)) - c) <= 1:
			return false
	return absi(hash(Vector3i(c, _row, salt))) % 100 < 45

# Trilhas (lista de centros de casa, como ForestTrail.cell_points) que cruzam o vale:
# onde a lava cobrir, a trilha vira passarela de basalto em pilares (a peça atravessa
# por cima da ponte, não da lava). As casas dos nodos ficam de fora (têm a ilha).
func set_trails(trails: Array) -> void:
	_bridges.clear()
	var node_cells: Dictionary = {}
	for p in _pts:
		node_cells[Vector2i(((p as Vector2) / tile).round())] = true
	var seen: Dictionary = {}
	for pts in trails:
		for i in range(1, (pts as Array).size() - 1):
			var c := Vector2i(((pts[i] as Vector2) / tile).round())
			if node_cells.has(c) or seen.has(c) or absi(c.y - _row) > HALF_ROWS + 1:
				continue
			var din := Vector2i(((pts[i] as Vector2) - (pts[i - 1] as Vector2)) / tile).clamp(Vector2i(-1, -1), Vector2i(1, 1))
			var dout := Vector2i(((pts[i + 1] as Vector2) - (pts[i] as Vector2)) / tile).clamp(Vector2i(-1, -1), Vector2i(1, 1))
			var diag: Vector2i = din if din.x != 0 else dout
			var piece: String = "N_S"
			if diag.x != 0:
				piece = "NE_SW" if diag.x * diag.y < 0 else "SE_NW"
			seen[c] = true
			_bridges.append([c, piece])

# Estado sem animação (ao abrir o mapa).
func set_progress(k: int, states: Array) -> void:
	for i in range(mini(states.size(), _state.size())):
		_state[i] = "afundado" if states[i] == "afundando" else states[i]
	_front_col = _col_for(k)
	_apply_cells(int(_front_col))

func set_next(i: int) -> void:
	_next = i

# A lava avança de k_from até k_to; os nodos novos viram ilha ou afundam (states).
func advance(k_to: int, states: Array) -> void:
	var target: float = _col_for(k_to)
	# só toca se o trecho por onde a lava vai andar estiver na tela
	var c_from: float = _front_col if _front_col > -999.0 else _col_for(0)
	var seg := Rect2(Vector2(minf(c_from, target) - 0.5, _row - HALF_ROWS - 0.5) * tile, Vector2(absf(target - c_from) + 1.0, HALF_ROWS * 2 + 1) * tile)
	if MapEruption.on_screen(self, seg):
		Sfx.play("lava_mare")
	if _front_col <= -999.0:
		_front_col = _col_for(0) - float(_dir)
	while (target - _front_col) * float(_dir) > 0.01:
		_front_col += float(_dir)
		_apply_cells(int(_front_col))
		# nodo alcançado nesta coluna
		for i in range(_pts.size()):
			var nc: float = round((_pts[i] as Vector2).x / tile)
			if _state[i] == "" and states[i] != "" and (_front_col - nc) * float(_dir) >= -0.01:
				_state[i] = states[i]
				_node_sound(states[i], i)
				if states[i] == "afundando":
					_sink_t0[i] = _t
					node_sinking.emit(i)
		await get_tree().create_timer(COL_STEP_TIME).timeout
	for i in range(_pts.size()):
		if _state[i] == "" and states[i] != "":
			_state[i] = states[i]
			_node_sound(states[i], i)
			if states[i] == "afundando":
				_sink_t0[i] = _t
				node_sinking.emit(i)
	await get_tree().create_timer(0.55).timeout

func _node_sound(st: String, i: int = -1) -> void:
	if i >= 0 and not MapEruption.on_screen(self, Rect2((_pts[i] as Vector2) - Vector2(tile, tile) * 0.5, Vector2(tile, tile))):
		return
	if st == "afundando":
		Sfx.play("lava_afunda")
	elif st == "ilha":
		Sfx.play("lava_ilha")

func _process(delta: float) -> void:
	_t += delta
	for i in range(_badges.size()):
		var b: Sprite2D = _badges[i]
		if b != null:
			b.visible = _state[i] == "ilha"
			b.position = (_pts[i] as Vector2) + Vector2(30.0, -30.0 + roundf(sin(_t * 2.4 + float(i))) * px)
	queue_redraw()
	if over != null:
		over.queue_redraw()

func _draw() -> void:
	if _front_col <= -999.0:
		return
	# frente da maré: na coluna logo depois da última coberta (espelhada se vem da direita)
	var fr: Array = _frames(DIR, "frente", 4)
	var fc: int = int(_front_col) + _dir
	if not fr.is_empty() and fc >= _min_col and fc <= _max_col:
		var ft: Texture2D = fr[int(_t * 6.0) % fr.size()]
		for r in range(_row - HALF_ROWS, _row + HALF_ROWS + 1):
			var ctr := Vector2(fc * tile, r * tile)
			var sz := Vector2(tile, tile)
			draw_set_transform(ctr, 0.0, Vector2(1.0 if _dir > 0 else -1.0, 1.0))
			draw_texture_rect(ft, Rect2(-sz * 0.5, sz), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# aviso de MARÉ: setas de lava no chão, da frente até o próximo nodo, andando
	if _next >= 0 and _next < _pts.size() and _state[_next] == "":
		var nc: int = int(round((_pts[_next] as Vector2).x / tile))
		var c: int = fc
		var idx: int = 0
		while (nc - c) * _dir >= 0 and idx < 40:
			for r in [_row - 1, _row + 1]:
				var glow: float = 0.45 + 0.55 * maxf(0.0, sin(_t * 5.0 - float(idx) * 1.1))
				var ctr := Vector2(c * tile, r * tile)
				_draw_chevron(ctr, glow)
			c += _dir
			idx += 1
	# passarelas: pilares de basalto sob a trilha onde ela passa pela lava (a trilha em
	# si é desenhada por cima, então o estado dela continua aparecendo)
	for br in _bridges:
		var bc: Vector2i = br[0]
		if not _lava.has(bc):
			continue
		var bt: Texture2D = _single(DIR + "passarela_%s.png" % br[1])
		if bt != null:
			var bsz: Vector2 = bt.get_size() * px
			draw_texture_rect(bt, Rect2((Vector2(bc) * tile - bsz * 0.5).round(), bsz), false)
	# ilhas embaixo dos nodos de pé
	var ilha: Array = _frames(DIR, "ilha", 4)
	for i in range(_pts.size()):
		if _state[i] == "ilha" and not ilha.is_empty():
			var it: Texture2D = ilha[int(_t * 5.0 + float(i)) % ilha.size()]
			var isz: Vector2 = it.get_size() * px
			draw_texture_rect(it, Rect2(((_pts[i] as Vector2) - isz * 0.5).round(), isz), false)

func _draw_chevron(ctr: Vector2, glow: float) -> void:
	var w: int = 5
	var h: int = _CHEVRON.size()
	var o: Vector2 = (ctr - Vector2(w, h) * px * 0.5).round()
	for y in range(h):
		var row: String = _CHEVRON[y]
		for x in range(w):
			var ch: String = row[x]
			if ch == ".":
				continue
			var xx: int = x if _dir > 0 else (w - 1 - x)
			var col: Color = Color("#7a2420") if ch == "O" else Color("#ffa53a").lerp(Color("#ffe08a"), glow * 0.6)
			draw_rect(Rect2(o + Vector2(xx, y) * px, Vector2(px, px)), Color(col, 0.35 + 0.6 * glow))

func _draw_over() -> void:
	var sink: Array = _frames(DIR, "afundando", 6)
	# (guardada no cache: uma textura carregada só aqui seria liberada antes de desenhar)
	if not _cache.has("afundado"):
		_cache["afundado"] = load(DIR + "afundado.png") if ResourceLoader.exists(DIR + "afundado.png") else null
	var sunk: Texture2D = _cache["afundado"]
	for i in range(_pts.size()):
		var tex: Texture2D = null
		if _state[i] == "afundando":
			var f: int = int((_t - float(_sink_t0[i])) * 8.0)
			if f < sink.size():
				tex = sink[f]
			else:
				_state[i] = "afundado"
				tex = sunk
		elif _state[i] == "afundado":
			tex = sunk
		if tex != null:
			var sz: Vector2 = tex.get_size() * px
			over.draw_texture_rect(tex, Rect2(((_pts[i] as Vector2) - sz * 0.5).round(), sz), false)
	# próximo nodo que a lava pega: anel de lava (borbulhando) em volta do soquete —
	# diferente da mira vermelha das bolas de fogo do vulcão
	if _next >= 0 and _next < _pts.size() and _state[_next] == "" and _front_col > -999.0:
		var c0: Vector2 = _pts[_next]
		var rad: float = 23.0 * px
		var steps: int = int(TAU * rad / px)
		for k in range(steps):
			var a: float = TAU * float(k) / float(steps)
			var wob: float = roundf(sin(a * 9.0 + _t * 4.0) * 1.2) * px
			var p: Vector2 = (c0 + Vector2(cos(a), sin(a)) * (rad + wob) - Vector2(px, px) * 0.5).round()
			var hot: bool = (k + int(_t * 10.0)) % 7 == 0
			over.draw_rect(Rect2(p, Vector2(px, px) * 2.0), Color("#7a2420"))
			over.draw_rect(Rect2(p, Vector2(px, px)), Color("#ffe08a") if hot else Color("#f0662a"))
