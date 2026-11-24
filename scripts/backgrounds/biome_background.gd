class_name BiomeBackground
extends CanvasLayer

# Fundo abstrato animado dos duelos, loja e aposta: um padrão de losangos (como
# o verso de uma carta) rolando bem devagar, vinheta, e partículas temáticas do
# bioma (vaga-lumes, folhas, esporos). Tudo procedural, em pixel art de escala
# inteira. Cada bioma é só uma entrada em BIOMES (cores + partículas), então
# novos biomas são dados, não código.
#
# Uso: add_child(BiomeBackground.new())            -> escolhe sozinho (tutorial ou floresta)
#      var b := BiomeBackground.new(); b.biome = "floresta"; add_child(b)

const BIOMES: Dictionary = {
	"floresta": {
		"top": Color("16201c"), "bottom": Color("221b2a"),
		"line": Color("2a3a31"), "dot": Color("3a4f3f"), "fill": Color("1d2923"),
		"patterns": ["losango", "xadrez", "escamas", "estrelas", "diagonal", "trama", "ondas", "chevron"],
		"fireflies": Color("d9a441"), "n_fireflies": 22,
		"leaves": [Color("5b8f4e"), Color("3f6b3a"), Color("d0802f")], "n_leaves": 14,
		"spores": Color("7fa874"), "n_spores": 46,
		# Cores das transições de cena (SceneTransition): a, b, chefe, detalhe.
		"trans_a": Color("16201c"), "trans_b": Color("2a3a31"), "trans_boss": Color("2a1418"), "trans_edge": Color("5b8f4e"),
	},
	"deserto": {
		"top": Color("2b2118"), "bottom": Color("3a2a22"),
		"line": Color("4d3b2a"), "dot": Color("6e5636"), "fill": Color("33261c"),
		"patterns": ["losango", "xadrez", "escamas", "diagonal", "trama", "ondas", "tijolos", "chevron"],
		# Rajadas de vento com areia (fiapos que aceleram em ondas) e 2 ervas-
		# rolantes cruzando a tela: o efeito único do deserto (como as folhas
		# da floresta).
		"wind": Color("ecd49a"), "n_wind": 46, "n_tumble": 3, "tumble": Color("a8854f"),
		# Brilhos de areia ao vento (no lugar dos vaga-lumes) e grãos subindo.
		"fireflies": Color("f2cf6b"), "n_fireflies": 12,
		"leaves": [Color("cdb078"), Color("a88a58"), Color("e3c98a")], "n_leaves": 0,
		"spores": Color("d9bb82"), "n_spores": 64,
		"trans_a": Color("2b2118"), "trans_b": Color("5a4530"), "trans_boss": Color("3a1a14"), "trans_edge": Color("a8854f"),
	},
	"mina": {
		"top": Color("0d1c22"), "bottom": Color("12272b"),
		"line": Color("1d3a40"), "dot": Color("3f6f73"), "fill": Color("102329"),
		"patterns": ["losango", "xadrez", "escamas", "estrelas", "diagonal", "chevron", "tijolos"],
		# Brilhos de cristal azul-gelo no lugar dos vaga-lumes e poeira verde-água subindo.
		"fireflies": Color("a9dcef"), "n_fireflies": 26,
		"leaves": [Color("3f9b79"), Color("6fb6d8"), Color("7fd1a6")], "n_leaves": 0,
		"spores": Color("7fcfc0"), "n_spores": 52,
		# Estalactites (teto) e estalagmites (chão) no fundo: [rocha, rocha clara, ponta de cristal].
		"cave": [Color("07131a"), Color("1a3a42"), Color("7fd1c0")],
		"trans_a": Color("0d1c22"), "trans_b": Color("1d3a40"), "trans_boss": Color("2a1418"), "trans_edge": Color("4fb3a0"),
	},
	"cume": {
		"top": Color("0f1a2b"), "bottom": Color("1c2a40"),
		"line": Color("23364f"), "dot": Color("4f6f8f"), "fill": Color("142236"),
		"patterns": ["losango", "xadrez", "estrelas", "diagonal", "chevron", "trama"],
		# Vento com neve (fiapos brancos que aceleram nas rajadas, o mesmo sistema
		# da areia do deserto), flocos caindo de lado e aurora no alto.
		"wind": Color("f4f7fa"), "n_wind": 40,
		"snow": Color("f4f7fa"), "n_snow": 170,
		"aurora": true,
		# Faíscas de aurora (verde-água) no lugar dos vaga-lumes.
		"fireflies": Color("6fe0b8"), "n_fireflies": 10,
		"leaves": [Color("dfe8ef"), Color("a9dcef"), Color("c3d2de")], "n_leaves": 0,
		"spores": Color("a9dcef"), "n_spores": 30,
		"trans_a": Color("0f1a2b"), "trans_b": Color("23364f"), "trans_boss": Color("2a1418"), "trans_edge": Color("a9dcef"),
	},
	"caldeira": {
		"top": Color("1c1013"), "bottom": Color("2a1414"),
		"line": Color("3a1d1d"), "dot": Color("6e2a22"), "fill": Color("221215"),
		"patterns": ["losango", "xadrez", "escamas", "diagonal", "chevron", "tijolos"],
		# Brasas subindo (no lugar dos vaga-lumes e dos esporos) e cinza caindo
		# de lado (o mesmo sistema da neve do Cume, em cinza e bem mais rala).
		"fireflies": Color("ffa53a"), "n_fireflies": 18,
		"leaves": [Color("f0662a"), Color("c63a22"), Color("ffe08a")], "n_leaves": 0,
		"spores": Color("f0662a"), "n_spores": 60,
		"snow": Color("9a9095"), "n_snow": 60,
		# Forja ao fundo: vulcões no horizonte que entram em erupção de tempos em
		# tempos e bigornas sendo marteladas nos cantos de baixo (faíscas a cada golpe).
		"forge": true,
		"trans_a": Color("1c1013"), "trans_b": Color("3a1d1d"), "trans_boss": Color("2a1418"), "trans_edge": Color("f0662a"),
	},
	"tutorial": {
		"top": Color("231a2a"), "bottom": Color("1a1420"),
		"line": Color("3a2b41"), "dot": Color("5a4561"), "fill": Color("2a2031"),
		"patterns": ["losango", "xadrez", "escamas", "estrelas", "diagonal", "trama", "chevron"],
		"fireflies": Color("efe6cf"), "n_fireflies": 18,
		"leaves": [Color("7c6489"), Color("5a4561"), Color("d9a441")], "n_leaves": 0,   # sem folhas no tutorial
		"spores": Color("a58bb3"), "n_spores": 40,
		"trans_a": Color("231a2a"), "trans_b": Color("3a2b41"), "trans_boss": Color("2a1418"), "trans_edge": Color("d9a441"),
	},
}

const TILE_ART: int = 24            # lado do ladrilho em "pixels de arte"
const SCROLL_SPEED: Vector2 = Vector2(7.0, 4.0)   # px de tela por segundo (lento)

var biome: String = "auto"
# Padrão do fundo: "auto" sorteia um dos padrões do bioma a cada vez; ou force um
# nome de PATTERNS ("losango", "xadrez", "escamas", "estrelas", "diagonal", "trama",
# "ondas", "tijolos", "chevron").
var pattern: String = "auto"
var _cfg: Dictionary = {}
var _tile_tex: ImageTexture = null
var _canvas: Node2D
var _vignette: TextureRect
var _scroll: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _flies: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []
var _spores: Array[Dictionary] = []
var _winds: Array[Dictionary] = []
var _tumbles: Array[Dictionary] = []
var _snow: Array[Dictionary] = []
var _snow_fx: Node2D = null
var _aurora: Array = []   # [Texture2D, y (fração), velocidade, fase]
var _scroll_vel: Vector2 = SCROLL_SPEED
var _wind_phase: float = 0.0   # tempo "acelerado" pelas rajadas
var _gust: float = 0.0         # 0..1, força da rajada atual
# Caldeira (forja ao fundo)
var _volcs: Array = []         # {x (fração), h (fração da tela), w (fração), next: tempo da próxima erupção, t0: início da última}
var _anvils: Array = []        # {x (fração), period, phase, beats, beat_phase, flip, last}
var _beat: float = -1.0        # tempo da música (Music.beat_time) neste quadro; -1 = sem andamento
var _parts: Array = []         # faíscas/bombas/fumaça: {p, v, t0, life, c, s, g (gravidade), kind}
var _forge_fx: Node2D = null   # a forja fica POR CIMA da vinheta (senão some nos cantos escuros)
var _meteors: Array = []       # bolas de fogo grandes que cruzam a tela vindo na direção da câmera

func _init() -> void:
	layer = -100
	follow_viewport_enabled = false

func _ready() -> void:
	if biome == "auto":
		biome = "tutorial" if TutorialManager.is_active else RunManager.map_biome
	_cfg = BIOMES.get(biome, BIOMES["floresta"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + biome.hash() % 1000

	# 1. Degradê vertical.
	var grad := Gradient.new()
	grad.set_color(0, _cfg["top"])
	grad.set_color(1, _cfg["bottom"])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 4
	gtex.height = 256
	var base := TextureRect.new()
	base.texture = gtex
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	# 2. Padrão de losangos + partículas (desenhados num Node2D).
	if pattern == "auto":
		var options: Array = _cfg.get("patterns", ["losango"])
		pattern = options[randi() % options.size()]
	_tile_tex = _make_tile(_cfg, pattern)
	_canvas = Node2D.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)

	# 3. Vinheta (escurece as bordas para o centro respirar).
	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0.0))
	vg.set_color(1, Color(0, 0, 0, 0.55))
	vg.set_offset(0, 0.55)
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.0, 0.5)   # raio até a borda (esquerda/direita)
	vt.width = 128
	vt.height = 72
	_vignette = TextureRect.new()
	_vignette.texture = vt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	if bool(_cfg.get("forge", false)):
		_forge_fx = Node2D.new()
		_forge_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_forge_fx.draw.connect(func(): _forge_draw(get_viewport().get_visible_rect().size, _unit(get_viewport().get_visible_rect().size)))
		add_child(_forge_fx)
	if int(_cfg.get("n_snow", 0)) > 0:
		_snow_fx = Node2D.new()
		_snow_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_snow_fx.draw.connect(_draw_snow)
		add_child(_snow_fx)

	# Direção e velocidade do rolar do padrão variam a cada visita.
	var dirs: Array[Vector2] = [Vector2(1, 0.57), Vector2(-1, 0.57), Vector2(1, -0.57), Vector2(-1, -0.57),
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	_scroll_vel = dirs[randi() % dirs.size()] * SCROLL_SPEED.length() * randf_range(0.7, 1.4)

	# Partículas (posições em fração da tela).
	for i in range(int(_cfg["n_fireflies"])):
		_flies.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"rate": rng.randf_range(0.5, 1.4), "ax": rng.randf_range(14.0, 40.0), "ay": rng.randf_range(10.0, 30.0)})
	for i in range(int(_cfg["n_leaves"])):
		_leaves.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"fall": rng.randf_range(10.0, 22.0), "sway": rng.randf_range(16.0, 40.0),
			"col": rng.randi() % (_cfg["leaves"] as Array).size(), "u": 3 + (i % 2)})
	for i in range(int(_cfg.get("n_wind", 0))):
		_winds.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"spd": rng.randf_range(60.0, 150.0), "len": 3 + (i % 5), "u": 1 + (i % 2)})
	for i in range(int(_cfg.get("n_tumble", 0))):
		var tb := {"x": 0.0, "y": 0.5, "spd": 60.0, "r": 4.0, "ph": 0.0, "wait": 0.0}
		_respawn_tumble(tb, true)
		_tumbles.append(tb)
	for i in range(int(_cfg.get("n_snow", 0))):
		_snow.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"fall": rng.randf_range(28.0, 80.0), "u": 3 if i % 23 == 0 else (2 if i % 7 == 0 else (1 if i % 3 == 0 else 0))})
	if bool(_cfg.get("aurora", false)):
		for k in range(3):
			var ap: String = "res://assets/sprites/mapa/ceu/cume/aurora_%d.png" % (k + 1)
			if ResourceLoader.exists(ap):
				_aurora.append([load(ap), 0.04 + 0.08 * float(k), rng.randf_range(6.0, 12.0) * (1.0 if k % 2 == 0 else -1.0), rng.randf() * TAU])
	if bool(_cfg.get("forge", false)):
		_forge_init(rng)
	for i in range(int(_cfg["n_spores"])):
		_spores.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"rise": rng.randf_range(5.0, 14.0), "u": 2 + (i % 2)})

# Sorteia uma nova erva-rolante: altura em QUALQUER ponto do fundo (as de cima
# são menores, mais lentas e quicam menos, como se estivessem longe; as de baixo
# são maiores e mais rápidas). Ao reaparecer, espera um tempo aleatório fora da tela.
func _respawn_tumble(tb: Dictionary, first: bool) -> void:
	var depth: float = randf_range(0.1, 0.95)   # 0 = longe/alto, 1 = perto/baixo
	tb["y"] = depth
	tb["r"] = lerpf(3.0, 7.0, depth)
	tb["spd"] = lerpf(35.0, 90.0, depth) * randf_range(0.85, 1.15)
	tb["ph"] = randf() * TAU
	if first:
		tb["x"] = randf_range(-100.0, 1700.0)
		tb["wait"] = 0.0
	else:
		tb["x"] = -220.0
		tb["wait"] = randf_range(1.0, 9.0)

func _process(delta: float) -> void:
	_t += delta
	_scroll += _scroll_vel * delta
	if not _winds.is_empty() or not _tumbles.is_empty():
		_gust = pow(maxf(0.0, sin(_t * 0.28 + 1.0)), 2.0)
		_wind_phase += delta * (1.0 + 5.0 * _gust)
		var vw: float = get_viewport().get_visible_rect().size.x
		for tb in _tumbles:
			if float(tb["wait"]) > 0.0:
				tb["wait"] = float(tb["wait"]) - delta
				continue
			tb["x"] = float(tb["x"]) + delta * float(tb["spd"]) * (1.0 + 5.0 * _gust)
			if float(tb["x"]) > vw + 220.0:
				_respawn_tumble(tb, false)
	if not _volcs.is_empty():
		_forge_update(delta)
	_canvas.queue_redraw()

const PATTERNS: Array[String] = ["losango", "xadrez", "escamas", "estrelas", "diagonal", "trama", "ondas", "tijolos", "chevron"]

# Ladrilho 24x24 SEM emendas (periódico em x e y). Cada padrão usa as mesmas 3
# cores do bioma: fio (line), pontinho (dot) e miolo (fill).
static func _make_tile(cfg: Dictionary, tile_pattern: String = "losango") -> ImageTexture:
	var n: int = TILE_ART
	@warning_ignore("integer_division")
	var h: int = n / 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var line: Color = cfg["line"]
	var dot: Color = cfg["dot"]
	var fill: Color = cfg["fill"]
	for y in range(n):
		for x in range(n):
			match tile_pattern:
				"xadrez":
					# Casas de 12x12 alternadas, com fio fino na divisa e pontinho no miolo.
					@warning_ignore("integer_division")
					var dark_sq: bool = ((x / h) + (y / h)) % 2 == 0
					if dark_sq:
						img.set_pixel(x, y, fill)
					if x % h == 0 or y % h == 0:
						img.set_pixel(x, y, line)
					if dark_sq and x % h in [5, 6] and y % h in [5, 6]:
						img.set_pixel(x, y, dot)
				"escamas":
					# Escamas de peixe: semicírculos de raio 12, fileiras alternadas.
					var on_line := false
					for cy in [0, 12, 24, 36]:
						var row: int = cy / 12
						for i in range(-1, 3):
							var cx: int = 24 * i + (12 if row % 2 == 1 else 0)
							var dx: float = float(x - cx) + 0.5
							var dy: float = float(y - cy) + 0.5
							if dy >= 0.0 and absf(sqrt(dx * dx + dy * dy) - 12.0) < 0.8:
								on_line = true
					if on_line:
						img.set_pixel(x, y, line)
					elif (x + y * 3) % 11 == 0:
						img.set_pixel(x, y, fill)
				"estrelas":
					# Cruzes de 4 pontas em grade alternada, com miolo claro.
					for c in [Vector2i(6, 6), Vector2i(18, 18)]:
						var dx2: int = absi(x - c.x)
						var dy2: int = absi(y - c.y)
						if (dx2 == 0 and dy2 <= 3) or (dy2 == 0 and dx2 <= 3):
							img.set_pixel(x, y, line)
						if dx2 <= 1 and dy2 <= 1 and dx2 + dy2 <= 1:
							img.set_pixel(x, y, dot)
				"diagonal":
					# Faixas diagonais largas com fio claro.
					var d: int = (x + y) % n
					if d < h:
						img.set_pixel(x, y, fill)
					if d == 0 or d == h:
						img.set_pixel(x, y, line)
				"ondas":
					# Fios ondulados (2 por ladrilho) com nó nas cristas.
					for base in [6, 18]:
						var wy: int = base + int(round(sin(float(x) / float(n) * TAU) * 3.0))
						if y == wy:
							img.set_pixel(x, y, line)
							if x == 6 or x == 18:
								img.set_pixel(x, y, dot)
						elif y == wy + 1 or y == wy - 1:
							pass
					if (x * 5 + y * 7) % 23 == 0:
						img.set_pixel(x, y, fill)
				"tijolos":
					# Tijolos 12x6, fileiras alternadas (ruínas); miolo escuro em alguns.
					@warning_ignore("integer_division")
					var brow: int = y / 6
					var bx: int = (x + (6 if brow % 2 == 1 else 0)) % 12
					if y % 6 == 0 or bx == 0:
						img.set_pixel(x, y, line)
					elif (brow + floori((x + (6 if brow % 2 == 1 else 0)) / 12.0)) % 3 == 0:
						img.set_pixel(x, y, fill)
					if bx == 6 and y % 6 == 3 and brow % 2 == 0:
						img.set_pixel(x, y, dot)
				"chevron":
					# Zigue-zague (setas) em duas fileiras, período 12.
					var zz: int = absi((x % 12) - 6)
					for kb in [0, 12]:
						if y == zz + kb + 3:
							img.set_pixel(x, y, line)
						elif y == zz + kb + 4 and (x % 12) == 6:
							img.set_pixel(x, y, dot)
				"trama":
					# Trama de fios cruzados com um nó (dot) em cada cruzamento.
					if x % h == 0 or y % h == 0:
						img.set_pixel(x, y, line)
					if x % h <= 1 and y % h <= 1:
						img.set_pixel(x, y, dot)
					elif x % h > 3 and x % h < 9 and y % h > 3 and y % h < 9 and (x % h + y % h) % 2 == 0:
						img.set_pixel(x, y, fill)
				_:
					# "losango": o original.
					var dd: int = absi(x - h) + absi(y - h)
					if dd == h:
						img.set_pixel(x, y, line)
					elif dd < h - 3:
						img.set_pixel(x, y, fill)
	if tile_pattern == "losango":
		for c in [Vector2i(h, h), Vector2i(h - 1, h), Vector2i(h, h - 1), Vector2i(h - 1, h - 1),
				Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
			img.set_pixel(c.x, c.y, dot)
	return ImageTexture.create_from_image(img)

func _unit(vp: Vector2) -> float:
	return maxf(3.0, round(vp.y / 270.0))   # ~4 a 1080p

func _draw_all() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var u: float = _unit(vp)
	var tile: float = float(TILE_ART) * u
	# Padrão rolando: desloca em pixels INTEIROS de tela (fluido, e ainda sem borrar).
	var off := Vector2(fposmod(floorf(_scroll.x), tile), fposmod(floorf(_scroll.y), tile))
	var cols: int = int(ceil(vp.x / tile)) + 2
	var rows: int = int(ceil(vp.y / tile)) + 2
	for j in range(rows):
		for i in range(cols):
			_canvas.draw_texture_rect(_tile_tex, Rect2(Vector2(i * tile, j * tile) - Vector2(tile, tile) + off, Vector2(tile, tile)), false)
	if _cfg.has("cave"):
		draw_cave_spikes(_canvas, vp, u, _cfg["cave"], _t)
	if _forge_fx != null:
		_forge_fx.queue_redraw()
	# Cume: aurora no alto, bem discreta (o duelo fica por cima).
	var asc: float = maxf(2.0, floorf(vp.x / 320.0 * 0.95))
	for ab in _aurora:
		var atex: Texture2D = ab[0]
		var aw: float = atex.get_width() * asc
		var ax: float = (vp.x - aw) * 0.5 + sin(_t * 0.05 + float(ab[3])) * float(ab[2]) * 5.0
		var aa: float = 0.16 + 0.12 * sin(_t * 0.3 + float(ab[3]))
		_canvas.draw_texture_rect(atex, Rect2(Vector2(ax, float(ab[1]) * vp.y).round(), atex.get_size() * asc), false, Color(1, 1, 1, aa))
	if _snow_fx != null:
		_snow_fx.queue_redraw()

	# Esporos subindo (mais ao fundo, bem discretos).
	var spore_col: Color = _cfg["spores"]
	for s in _spores:
		var su: float = float(s["u"])
		var y: float = fposmod(float(s["y"]) * vp.y - _t * float(s["rise"]) * 1.0, vp.y)
		var x: float = float(s["x"]) * vp.x + sin(_t * 0.5 + float(s["ph"])) * 10.0
		var a: float = 0.25 + 0.2 * (sin(_t * 0.8 + float(s["ph"])) * 0.5 + 0.5)
		_canvas.draw_rect(Rect2(floorf(x), floorf(y), su, su), Color(spore_col.r, spore_col.g, spore_col.b, a))
	# Deserto: rajadas de areia (fiapos horizontais) e ervas-rolantes.
	if not _winds.is_empty():
		var wc: Color = _cfg["wind"]
		var g: float = _gust
		for w in _winds:
			var wu: float = u * float(w["u"]) * 0.5
			wu = maxf(2.0, round(wu))
			var wx: float = fposmod(float(w["x"]) * vp.x + _wind_phase * float(w["spd"]), vp.x + 120.0) - 60.0
			var wy: float = float(w["y"]) * vp.y + sin(_t * 1.3 + float(w["ph"])) * 6.0 + (wx / vp.x) * 26.0
			var wl: float = float(w["len"]) * wu * (1.0 + 2.2 * g)
			var wa: float = 0.18 + 0.4 * g
			var px2: float = floorf(wx)
			var py2: float = floorf(wy)
			_canvas.draw_rect(Rect2(px2 - wl, py2, wl, wu), Color(wc.r, wc.g, wc.b, wa * 0.45))
			_canvas.draw_rect(Rect2(px2 - wl * 0.5, py2, wl * 0.5, wu), Color(wc.r, wc.g, wc.b, wa * 0.8))
			_canvas.draw_rect(Rect2(px2, py2, wu, wu), Color(wc.r, wc.g, wc.b, minf(1.0, wa + 0.3)))
	for tb in _tumbles:
		_draw_tumbleweed(vp, u, tb)
	# Folhas caindo, balançando (sprite de 3x2 blocos).
	var leaf_cols: Array = _cfg["leaves"]
	for l in _leaves:
		var lu: float = float(l["u"]) * (u / 3.0)
		lu = maxf(2.0, round(lu))
		var y: float = fposmod(float(l["y"]) * vp.y + _t * float(l["fall"]), vp.y + 40.0) - 20.0
		var x: float = float(l["x"]) * vp.x + sin(_t * 0.6 + float(l["ph"])) * float(l["sway"])
		var col: Color = leaf_cols[int(l["col"])]
		var flip: bool = sin(_t * 0.9 + float(l["ph"])) > 0.0
		var px: float = floorf(x)
		var py: float = floorf(y)
		var dark := col.darkened(0.35)
		if flip:
			_canvas.draw_rect(Rect2(px, py, lu * 2.0, lu), col)
			_canvas.draw_rect(Rect2(px + lu, py + lu, lu * 2.0, lu), col)
			_canvas.draw_rect(Rect2(px + lu, py + lu, lu, lu), dark)
		else:
			_canvas.draw_rect(Rect2(px + lu, py, lu * 2.0, lu), col)
			_canvas.draw_rect(Rect2(px, py + lu, lu * 2.0, lu), col)
			_canvas.draw_rect(Rect2(px + lu, py + lu, lu, lu), dark)
	# Vaga-lumes: miolo brilhante + halo em losango de pixels (3 camadas), pisca em
	# "rajadas" (acende rápido, apaga devagar), deixa um rastro curto e varia
	# do dourado para um amarelo-esverdeado.
	var fc: Color = _cfg["fireflies"]
	for f in _flies:
		var ph: float = float(f["ph"])
		var rate: float = float(f["rate"])
		var blink: float = pow(maxf(0.0, sin(_t * rate * 1.3 + ph)), 3.0)
		var glow: float = 0.18 + 0.82 * blink
		var tint: Color = fc.lerp(Color(0.78, 1.0, 0.45), 0.35 * (sin(ph * 3.1) * 0.5 + 0.5))
		# Rastro: posições do passado na mesma trajetória, cada vez mais fracas.
		for k in range(3, 0, -1):
			var tp: Vector2 = _firefly_pos(f, vp, _t - float(k) * 0.16)
			var ta: float = 0.10 * glow * (1.0 - float(k) / 4.0)
			_canvas.draw_rect(Rect2(floorf(tp.x), floorf(tp.y), u, u), Color(tint.r, tint.g, tint.b, ta))
		var p: Vector2 = _firefly_pos(f, vp, _t)
		var px: float = floorf(p.x)
		var py: float = floorf(p.y)
		# Halo: losango de pixels; alfa cai com a distância e sobe com o brilho.
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var dist: int = absi(dx) + absi(dy)
				if dist == 0 or dist > 3:
					continue
				var ha: float = (0.16 if dist == 1 else (0.09 if dist == 2 else 0.04)) * (0.4 + 1.2 * glow)
				_canvas.draw_rect(Rect2(px + float(dx) * u, py + float(dy) * u, u, u), Color(tint.r, tint.g, tint.b, ha))
		# Miolo: quadrado de 2x2 unidades com ponto quente no centro.
		_canvas.draw_rect(Rect2(px, py, u * 2.0, u * 2.0), Color(tint.r, tint.g, tint.b, 0.45 + 0.55 * glow))
		_canvas.draw_rect(Rect2(px + u * 0.5, py + u * 0.5, u, u), Color(1.0, 0.97, 0.8, 0.3 + 0.7 * glow))

# Posição do vaga-lume no instante `at`: deriva em curvas lentas e suaves.
func _firefly_pos(f: Dictionary, vp: Vector2, at: float) -> Vector2:
	var rate: float = float(f["rate"])
	var ph: float = float(f["ph"])
	var x: float = float(f["x"]) * vp.x + sin(at * 0.35 * rate + ph) * float(f["ax"]) + sin(at * 0.9 * rate + ph * 2.3) * 6.0
	var y: float = float(f["y"]) * vp.y + cos(at * 0.28 * rate + ph * 1.7) * float(f["ay"]) + cos(at * 0.7 * rate + ph) * 5.0
	return Vector2(x, y)

# Erva-rolante: aro de quadradinhos girando + raios internos; pula de leve.
func _draw_tumbleweed(vp: Vector2, u: float, tb: Dictionary) -> void:
	var tcol: Color = _cfg["tumble"]
	if float(tb["wait"]) > 0.0:
		return
	var cx: float = float(tb["x"])
	var rad: float = float(tb["r"]) * u
	var bounce: float = absf(sin(cx * 0.018 + float(tb["ph"]))) * rad * 1.8 * (1.0 + 0.4 * _gust)
	var cy: float = float(tb["y"]) * vp.y - bounce
	var ang0: float = cx * 0.03
	var px: float = maxf(2.0, round(u * 0.9))
	# Sombra no chão.
	var shadow_w: float = rad * (1.6 - bounce / 60.0)
	_canvas.draw_rect(Rect2(floorf(cx - shadow_w * 0.5), floorf(float(tb["y"]) * vp.y + rad * 0.9), shadow_w, px), Color(0, 0, 0, 0.22))
	for k in range(14):
		var a: float = ang0 + float(k) * TAU / 14.0
		var p := Vector2(cx, cy) + Vector2(cos(a), sin(a)) * rad
		_canvas.draw_rect(Rect2(floorf(p.x), floorf(p.y), px, px), tcol if k % 3 != 0 else tcol.darkened(0.3))
	for k in range(3):
		var a2: float = ang0 * 1.3 + float(k) * TAU / 3.0
		for step in range(1, 4):
			var p2 := Vector2(cx, cy) + Vector2(cos(a2), sin(a2)) * rad * (float(step) / 4.0)
			_canvas.draw_rect(Rect2(floorf(p2.x), floorf(p2.y), px, px), tcol.darkened(0.15))


# Mina: estalactites penduradas no teto e estalagmites subindo do chão, em
# escadinha de pixels (duas camadas: fundo mais claro/baixo, frente escura).
# Fixas, com um brilho lento na ponta de cristal de algumas.
static func draw_cave_spikes(canvas: CanvasItem, vp: Vector2, u: float, cols: Array, t_now: float) -> void:
	var rock: Color = cols[0]
	var lite: Color = cols[1]
	var tip: Color = cols[2]
	var step: float = u * 2.0
	for lyr in range(2):
		var rng := RandomNumberGenerator.new()
		rng.seed = 777 + lyr * 31
		var w_base: float = (150.0 if lyr == 0 else 230.0) * u / 4.0
		var n: int = int(ceil(vp.x / w_base)) + 1
		for side in range(2):   # 0 = teto, 1 = chão
			for i in range(n):
				var w: float = w_base * rng.randf_range(0.7, 1.3)
				var h: float = (vp.y * (0.15 if lyr == 0 else 0.23)) * rng.randf_range(0.45, 1.25)
				var cx: float = (float(i) + rng.randf()) * w_base
				var col: Color = lite if lyr == 0 else rock
				var rows: int = int(h / step)
				for r in range(rows):
					var frac: float = 1.0 - float(r) / float(rows)
					var hw: float = roundf(w * 0.5 * frac / step) * step
					if hw <= 0.0:
						hw = step * 0.5
					var y: float = float(r) * step if side == 0 else vp.y - float(r + 1) * step
					canvas.draw_rect(Rect2(floorf(cx - hw), floorf(y), hw * 2.0, step), col)
					# fio de luz do lado esquerdo (volume)
					if lyr == 1:
						canvas.draw_rect(Rect2(floorf(cx - hw), floorf(y), step, step), lite)
				# Ponta de cristal brilhando em algumas.
				if lyr == 1 and (i % 3 == 0):
					var ty: float = float(rows) * step
					var py: float = ty if side == 0 else vp.y - ty - step
					var a: float = 0.45 + 0.45 * (sin(t_now * 1.2 + cx) * 0.5 + 0.5)
					canvas.draw_rect(Rect2(floorf(cx - step * 0.5), floorf(py - (0.0 if side == 1 else step)), step, step * 2.0), Color(tip.r, tip.g, tip.b, a))

# Cume: flocos caindo de lado, empurrados pelas rajadas. Ficam numa camada POR
# CIMA da vinheta (senão somem nas bordas escurecidas).
func _draw_snow() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var u: float = _unit(vp)
	if not _snow.is_empty():
		var sc: Color = _cfg["snow"]
		var fu: float = maxf(3.0, round(u * 0.75))
		for f in _snow:
			var shape: int = int(f["u"])
			var fy: float = fposmod(float(f["y"]) * vp.y + _t * float(f["fall"]), vp.y + 30.0) - 15.0
			var fx: float = fposmod(float(f["x"]) * vp.x + _wind_phase * float(f["fall"]) * 1.4 + sin(_t + float(f["ph"])) * 8.0, vp.x + 30.0) - 15.0
			var fa: float = 0.6 + 0.1 * float(shape) + 0.12 * sin(float(f["ph"]))
			ForestBackground.draw_flake(_snow_fx, Vector2(floorf(fx), floorf(fy)), fu, shape, Color(sc.r, sc.g, sc.b, clampf(fa, 0.2, 0.95)))


# ------------------------------------------------------------------ Caldeira: forja
const _FORGE_ROCK := Color("2a1517")      # silhueta dos vulcões de trás
const _FORGE_ROCK2 := Color("3a1c1c")     # vulcões da frente
const _FORGE_RIM := Color("a0402a")       # fio de lava na encosta
const _ANVIL_BODY := Color("3e2628")
const _ANVIL_LIT := Color("b0603e")
const _HOT := [Color("ffe08a"), Color("ffa53a"), Color("f0662a")]
# Bigorna (chifre para a esquerda) e toco embaixo, em pixels do fundo.
const _ANVIL_MASK: Array = [
	"..OOOOOOOOOOOOOO",
	"OOOOOOOOOOOOOOOO",
	"..OOOOOOOOOOOOOO",
	"......OOOOOOO...",
	".......OOOOO....",
	".......OOOOO....",
	"......OOOOOOO...",
	".....OOOOOOOOO..",
	"....TTTTTTTTTTT.",
	"....TTTTTTTTTTT.",
	"....TTTTTTTTTTT.",
]

func _forge_init(rng: RandomNumberGenerator) -> void:
	for v in [[0.06, 0.20, 0.30], [0.27, 0.13, 0.22], [0.52, 0.17, 0.26], [0.76, 0.12, 0.20], [0.95, 0.22, 0.30]]:
		_volcs.append({"x": v[0], "h": v[1], "w": v[2], "next": 1.5 + 2.6 * float(_volcs.size()) + rng.randf_range(0.0, 1.5), "t0": -99.0})
	# Os dois ferreiros batem no ritmo da música, um de cada vez: o da esquerda nos tempos
	# 1 e 3 do compasso, o da direita nos tempos 2 e 4. Sem andamento conhecido, cada
	# um segue o próprio relógio (period/phase em segundos).
	_anvils.append({"x": 0.11, "period": 1.35, "phase": 0.0, "beats": 2.0, "beat_phase": 0.0, "flip": false, "last": -1})
	_anvils.append({"x": 0.89, "period": 1.6, "phase": 0.7, "beats": 2.0, "beat_phase": 1.0, "flip": true, "last": -1})

## Ciclo do martelo: a parte inteira conta as batidas, a fração é a fase (0 = bateu agora).
func _anvil_cycle(a: Dictionary) -> float:
	if _beat >= 0.0:
		return (_beat + float(a["beat_phase"])) / float(a["beats"])
	return (_t + float(a["phase"])) / float(a["period"])

# Ângulo do martelo (0 = encostado na bigorna; negativo = levantado) e se acabou de bater.
func _hammer_angle(a: Dictionary, back: float = 0.0) -> float:
	return _hammer_angle_k(fposmod(_anvil_cycle(a) - back, 1.0))

func _hammer_angle_k(k: float) -> float:
	if k < 0.07:      # bateu: fica um instante em cima da peça (com um quique pequeno)
		return -0.10 * sin(k / 0.07 * PI)
	if k < 0.34:      # volta a subir, desacelerando
		var r: float = (k - 0.07) / 0.27
		return -1.45 * (1.0 - pow(1.0 - r, 2.0))
	if k < 0.84:      # segura lá em cima, tomando impulso
		return -1.45 - 0.12 * sin((k - 0.34) / 0.50 * PI)
	return -lerpf(1.45, 0.0, pow((k - 0.84) / 0.16, 2.2))   # desce rápido e acerta no tempo

func _forge_update(delta: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var u: float = _unit(vp)
	var pu: float = u * 2.0
	var ks: float = vp.y / 1080.0
	for i in range(_volcs.size()):
		var v: Dictionary = _volcs[i]
		if _t >= float(v["next"]):
			v["t0"] = _t
			v["next"] = _t + randf_range(6.0, 11.0)
			# rios de lava que vão descer pelas encostas (posição relativa na largura da encosta)
			var flows: Array = []
			for k in range(randi_range(2, 4)):
				flows.append({"k": randf_range(-0.65, 0.65), "wob": randf_range(0.0, 6.28), "speed": randf_range(0.045, 0.08)})
			v["flows"] = flows
			var top := Vector2(float(v["x"]) * vp.x, vp.y * (1.0 - float(v["h"])))
			# bombas de lava grandes (caem nas encostas e espirram) + brasas miúdas
			for k in range(randi_range(7, 11)):
				var a: float = randf_range(-PI * 0.82, -PI * 0.18)
				var spd: float = randf_range(160.0, 320.0) * ks
				_parts.append({"p": top, "v": Vector2(cos(a), sin(a)) * spd, "t0": _t + randf_range(0.25, 0.6), "life": 4.0,
					"c": _HOT[1], "s": u * randf_range(2.0, 3.0), "g": 260.0 * ks, "kind": 2,
					"land": vp.y * (1.0 - randf_range(0.01, 0.12)), "trail": []})
			for k in range(randi_range(14, 22)):
				var a2: float = randf_range(-PI * 0.9, -PI * 0.1)
				var spd3: float = randf_range(80.0, 260.0) * ks
				_parts.append({"p": top, "v": Vector2(cos(a2), sin(a2)) * spd3, "t0": _t + randf_range(0.2, 0.7), "life": randf_range(0.9, 1.8),
					"c": _HOT[randi() % 3], "s": u, "g": 200.0 * ks, "kind": 0})
			for k in range(8):
				_parts.append({"p": top + Vector2(randf_range(-12, 12), 0), "v": Vector2(randf_range(-10, 10), -randf_range(24, 46)) * ks, "t0": _t + 0.25 + k * 0.14,
					"life": randf_range(3.0, 4.5), "c": Color("4a3a40"), "s": u * 3.0, "g": 0.0, "kind": 1})
			# às vezes uma bola de fogo vem na direção da tela, por cima de tudo do fundo
			if randf() < 0.55:
				var side: float = -1.0 if top.x > vp.x * 0.5 else 1.0
				_meteors.append({"from": top, "to": Vector2(top.x + side * randf_range(0.35, 0.6) * vp.x, vp.y + 80.0), "peak": randf_range(0.55, 0.8) * vp.y,
					"t0": _t + 0.35, "dur": randf_range(1.6, 2.2), "s": u * 1.4})
	_beat = Music.beat_time()
	for a in _anvils:
		var hit: int = int(floor(_anvil_cycle(a)))
		if hit != int(a["last"]):
			a["last"] = hit
			var sp: Vector2 = _anvil_strike_point(a, vp, pu)
			# o golpe do tempo 1 (ferreiro da esquerda, batida par) solta mais faísca
			var strong: bool = _beat >= 0.0 and not bool(a["flip"]) and hit % 2 == 0
			a["strong"] = strong
			for k in range(26 if strong else 14):
				var ang: float = randf_range(-PI * 0.95, -PI * 0.05)
				var spd2: float = randf_range(60.0, 220.0) * ks
				_parts.append({"p": sp, "v": Vector2(cos(ang), sin(ang)) * spd2, "t0": _t, "life": randf_range(0.35, 0.8),
					"c": _HOT[randi() % 3], "s": u, "g": 420.0 * ks, "kind": 0})
	# física das partículas (integra; as bombas espirram quando caem)
	var splashes: Array = []
	for p in _parts:
		if _t < float(p["t0"]):
			continue
		var vv: Vector2 = p["v"]
		vv.y += float(p["g"]) * delta
		p["v"] = vv
		var pp: Vector2 = Vector2(p["p"]) + vv * delta
		p["p"] = pp
		if int(p["kind"]) == 2:
			var trail_pts: Array = p["trail"]
			trail_pts.push_front(pp)
			if trail_pts.size() > 6:
				trail_pts.pop_back()
			if vv.y > 0.0 and pp.y >= float(p["land"]):
				p["life"] = 0.0
				splashes.append(pp)
	for sp2 in splashes:
		for k in range(10):
			var ang2: float = randf_range(-PI * 0.95, -PI * 0.05)
			_parts.append({"p": sp2, "v": Vector2(cos(ang2), sin(ang2)) * randf_range(40.0, 130.0) * ks, "t0": _t, "life": randf_range(0.3, 0.6),
				"c": _HOT[randi() % 3], "s": u, "g": 380.0 * ks, "kind": 0})
		_parts.append({"p": sp2, "v": Vector2.ZERO, "t0": _t, "life": 2.5, "c": _HOT[2], "s": u * 2.0, "g": 0.0, "kind": 3})   # poça esfriando
	_parts = _parts.filter(func(p): return _t - float(p["t0"]) < float(p["life"]))
	_meteors = _meteors.filter(func(m): return _t - float(m["t0"]) < float(m["dur"]))

func _meteor_pos(m: Dictionary, k: float) -> Vector2:
	var a: Vector2 = m["from"]
	var b: Vector2 = m["to"]
	var p: Vector2 = a.lerp(b, k)
	var top_y: float = minf(a.y, b.y) - float(m["peak"])
	return Vector2(p.x, p.y + (top_y - minf(a.y, b.y)) * 4.0 * k * (1.0 - k))

func _anvil_origin(a: Dictionary, vp: Vector2, pu: float) -> Vector2:
	# canto de cima à esquerda da máscara da bigorna, pousada na borda de baixo da tela
	var w: float = 16.0 * pu
	var h: float = float(_ANVIL_MASK.size()) * pu
	return Vector2(floorf(float(a["x"]) * vp.x - w * 0.5), floorf(vp.y - h - pu * 2.0))

func _anvil_strike_point(a: Dictionary, vp: Vector2, pu: float) -> Vector2:
	var o: Vector2 = _anvil_origin(a, vp, pu)
	return o + Vector2((5.0 if not bool(a["flip"]) else 10.0) * pu + pu * 3.0, 0.0)

func _forge_draw(vp: Vector2, u: float) -> void:
	var c: CanvasItem = _forge_fx
	var step: float = u * 2.0
	# brilho de lava no horizonte (mais forte logo depois de uma erupção)
	var boom: float = 0.0
	for v in _volcs:
		var dt: float = _t - float(v["t0"])
		if dt >= 0.0 and dt < 2.0:
			boom = maxf(boom, (1.0 - dt / 2.0))
	for k in range(6):
		var a: float = (0.05 + 0.10 * boom) * (1.0 - float(k) / 6.0)
		c.draw_rect(Rect2(0, vp.y * (0.70 + 0.05 * k), vp.x, vp.y * 0.05 + 1.0), Color(0.94, 0.35, 0.12, a))
	# vulcões: escadinha de pixels, os mais altos atrás
	for vol_layer in range(2):
		for v in _volcs:
			var tall: bool = float(v["h"]) >= 0.17
			if (vol_layer == 0) != tall:
				continue
			var cx: float = float(v["x"]) * vp.x
			var h: float = float(v["h"]) * vp.y
			var hw: float = float(v["w"]) * vp.x * 0.5
			var rows: int = int(h / step)
			var col: Color = _FORGE_ROCK if vol_layer == 0 else _FORGE_ROCK2
			var dt2: float = _t - float(v["t0"])
			var glow: float = clampf(1.0 - absf(dt2 - 0.3) / 1.6, 0.0, 1.0) if dt2 >= 0.0 else 0.0
			for r in range(rows):
				var frac: float = float(r) / float(rows)            # 0 = topo
				var w2: float = roundf((hw * (0.12 + 0.88 * frac)) / step) * step
				var y: float = vp.y - h + float(r) * step
				c.draw_rect(Rect2(floorf(cx - w2), floorf(y), w2 * 2.0, step), col)
				c.draw_rect(Rect2(floorf(cx + w2 * 0.25), floorf(y), w2 * 0.75, step), col.darkened(0.22))   # lado da sombra
				if r < rows * 0.5 and (r + int(cx)) % 3 == 0:     # fio de lava escorrendo na encosta
					var lx: float = floorf(cx - w2 * 0.45 + float((r * 7) % 5) * step * 0.5)
					c.draw_rect(Rect2(lx, floorf(y), step * 0.5, step), Color(_FORGE_RIM, 0.5 + 0.5 * glow))
			# rios de lava descendo a encosta depois da erupção (cabeça amarela, corpo laranja,
			# esfriando para vermelho e sumindo na rocha)
			if dt2 >= 0.0 and dt2 < 10.0:
				for fl in v.get("flows", []):
					var reach: int = mini(rows, int(dt2 / float(fl["speed"])))
					for r in range(1, reach):
						var frac2: float = float(r) / float(rows)
						var w3: float = hw * (0.12 + 0.88 * frac2)
						var fx: float = cx + w3 * float(fl["k"]) + sin(float(r) * 0.18 + float(fl["wob"])) * step * 0.6
						var fy: float = vp.y - h + float(r) * step
						var age: float = dt2 - float(r) * float(fl["speed"])
						var fcol: Color
						if age < 0.25:
							fcol = _HOT[0]
						elif age < 1.2:
							fcol = _HOT[1]
						elif age < 3.5:
							fcol = _HOT[2]
						else:
							fcol = Color("c63a22").lerp(col, clampf((age - 3.5) / 5.0, 0.0, 1.0))
						var fw: float = step if age < 1.2 else step * 0.5
						var fxx: float = floorf((fx - fw * 0.5) / (step * 0.5)) * step * 0.5
						c.draw_rect(Rect2(fxx, floorf(fy), fw, step), fcol)
						if age < 3.5:   # beirada escura do rio (crosta)
							c.draw_rect(Rect2(fxx + fw, floorf(fy), step * 0.5, step), Color("1d0d0e", 0.55))
			# cratera acesa (pulsando; explode na erupção)
			var ty: float = vp.y - h
			var cw: float = roundf(hw * 0.12 / step) * step
			var pulse: float = 0.35 + 0.15 * sin(_t * 1.7 + cx) + 0.5 * glow
			c.draw_rect(Rect2(floorf(cx - cw), floorf(ty - step * 0.5), cw * 2.0, step), Color(_HOT[1], pulse))
			if glow > 0.0:
				# jato de lava: blocos tremendo, núcleo claro e beiradas laranja/vermelhas, afinando no alto
				var jh: int = int(3.0 + 9.0 * glow)
				for j in range(jh):
					var jw: float = roundf(cw * (1.1 - 0.7 * float(j) / float(jh)) / (step * 0.5)) * step * 0.5
					var wob: float = roundf(sin(_t * 23.0 + float(j) * 1.7) * 1.0) * step * 0.5
					var jy: float = floorf(ty - step * float(j + 1))
					var ja: float = glow * (1.0 - 0.5 * float(j) / float(jh))
					c.draw_rect(Rect2(floorf(cx - jw + wob), jy, jw * 2.0, step), Color(_HOT[2], ja))
					c.draw_rect(Rect2(floorf(cx - jw * 0.5 + wob), jy, jw, step), Color(_HOT[0] if j % 3 else _HOT[1], ja))
				# clarão em losango em volta da cratera
				for d in range(1, 5):
					var ga: float = 0.22 * glow * (1.0 - float(d) / 5.0)
					c.draw_rect(Rect2(floorf(cx - cw - step * d), floorf(ty - step * 0.5 - step * d * 0.5), (cw + step * d) * 2.0, step * (1.0 + d)), Color(_HOT[1], ga))
	# partículas: 0 brasa/faísca, 1 fumaça, 2 bomba de lava (com rastro), 3 poça esfriando
	for p in _parts:
		var dt3: float = _t - float(p["t0"])
		if dt3 < 0.0:
			continue
		var life: float = maxf(0.001, float(p["life"]))
		var pos: Vector2 = p["p"]
		var fade: float = 1.0 - dt3 / life
		var kind: int = int(p["kind"])
		var col2: Color = p["c"]
		var sz: float = float(p["s"])
		match kind:
			1:
				sz *= 1.0 + 1.5 * dt3 / life
				c.draw_rect(Rect2(floorf(pos.x), floorf(pos.y), roundf(sz), roundf(sz)), Color(col2, 0.35 * fade))
			2:
				var tr2: Array = p["trail"]
				for ti in range(tr2.size()):
					var tq: Vector2 = tr2[ti]
					var ts: float = maxf(u, roundf(sz * (1.0 - float(ti) / 7.0)))
					var tc: Color = _HOT[2] if ti > 2 else _HOT[1]
					c.draw_rect(Rect2(floorf(tq.x - ts * 0.5), floorf(tq.y - ts * 0.5), ts, ts), Color(tc, 0.75 * (1.0 - float(ti) / 6.0)))
				var bs: float = roundf(sz)
				c.draw_rect(Rect2(floorf(pos.x - bs * 0.5), floorf(pos.y - bs * 0.5), bs, bs), Color("3a1c1c"))
				c.draw_rect(Rect2(floorf(pos.x - bs * 0.5) + u * 0.5, floorf(pos.y - bs * 0.5) + u * 0.5, maxf(u, bs - u), maxf(u, bs - u)), _HOT[1])
				c.draw_rect(Rect2(floorf(pos.x - u * 0.5), floorf(pos.y - u * 0.5), u, u), _HOT[0])
			3:
				var pc: Color = _HOT[2].lerp(Color("5a2420"), clampf(dt3 / life, 0.0, 1.0))
				c.draw_rect(Rect2(floorf(pos.x - sz), floorf(pos.y), sz * 2.0, u), Color(pc, fade))
			_:
				c.draw_rect(Rect2(floorf(pos.x), floorf(pos.y), roundf(sz), roundf(sz)), Color(col2, minf(1.0, fade * 1.5)))
	# bolas de fogo vindo na direção da tela (crescem e passam por cima do fundo)
	for m in _meteors:
		var k3: float = (_t - float(m["t0"])) / float(m["dur"])
		if k3 < 0.0 or k3 > 1.0:
			continue
		for ti2 in range(10, -1, -1):
			var kk: float = maxf(0.0, k3 - float(ti2) * 0.018)
			var mp: Vector2 = _meteor_pos(m, kk)
			var ms: float = roundf(float(m["s"]) * (1.0 + 2.2 * kk) * (1.0 - float(ti2) / 12.0))
			var mc: Color = _HOT[0] if ti2 == 0 else (_HOT[1] if ti2 < 4 else _HOT[2])
			var ma: float = 1.0 if ti2 == 0 else 0.8 * (1.0 - float(ti2) / 11.0)
			c.draw_rect(Rect2(floorf(mp.x - ms * 0.5), floorf(mp.y - ms * 0.5), ms, ms), Color(mc, ma))
		var hp: Vector2 = _meteor_pos(m, k3)
		var hs: float = roundf(float(m["s"]) * (1.0 + 2.2 * k3))
		c.draw_rect(Rect2(floorf(hp.x - hs * 0.5), floorf(hp.y - hs * 0.5), hs, roundf(hs * 0.35)), Color("3a1c1c", 0.9))   # crosta em cima
	# bigornas com martelo
	var pu: float = u * 2.0
	for a in _anvils:
		_draw_anvil(c, a, vp, pu)

func _draw_anvil(c: CanvasItem, a: Dictionary, vp: Vector2, pu: float) -> void:
	var o: Vector2 = _anvil_origin(a, vp, pu)
	var flip: bool = bool(a["flip"])
	for y in range(_ANVIL_MASK.size()):
		var row: String = _ANVIL_MASK[y]
		for x in range(row.length()):
			var ch: String = row[x]
			if ch == ".":
				continue
			var xx: int = (row.length() - 1 - x) if flip else x
			var col: Color = _ANVIL_BODY
			if ch == "T":
				col = Color("2a1416") if x % 3 else Color("341a1a")
			elif y == 0:
				col = _ANVIL_LIT
			c.draw_rect(Rect2(o + Vector2(xx, y) * pu, Vector2(pu, pu)), col)
	# peça em brasa em cima da bigorna (acende no golpe e vai esfriando)
	var sp: Vector2 = _anvil_strike_point(a, vp, pu)
	var k: float = fposmod(_anvil_cycle(a), 1.0)
	var heat: float = 1.0 - k * 0.6
	for i in range(-2, 3):
		c.draw_rect(Rect2(sp + Vector2(float(i) * pu - pu * 0.5, -pu), Vector2(pu, pu)), Color(_HOT[1 if absi(i) < 2 else 2], 0.55 + 0.45 * heat))
	if k < 0.08:
		var fl: float = 1.0 - k / 0.08
		var big: float = 1.6 if bool(a.get("strong", false)) else 1.0
		c.draw_rect(Rect2(sp + Vector2(-pu * 4.0 * big, -pu * 3.0 * big), Vector2(pu * 8.0 * big, pu * 3.0 * big)), Color(_HOT[0], 0.5 * fl))
	# marreta em T: cabo reto e cabeça atravessada na ponta (perpendicular ao cabo)
	var dir: float = -1.0 if flip else 1.0
	var pivot: Vector2 = sp + Vector2(dir * HAMMER_REACH * pu, -4.0 * pu)   # as mãos do ferreiro
	var base: float = PI if not flip else 0.0                              # do pivô para a cabeça
	var k2: float = fposmod(_anvil_cycle(a), 1.0)
	if k2 > 0.84:    # rastro na descida
		_draw_hammer(c, o, pivot, base + _hammer_angle(a, 0.035) * -dir, pu, 0.28)
		_draw_hammer(c, o, pivot, base + _hammer_angle(a, 0.018) * -dir, pu, 0.45)
	_draw_hammer(c, o, pivot, base + _hammer_angle(a) * -dir, pu, 1.0)

const HAMMER_REACH := 14.0   # pivô -> centro da cabeça, em pixels da arte
const _HAMMER_STEEL := [Color("2c1e22"), Color("54434a"), Color("7d6a70"), Color("a8949a")]
const _HAMMER_WOOD := [Color("4a2a1c"), Color("7a4a30"), Color("9a6440")]

# Desenha a marreta rasterizada célula a célula: para cada célula da grade de pixels em
# volta do pivô, gira de volta para o "espaço da marreta" e testa se cai no cabo ou na
# cabeça. Assim o cabo não fica furado e a cabeça continua um bloco cheio em qualquer ângulo.
func _draw_hammer(c: CanvasItem, grid_o: Vector2, pivot: Vector2, ang: float, pu: float, alpha: float) -> void:
	var D: float = HAMMER_REACH
	var r: float = D + 4.0
	var i0: int = int(floor((pivot.x - grid_o.x) / pu - r))
	var j0: int = int(floor((pivot.y - grid_o.y) / pu - r))
	var n: int = int(ceil(r * 2.0)) + 1
	var cs: float = cos(-ang)
	var sn: float = sin(-ang)
	# meia-largura do cabo que dá uma linha de 1 pixel sem furos e sem dobrar (estilo Bresenham)
	var half: float = 0.5 * (absf(cs) + absf(sn)) + 0.02
	for j in range(j0, j0 + n):
		for i in range(i0, i0 + n):
			var cell: Vector2 = grid_o + Vector2(i, j) * pu
			var d: Vector2 = (cell + Vector2(pu, pu) * 0.5 - pivot) / pu
			var lu: float = d.x * cs - d.y * sn     # ao longo do cabo (0 = mãos, D = cabeça)
			var lv: float = d.x * sn + d.y * cs     # atravessado
			var col: Color
			if lu >= D - 2.0 and lu <= D + 2.0 and absf(lv) <= 3.5:
				# cabeça: faces de bater mais escuras, quina de cima com brilho
				if absf(lv) > 2.8:
					col = _HAMMER_STEEL[0]
				elif lu > D + 1.2:
					col = _HAMMER_STEEL[1]
				elif lu < D - 1.2:
					col = _HAMMER_STEEL[3] if absf(lv) < 2.0 else _HAMMER_STEEL[2]
				else:
					col = _HAMMER_STEEL[2]
			elif lu >= -1.5 and lu < D - 2.0 and absf(lv) <= half:
				if lu < 2.0:
					col = _HAMMER_WOOD[0]                                 # empunhadura enrolada
				elif lu > D - 3.6:
					col = _HAMMER_STEEL[1]                                # cunha de ferro
				else:
					col = _HAMMER_WOOD[2] if lv < -0.1 else _HAMMER_WOOD[1]
			else:
				continue
			c.draw_rect(Rect2(cell, Vector2(pu, pu)), Color(col, alpha))
