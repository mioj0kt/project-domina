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

static var _nebula_tex: ImageTexture = null
static var _island_texs: Array[Texture2D] = []

# Ilhas-tabuleiro flutuantes (sprites em assets/sprites/ui/ilhas); escala de pixel
# e brilho por profundidade (longe = menor, mais escuro e mais lento).
const ISLAND_PATHS: Array[String] = [
	"res://assets/sprites/ui/ilhas/ilha_1.png", "res://assets/sprites/ui/ilhas/ilha_2.png",
	"res://assets/sprites/ui/ilhas/ilha_3.png", "res://assets/sprites/ui/ilhas/ilha_4.png",
	"res://assets/sprites/ui/ilhas/ilha_5.png", "res://assets/sprites/ui/ilhas/ilha_6.png",
	"res://assets/sprites/ui/ilhas/ilha_7.png", "res://assets/sprites/ui/ilhas/ilha_8.png",
	"res://assets/sprites/ui/ilhas/ilha_9.png",
]
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
	grad.set_color(0, SKY_TOP)
	grad.set_color(1, SKY_BOTTOM)
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
	neb.texture = _get_nebula()
	neb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	neb.stretch_mode = TextureRect.STRETCH_SCALE
	neb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	neb.set_anchors_preset(Control.PRESET_FULL_RECT)
	neb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(neb)

	# 3. Estrelas.
	for li in range(LAYERS.size()):
		for i in range(int(LAYERS[li]["count"])):
			_stars.append({
				"layer": li,
				"x": rng.randf(),
				"y": rng.randf(),
				"color": STAR_COLORS[rng.randi() % STAR_COLORS.size()],
				"phase": rng.randf() * TAU,
				"rate": rng.randf_range(0.6, 2.4),
				"cross": li == 2 and rng.randf() < 0.45,
			})
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_stars)
	add_child(_canvas)

	# 4. Ilhas-tabuleiro e peças voando (da mais longe para a mais perto).
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
	_update_floaters(delta)

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
static func _get_nebula() -> ImageTexture:
	if _nebula_tex != null:
		return _nebula_tex
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
	_nebula_tex = ImageTexture.create_from_image(img)
	return _nebula_tex


# ---------------------------------------------------------------------
# Ilhas-tabuleiro e peças voando
# ---------------------------------------------------------------------

func _build_floaters(_fixed_rng: RandomNumberGenerator) -> void:
	# Ilhas e peças usam semente aleatória a cada abertura (estrelas seguem fixas).
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if _island_texs.is_empty():
		for path in ISLAND_PATHS:
			if ResourceLoader.exists(path):
				_island_texs.append(load(path))
	var vp = get_viewport().get_visible_rect().size
	# Ilhas: 3 longe, 3 médias, 2 perto — posições espalhadas, sem sorteio puro
	# para não amontoar.
	var plan: Array[Vector3] = [   # (x%, y%, depth)
		Vector3(0.08, 0.20, 0), Vector3(0.50, 0.10, 0), Vector3(0.88, 0.32, 0),
		Vector3(0.22, 0.72, 1), Vector3(0.70, 0.78, 1), Vector3(0.93, 0.08, 1),
		Vector3(0.04, 0.48, 2), Vector3(0.80, 0.55, 2),
	]
	var island_bag: Array = []   # sorteio sem repetir até esgotar as 6 ilhas
	for item in plan:
		if _island_texs.is_empty():
			break
		if island_bag.is_empty():
			island_bag = range(_island_texs.size())
			island_bag.shuffle()
		var d: Dictionary = ISLAND_DEPTHS[int(item.z)]
		var spr = Sprite2D.new()
		spr.texture = _island_texs[int(island_bag.pop_back())]
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
		spr.texture = load(path)
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

# (As ilhas agora vêm prontas de assets/sprites/ui/ilhas/.)
