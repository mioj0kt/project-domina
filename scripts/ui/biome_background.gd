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
		"patterns": ["losango", "xadrez", "escamas", "estrelas", "diagonal", "trama"],
		"fireflies": Color("d9a441"), "n_fireflies": 22,
		"leaves": [Color("5b8f4e"), Color("3f6b3a"), Color("d0802f")], "n_leaves": 14,
		"spores": Color("7fa874"), "n_spores": 46,
		# Cores das transições de cena (SceneTransition): a, b, chefe, detalhe.
		"trans_a": Color("16201c"), "trans_b": Color("2a3a31"), "trans_boss": Color("2a1418"), "trans_edge": Color("5b8f4e"),
	},
	"deserto": {
		"top": Color("2b2118"), "bottom": Color("3a2a22"),
		"line": Color("4d3b2a"), "dot": Color("6e5636"), "fill": Color("33261c"),
		"patterns": ["losango", "xadrez", "escamas", "diagonal", "trama"],
		# Brilhos de areia ao vento (no lugar dos vaga-lumes) e grãos subindo.
		"fireflies": Color("f2cf6b"), "n_fireflies": 12,
		"leaves": [Color("cdb078"), Color("a88a58"), Color("e3c98a")], "n_leaves": 0,
		"spores": Color("d9bb82"), "n_spores": 64,
		"trans_a": Color("2b2118"), "trans_b": Color("5a4530"), "trans_boss": Color("3a1a14"), "trans_edge": Color("d9a441"),
	},
	"tutorial": {
		"top": Color("231a2a"), "bottom": Color("1a1420"),
		"line": Color("3a2b41"), "dot": Color("5a4561"), "fill": Color("2a2031"),
		"patterns": ["losango", "xadrez", "escamas", "estrelas", "diagonal", "trama"],
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
# nome de PATTERNS ("losango", "xadrez", "escamas", "estrelas", "diagonal", "trama").
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

	# Partículas (posições em fração da tela).
	for i in range(int(_cfg["n_fireflies"])):
		_flies.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"rate": rng.randf_range(0.5, 1.4), "ax": rng.randf_range(14.0, 40.0), "ay": rng.randf_range(10.0, 30.0)})
	for i in range(int(_cfg["n_leaves"])):
		_leaves.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"fall": rng.randf_range(10.0, 22.0), "sway": rng.randf_range(16.0, 40.0),
			"col": rng.randi() % (_cfg["leaves"] as Array).size(), "u": 3 + (i % 2)})
	for i in range(int(_cfg["n_spores"])):
		_spores.append({"x": rng.randf(), "y": rng.randf(), "ph": rng.randf() * TAU,
			"rise": rng.randf_range(5.0, 14.0), "u": 2 + (i % 2)})

func _process(delta: float) -> void:
	_t += delta
	_scroll += SCROLL_SPEED * delta
	_canvas.queue_redraw()

const PATTERNS: Array[String] = ["losango", "xadrez", "escamas", "estrelas", "diagonal", "trama"]

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
	# Esporos subindo (mais ao fundo, bem discretos).
	var spore_col: Color = _cfg["spores"]
	for s in _spores:
		var su: float = float(s["u"])
		var y: float = fposmod(float(s["y"]) * vp.y - _t * float(s["rise"]) * 1.0, vp.y)
		var x: float = float(s["x"]) * vp.x + sin(_t * 0.5 + float(s["ph"])) * 10.0
		var a: float = 0.25 + 0.2 * (sin(_t * 0.8 + float(s["ph"])) * 0.5 + 0.5)
		_canvas.draw_rect(Rect2(floorf(x), floorf(y), su, su), Color(spore_col.r, spore_col.g, spore_col.b, a))
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
	# Vaga-lumes: quadradinho que pulsa em 4 passos, com halo fraco.
	var fc: Color = _cfg["fireflies"]
	for f in _flies:
		var x: float = float(f["x"]) * vp.x + sin(_t * 0.35 * float(f["rate"]) + float(f["ph"])) * float(f["ax"])
		var y: float = float(f["y"]) * vp.y + cos(_t * 0.28 * float(f["rate"]) + float(f["ph"]) * 1.7) * float(f["ay"])
		var pulse: float = sin(_t * float(f["rate"]) * 1.6 + float(f["ph"])) * 0.5 + 0.5
		var px: float = floorf(x)
		var py: float = floorf(y)
		_canvas.draw_rect(Rect2(px - u, py - u, u * 3.0, u * 3.0), Color(fc.r, fc.g, fc.b, 0.07 + 0.10 * pulse))
		_canvas.draw_rect(Rect2(px, py, u, u), Color(fc.r, fc.g, fc.b, 0.35 + 0.65 * pulse))
