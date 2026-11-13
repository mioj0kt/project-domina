class_name SpaceBackground
extends CanvasLayer

# Fundo de "universo": céu ameixa bem escuro, nebulosas em blocos (pixel art),
# estrelas que cintilam em 3 camadas com deriva lenta e uma estrela cadente de
# tempos em tempos. Tudo procedural (nenhum asset), na paleta do jogo.
# Uso: add_child(SpaceBackground.new()) em qualquer cena — fica atrás de tudo.

const NEBULA_SIZE := Vector2i(192, 108)   # textura baixa, ampliada sem filtro
const SKY_TOP := Color("#14101a")
const SKY_BOTTOM := Color("#2a1f33")
const STAR_COLORS: Array[Color] = [
	Color("#efe6cf"), Color("#efe6cf"), Color("#efe6cf"), Color("#cfc3a6"),
	Color("#d9a441"), Color("#7c6489"), Color("#3f7f9a"),
]

# {frac_y: 0..1 de profundidade, count, size(px nativos), speed(px/s), alpha}
const LAYERS: Array[Dictionary] = [
	{"count": 170, "size": 2.0, "speed": 3.0, "alpha": 0.6},
	{"count": 80, "size": 3.0, "speed": 7.0, "alpha": 0.85},
	{"count": 26, "size": 4.0, "speed": 14.0, "alpha": 1.0},
]

static var _island_cache: Dictionary = {}   # caminho -> Texture2D

# Ilhas-tabuleiro flutuantes (sprites em assets/sprites/menu/ilhas); escala de pixel
# e brilho por profundidade (longe = menor, mais escuro e mais lento).
# ilha_<grupo>_1..5.png. "menu" (as do tutorial) aparecem sempre; as de cada
# bioma só depois que o jogador visitou aquele bioma pelo menos uma vez.
const ISLAND_PATTERN := "res://assets/sprites/menu/ilhas/ilha_%s_%d.png"
const ISLAND_GROUPS: Array[String] = ["menu", "floresta", "deserto", "mina"]
const ISLAND_VARIANTS: int = 5
const ISLAND_DEPTHS: Array[Dictionary] = [
	{"scale": 0.5, "tint": 0.55, "speed": 4.0, "bob": 4.0},
	{"scale": 0.7, "tint": 0.75, "speed": 8.0, "bob": 6.0},
	{"scale": 0.95, "tint": 0.95, "speed": 13.0, "bob": 8.0},
]
const PIECE_PATHS: Array[String] = [
	"res://assets/sprites/pieces/white.png", "res://assets/sprites/pieces/black.png",
	"res://assets/sprites/pieces/white-king.png", "res://assets/sprites/pieces/black-king.png",
]

var _stars: Array[Dictionary] = []   # {layer, x, y, color, phase, rate, cross}
var _canvas: Node2D
var _t: float = 0.0
# Transparência das ilhas/peças (menor = mais discretas; usado nos mapas, onde há texto por cima).
var floater_alpha: float = 1.0
# Bioma do mapa ("floresta", "deserto", "mina"; vazio = roxo padrão do menu/
# tutorial). Troca o céu, as nebulosas e as estrelas. A mina não tem ilhas
# voando (é uma caverna). Defina ANTES de add_child().
var biome: String = ""
# sky_top, sky_bottom, nebulosa A (3 níveis), nebulosa B (3 níveis), estrelas
const BIOME_SKY: Dictionary = {
	"floresta": {
		"top": Color("#0f1a16"), "bottom": Color("#18281f"),
		"a": [Color(0.28, 0.58, 0.36, 0.05), Color(0.30, 0.62, 0.38, 0.09), Color(0.40, 0.72, 0.46, 0.14)],
		"b": [Color(0.60, 0.62, 0.25, 0.03), Color(0.65, 0.66, 0.28, 0.06), Color(0.72, 0.72, 0.34, 0.09)],
		"stars": [Color("#efe6cf"), Color("#efe6cf"), Color("#cfe0b0"), Color("#d9a441"), Color("#7fa874"), Color("#a9c98f")],
	},
	"deserto": {
		"top": Color("#1f1610"), "bottom": Color("#36261a"),
		"a": [Color(0.80, 0.56, 0.26, 0.05), Color(0.82, 0.58, 0.27, 0.09), Color(0.90, 0.66, 0.32, 0.13)],
		"b": [Color(0.72, 0.34, 0.24, 0.03), Color(0.75, 0.37, 0.25, 0.06), Color(0.82, 0.44, 0.30, 0.09)],
		"stars": [Color("#f2e3b0"), Color("#f2e3b0"), Color("#e3c98a"), Color("#d98f4a"), Color("#efe6cf"), Color("#c9a45e")],
	},
	"mina": {
		"top": Color("#0d1c22"), "bottom": Color("#12272b"),
		"a": [Color(0.20, 0.55, 0.55, 0.05), Color(0.22, 0.60, 0.58, 0.09), Color(0.30, 0.70, 0.66, 0.13)],
		"b": [Color(0.40, 0.65, 0.80, 0.03), Color(0.42, 0.70, 0.85, 0.06), Color(0.50, 0.78, 0.90, 0.09)],
		"stars": [Color("#efe6cf"), Color("#a9dcef"), Color("#7fd1c0"), Color("#6fb6d8"), Color("#cfeee6")],
	},
}
static var _nebula_cache: Dictionary = {}
# Mapa da Mina: dentro de uma gruta o céu vira um brilho de cristais (0..1, suavizado).
var cave_glow: float = 0.0
var _cave_t: float = 0.0
var _cave_fx: Node2D
var _cave_sparks: Array[Dictionary] = []   # {x, y, speed, size, color, phase, rate}
var _cave_blobs: Array[Dictionary] = []    # {x, y, r, color, phase, ax, ay}
var _cave_shards: Array[Dictionary] = []   # {x, y, size, color, phase, spin}
static var _blob_tex: ImageTexture = null
const CAVE_COLORS: Array[Color] = [
	Color(0.62, 0.45, 0.95), Color(0.66, 0.88, 1.0), Color(0.35, 0.85, 0.65), Color(0.85, 0.6, 1.0),
]
var _shoot_timer: float = 6.0
var _shoot: Dictionary = {}          # {pos, dir, life}
var _floaters: Array[Dictionary] = []   # ilhas e peças: {node, x, y, vx, vy, phase, bob, flip}

func _init() -> void:
	layer = -100
	follow_viewport_enabled = false

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 90210

	# 1. Céu em degradê (2 ColorRects não precisam de textura: usa shader-free
	# gradiente por GradientTexture2D).
	var grad = Gradient.new()
	grad.set_color(0, BIOME_SKY[biome]["top"] if BIOME_SKY.has(biome) else SKY_TOP)
	grad.set_color(1, BIOME_SKY[biome]["bottom"] if BIOME_SKY.has(biome) else SKY_BOTTOM)
	var gtex = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 4
	gtex.height = 256
	var sky = TextureRect.new()
	sky.texture = gtex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	# 2. Nebulosas em blocos.
	var neb = TextureRect.new()
	neb.texture = _get_nebula(biome)
	neb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	neb.stretch_mode = TextureRect.STRETCH_SCALE
	neb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	neb.set_anchors_preset(Control.PRESET_FULL_RECT)
	neb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(neb)

	# 3. Estrelas.
	var star_cols: Array = BIOME_SKY[biome]["stars"] if BIOME_SKY.has(biome) else STAR_COLORS
	for li in range(LAYERS.size()):
		for i in range(int(LAYERS[li]["count"])):
			_stars.append({
				"layer": li,
				"x": rng.randf(),
				"y": rng.randf(),
				"color": star_cols[rng.randi() % star_cols.size()],
				"phase": rng.randf() * TAU,
				"rate": rng.randf_range(0.6, 2.4),
				"cross": li == 2 and rng.randf() < 0.45,
			})
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_stars)
	add_child(_canvas)

	# 3b. Brilho de cristais (só aparece quando cave_glow > 0, na Mina).
	if biome == "mina":
		_build_cave_fx(rng)

	# 4. Ilhas-tabuleiro e peças voando (da mais longe para a mais perto).
	if biome != "mina":
		_build_floaters(rng)

func _process(delta: float) -> void:
	_t += delta
	_shoot_timer -= delta
	if _shoot.is_empty() and _shoot_timer <= 0.0:
		var vp = get_viewport().get_visible_rect().size
		var dir = Vector2(-1.0, 0.45).normalized()
		_shoot = {
			"pos": Vector2(randf_range(vp.x * 0.45, vp.x * 1.0), randf_range(0.0, vp.y * 0.35)),
			"dir": dir, "life": 0.0,
		}
		_shoot_timer = randf_range(9.0, 16.0)
	if not _shoot.is_empty():
		_shoot["life"] += delta
		_shoot["pos"] += _shoot["dir"] * 900.0 * delta
		if _shoot["life"] > 0.7:
			_shoot = {}
	_canvas.queue_redraw()
	if _cave_fx != null:
		_cave_t = lerpf(_cave_t, cave_glow, minf(1.0, delta * 3.0))
		_cave_fx.visible = _cave_t > 0.01
		# dentro da gruta o próprio céu é tingido pela cor da vez (roxo -> azul -> verde)
		var tint: Color = Color.WHITE.lerp(_cave_cycle(0.0).lightened(0.25), 0.85 * _cave_t)
		_canvas.modulate = Color(tint.r, tint.g, tint.b, 1.0 - 0.2 * _cave_t)
		if _cave_fx.visible:
			_cave_fx.queue_redraw()
	_update_floaters(delta)

func _build_cave_fx(rng: RandomNumberGenerator) -> void:
	if _blob_tex == null:
		var n: int = 64
		var bi := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in range(n):
			for x in range(n):
				var d: float = Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				var a: float = clampf(1.0 - d, 0.0, 1.0)
				bi.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		_blob_tex = ImageTexture.create_from_image(bi)
	_cave_fx = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cave_fx.material = mat
	_cave_fx.visible = false
	_cave_fx.draw.connect(_draw_cave)
	add_child(_cave_fx)
	for i in range(8):
		_cave_blobs.append({
			"x": rng.randf(), "y": rng.randf(), "r": rng.randf_range(0.22, 0.45),
			"color": CAVE_COLORS[i % CAVE_COLORS.size()], "phase": rng.randf() * TAU,
			"ax": rng.randf_range(0.03, 0.09), "ay": rng.randf_range(0.03, 0.09),
		})
	for i in range(90):
		_cave_sparks.append({
			"x": rng.randf(), "y": rng.randf(), "speed": rng.randf_range(0.01, 0.045),
			"size": float(rng.randi_range(1, 3)), "color": CAVE_COLORS[rng.randi() % CAVE_COLORS.size()].lerp(Color.WHITE, rng.randf_range(0.0, 0.5)),
			"phase": rng.randf() * TAU, "rate": rng.randf_range(1.2, 3.6),
		})
	for i in range(14):
		_cave_shards.append({
			"x": rng.randf(), "y": rng.randf(), "size": rng.randf_range(0.015, 0.05),
			"color": CAVE_COLORS[rng.randi() % CAVE_COLORS.size()], "phase": rng.randf() * TAU,
			"spin": rng.randf_range(-0.25, 0.25),
		})

# Cores dos cristais (violeta, gelo, esmeralda) alternando devagar; `offset` (0..1) defasa o ciclo.
const CAVE_CYCLE: Array = [Color(0.55, 0.22, 0.95), Color(0.16, 0.42, 1.0), Color(0.12, 0.80, 0.36)]   # roxo, azul, verde
const CAVE_CYCLE_SECS: float = 6.0   # tempo em cada cor

func _cave_cycle(ofs: float) -> Color:
	var n: int = CAVE_CYCLE.size()
	var f: float = fposmod(_t / CAVE_CYCLE_SECS + ofs * float(n), float(n))
	var i: int = int(f)
	var k: float = f - float(i)
	k = k * k * (3.0 - 2.0 * k)
	var a: Color = CAVE_CYCLE[i]
	var b: Color = CAVE_CYCLE[(i + 1) % n]
	return a.lerp(b, k)

func _draw_cave() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var u: float = _unit(vp)
	var g: float = _cave_t
	# Banho de cor dos cristais.
	var wash: Color = _cave_cycle(0.0)
	wash.a = 0.5 * g
	_cave_fx.draw_rect(Rect2(Vector2.ZERO, vp), wash)
	# Manchas de luz macias que derivam devagar.
	for b in _cave_blobs:
		var bx: float = (float(b["x"]) + float(b["ax"]) * sin(_t * 0.15 + float(b["phase"]))) * vp.x
		var by: float = (float(b["y"]) + float(b["ay"]) * cos(_t * 0.12 + float(b["phase"]))) * vp.y
		var rr: float = float(b["r"]) * vp.x
		var col: Color = _cave_cycle(float(b["phase"]) / TAU * 0.5).lightened(0.15)
		col.a = (0.26 + 0.08 * sin(_t * 0.7 + float(b["phase"]))) * g
		_cave_fx.draw_texture_rect(_blob_tex, Rect2(Vector2(bx - rr, by - rr), Vector2(rr * 2.0, rr * 2.0)), false, col)
	# Cacos de cristal (losangos) girando devagar.
	for sh in _cave_shards:
		var cx: float = float(sh["x"]) * vp.x
		var cy: float = float(sh["y"]) * vp.y + 14.0 * sin(_t * 0.5 + float(sh["phase"]))
		var sz: float = float(sh["size"]) * vp.y
		var wv: float = absf(cos(_t * float(sh["spin"]) + float(sh["phase"])))
		var col2: Color = sh["color"]
		col2.a = (0.16 + 0.12 * sin(_t * 1.3 + float(sh["phase"]))) * g
		var pts := PackedVector2Array([
			Vector2(cx, cy - sz), Vector2(cx + sz * 0.55 * wv, cy), Vector2(cx, cy + sz), Vector2(cx - sz * 0.55 * wv, cy),
		])
		_cave_fx.draw_colored_polygon(pts, col2)
	# Faíscas em cruz que sobem e piscam.
	for sp in _cave_sparks:
		var sx: float = float(sp["x"]) * vp.x
		var sy: float = fposmod(float(sp["y"]) - _t * float(sp["speed"]), 1.0) * vp.y
		var tw: float = 0.5 + 0.5 * sin(_t * float(sp["rate"]) + float(sp["phase"]))
		tw = floor(tw * 3.0) / 3.0
		var col3: Color = sp["color"]
		col3.a = (0.25 + 0.75 * tw) * g
		var sz2: float = float(sp["size"]) * u * 0.5
		var p := Vector2(floor(sx), floor(sy))
		_cave_fx.draw_rect(Rect2(p, Vector2(sz2, sz2)), col3)
		if tw > 0.6:
			var arm: float = sz2 * 2.0
			col3.a *= 0.6
			_cave_fx.draw_rect(Rect2(p + Vector2(-arm, 0), Vector2(arm, sz2)), col3)
			_cave_fx.draw_rect(Rect2(p + Vector2(sz2, 0), Vector2(arm, sz2)), col3)
			_cave_fx.draw_rect(Rect2(p + Vector2(0, -arm), Vector2(sz2, arm)), col3)
			_cave_fx.draw_rect(Rect2(p + Vector2(0, sz2), Vector2(sz2, arm)), col3)

func _unit(vp: Vector2) -> float:
	# Tamanho de "pixel" das estrelas: inteiro, cresce com a resolução.
	return maxf(2.0, round(vp.y / 540.0) * 2.0)

func _draw_stars() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var u: float = _unit(vp)
	for s in _stars:
		var L: Dictionary = LAYERS[s["layer"]]
		var sz: float = float(L["size"]) * u * 0.5
		var drift: float = _t * float(L["speed"])
		var x: float = fposmod(s["x"] * vp.x - drift, vp.x)
		var y: float = s["y"] * vp.y
		var tw: float = 0.5 + 0.5 * sin(_t * s["rate"] + s["phase"])
		# Cintilação em degraus (pixel art): 3 níveis de brilho.
		tw = floor(tw * 3.0) / 3.0
		var a: float = float(L["alpha"]) * (0.35 + 0.65 * tw)
		var c: Color = s["color"]
		c.a = a
		var p = Vector2(floor(x), floor(y))
		_canvas.draw_rect(Rect2(p, Vector2(sz, sz)), c)
		if s["cross"]:
			var arm: float = sz * (1.0 + tw)
			var ca = c
			ca.a = a * 0.6
			_canvas.draw_rect(Rect2(p + Vector2(-arm, 0), Vector2(arm, sz)), ca)
			_canvas.draw_rect(Rect2(p + Vector2(sz, 0), Vector2(arm, sz)), ca)
			_canvas.draw_rect(Rect2(p + Vector2(0, -arm), Vector2(sz, arm)), ca)
			_canvas.draw_rect(Rect2(p + Vector2(0, sz), Vector2(sz, arm)), ca)
	# Estrela cadente: cabeça + rastro em blocos que somem.
	if not _shoot.is_empty():
		var life: float = _shoot["life"]
		var fade: float = clampf(1.0 - life / 0.7, 0.0, 1.0)
		for i in range(10):
			var q: Vector2 = _shoot["pos"] - _shoot["dir"] * (i * u * 3.0)
			var col = Color("#efe6cf") if i == 0 else Color("#d9a441")
			col.a = fade * (1.0 - i / 10.0)
			_canvas.draw_rect(Rect2(Vector2(floor(q.x), floor(q.y)), Vector2(u, u)), col)

# Textura de nebulosa: ruído fractal posterizado em 3 níveis, em 2 cores
# (violeta e azul-petróleo), com transparência — gerada uma vez e reaproveitada.
static func _get_nebula(biome_id: String = "") -> ImageTexture:
	if _nebula_cache.has(biome_id):
		return _nebula_cache[biome_id]
	var img = Image.create(NEBULA_SIZE.x, NEBULA_SIZE.y, false, Image.FORMAT_RGBA8)
	var n1 = FastNoiseLite.new()
	n1.seed = 7
	n1.frequency = 0.012
	n1.fractal_type = FastNoiseLite.FRACTAL_FBM
	n1.fractal_octaves = 4
	var n2 = FastNoiseLite.new()
	n2.seed = 31
	n2.frequency = 0.016
	n2.fractal_type = FastNoiseLite.FRACTAL_FBM
	n2.fractal_octaves = 3
	var violet = [Color(0.54, 0.36, 0.75, 0.05), Color(0.54, 0.36, 0.75, 0.09), Color(0.60, 0.44, 0.80, 0.14)]
	var teal = [Color(0.25, 0.50, 0.60, 0.04), Color(0.25, 0.50, 0.60, 0.07), Color(0.30, 0.58, 0.68, 0.11)]
	if BIOME_SKY.has(biome_id):
		violet = BIOME_SKY[biome_id]["a"]
		teal = BIOME_SKY[biome_id]["b"]
	for y in range(NEBULA_SIZE.y):
		for x in range(NEBULA_SIZE.x):
			var v: float = n1.get_noise_2d(x, y) * 0.5 + 0.5
			var w: float = n2.get_noise_2d(x + 400, y + 90) * 0.5 + 0.5
			var col := Color(0, 0, 0, 0)
			if v > 0.62:
				col = violet[2]
			elif v > 0.55:
				col = violet[1]
			elif v > 0.49:
				col = violet[0]
			if w > 0.64:
				col = col.blend(teal[2]) if col.a > 0.0 else teal[2]
			elif w > 0.57:
				col = col.blend(teal[1]) if col.a > 0.0 else teal[1]
			elif w > 0.52 and col.a == 0.0:
				col = teal[0]
			img.set_pixel(x, y, col)
	var out := ImageTexture.create_from_image(img)
	_nebula_cache[biome_id] = out
	return out


# ---------------------------------------------------------------------
# Ilhas-tabuleiro e peças voando
# ---------------------------------------------------------------------

func _build_floaters(_fixed_rng: RandomNumberGenerator) -> void:
	# Ilhas e peças usam semente aleatória a cada abertura (estrelas seguem fixas).
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var groups: Array = _available_islands()
	var vp = get_viewport().get_visible_rect().size
	# Ilhas: 3 longe, 3 médias, 2 perto — posições espalhadas, sem sorteio puro
	# para não amontoar.
	var plan: Array[Vector3] = [   # (x%, y%, depth)
		Vector3(0.08, 0.20, 0), Vector3(0.50, 0.10, 0), Vector3(0.88, 0.32, 0),
		Vector3(0.22, 0.72, 1), Vector3(0.70, 0.78, 1), Vector3(0.93, 0.08, 1),
		Vector3(0.04, 0.48, 2), Vector3(0.80, 0.55, 2),
	]
	# Garante uma ilha de cada grupo liberado; o resto sai sorteado sem repetir.
	var picks: Array = []
	var rest: Array = []
	for g in groups:
		var gl: Array = (g as Array).duplicate()
		gl.shuffle()
		if not gl.is_empty():
			picks.append(gl.pop_back())
		rest.append_array(gl)
	rest.shuffle()
	while picks.size() < plan.size() and not rest.is_empty():
		picks.append(rest.pop_back())
	if picks.is_empty():
		plan.clear()   # sem arte de ilha: só as peças
	while picks.size() < plan.size():   # poucas ilhas: repete
		picks.append(picks[rng.randi() % picks.size()])
	picks.resize(plan.size())
	picks.shuffle()
	for pi in range(plan.size()):
		var item: Vector3 = plan[pi]
		var d: Dictionary = ISLAND_DEPTHS[int(item.z)]
		var spr = Sprite2D.new()
		spr.texture = picks[pi]
		# Ilhas novas são arte grande: reduzidas por profundidade, com filtro suave.
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		spr.scale = Vector2(d["scale"], d["scale"])
		var t: float = d["tint"]
		spr.modulate = Color(t, t, t, 1.0 * floater_alpha)
		add_child(spr)
		_floaters.append({
			"node": spr, "x": clampf(item.x + rng.randf_range(-0.07, 0.07), 0.02, 0.98) * vp.x, "y": clampf(item.y + rng.randf_range(-0.09, 0.09), 0.04, 0.96) * vp.y,
			"vx": float(d["speed"]) * (1.0 if rng.randf() < 0.5 else -1.0),
			"vy": 0.0, "phase": rng.randf() * TAU, "bob": float(d["bob"]), "flip": false, "island": true,
		})
	# Peças: reaproveita os sprites reais do jogo (brancas, pretas e damas).
	for i in range(10):
		var path: String = PIECE_PATHS[i % PIECE_PATHS.size()]
		if not ResourceLoader.exists(path):
			continue
		var spr = Sprite2D.new()
		spr.texture = load(path)   # peças do fundo: sempre as padrão (não a cor do jogador)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc: int = 1 + (i % 2)   # 1x a 2x
		spr.scale = Vector2(sc, sc)
		var t: float = 0.45 + 0.12 * (sc - 2)
		spr.modulate = Color(t, t, t, 0.9 * floater_alpha)
		add_child(spr)
		_floaters.append({
			"node": spr, "x": rng.randf() * vp.x, "y": rng.randf() * vp.y,
			"vx": rng.randf_range(-22.0, 22.0), "vy": rng.randf_range(-10.0, 10.0),
			"phase": rng.randf() * TAU, "bob": rng.randf_range(5.0, 12.0),
			"flip": rng.randf() < 0.4, "island": false, "base_scale": sc,
		})

# Texturas liberadas, separadas por grupo: [[menu...], [floresta...], ...]
func _available_islands() -> Array:
	var out: Array = []
	for g in ISLAND_GROUPS:
		if g != "menu" and not MetaProgress.visited_biomes.has(g):
			continue
		var gl: Array = []
		out.append(gl)
		for i in range(1, ISLAND_VARIANTS + 1):
			var path: String = ISLAND_PATTERN % [g, i]
			if not _island_cache.has(path) and ResourceLoader.exists(path):
				_island_cache[path] = load(path)
			if _island_cache.has(path):
				gl.append(_island_cache[path])
	return out

func _update_floaters(delta: float) -> void:
	var vp = get_viewport().get_visible_rect().size
	for f in _floaters:
		var n: Sprite2D = f["node"]
		f["x"] += f["vx"] * delta
		f["y"] += f["vy"] * delta
		var w: float = n.texture.get_width() * n.scale.x
		var h: float = n.texture.get_height() * n.scale.y
		# Dá a volta pela tela (com folga do tamanho do sprite).
		if f["x"] > vp.x + w:
			f["x"] = -w
		elif f["x"] < -w:
			f["x"] = vp.x + w
		if f["y"] > vp.y + h:
			f["y"] = -h
		elif f["y"] < -h:
			f["y"] = vp.y + h
		var bob: float = sin(_t * 0.7 + f["phase"]) * f["bob"]
		n.position = Vector2(floor(f["x"]), floor(f["y"] + bob))
		if f["flip"]:
			# Peça girando como moeda (achata na horizontal).
			var bs: float = f["base_scale"]
			n.scale.x = maxf(0.2, absf(cos(_t * 0.9 + f["phase"]))) * bs

# (As ilhas agora vêm prontas de assets/sprites/menu/ilhas/.)
