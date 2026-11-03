class_name IslandBase
extends Node2D

# Base rochosa que faz o mapa parecer uma ilha flutuando no espaço: um bloco de
# rocha (ameixa) com borda dourada, afunilando para baixo, com estalactites e
# cristais violeta. Gerada proceduralmente (pixel art, escala inteira) e
# determinística para a mesma largura. Também faz o "flutuar" do mapa: balança
# a câmera em passos de pixel, então tudo (tabuleiro, nós, base) se move junto
# e os cliques continuam alinhados; o céu estrelado (tela) fica parado.

const BOB_STEPS: int = 2            # amplitude em "pixels de arte"
const BOB_PERIOD: float = 11.0      # segundos por ciclo (lento)

# Arte pronta: ponta esquerda (a direita é o espelho) + faixa repetível.
const CAP_PATH := "res://assets/sprites/mapa/ilha/base_ponta.png"
const STRIP_PATH := "res://assets/sprites/mapa/ilha/base_faixa.png"
const ART_HEIGHT: int = 96
const OVERLAP_UNITS: int = 0        # quanto a base sobe por baixo da moldura

const C_OUTLINE := Color("1a1220")
const C_LIP := Color("d9a441")
const C_LIP_DARK := Color("9a6f2a")
const C_ROCK_1 := Color("5a4561")
const C_ROCK_2 := Color("3a2b41")
const C_ROCK_3 := Color("241a2b")
const C_HIGHLIGHT := Color("7c6489")
const C_CRYSTAL := Color("8a5cc0")
const C_CRYSTAL_TIP := Color("b58be0")

static var _cache: Dictionary = {}

var _unit: int = 3
var _tex: ImageTexture = null
var _camera: Camera2D = null
var _t: float = 0.0
var _height_px: float = 0.0

# Altura (em pixels de mundo) que a base ocupa abaixo do tabuleiro.
static func _has_art() -> bool:
	return ResourceLoader.exists(CAP_PATH) and ResourceLoader.exists(STRIP_PATH)

static func _height_units(w_units: int) -> int:
	if _has_art():
		return ART_HEIGHT
	return clampi(int(w_units * 0.2), 40, 80)

func build(board_rect: Rect2, unit: int, camera: Camera2D) -> void:
	_unit = unit
	_camera = camera
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var w: int = int(ceil(board_rect.size.x / float(unit)))
	_tex = _make_art_texture(w) if _has_art() else _make_texture(w, _height_units(w))
	_height_px = float(_tex.get_height() * unit)
	position = Vector2(board_rect.position.x, board_rect.end.y - float(unit) * float(OVERLAP_UNITS))
	queue_redraw()

func set_camera(camera: Camera2D) -> void:
	_camera = camera

func extra_height() -> float:
	return _height_px - float(_unit) * float(OVERLAP_UNITS)

func _draw() -> void:
	if _tex != null:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, _tex.get_size() * float(_unit)), false)

func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_t += delta
	var steps: float = round(sin(_t * TAU / BOB_PERIOD) * float(BOB_STEPS))
	_camera.offset = Vector2(0.0, steps * float(_unit))

# Monta a base na largura exata: ponta + faixa repetida (cortada no fim) + ponta espelhada.
static func _make_art_texture(w: int) -> ImageTexture:
	var key := Vector2i(w, -1)
	if _cache.has(key):
		return _cache[key]
	var cap: Image = (load(CAP_PATH) as Texture2D).get_image()
	var strip: Image = (load(STRIP_PATH) as Texture2D).get_image()
	cap.convert(Image.FORMAT_RGBA8)
	strip.convert(Image.FORMAT_RGBA8)
	var cw: int = cap.get_width()
	var h: int = maxi(cap.get_height(), strip.get_height())
	var total: int = maxi(w, cw * 2)
	var img := Image.create(total, h, false, Image.FORMAT_RGBA8)
	var mid: int = total - cw * 2
	var x: int = cw
	while x < cw + mid:
		var take: int = mini(strip.get_width(), cw + mid - x)
		img.blit_rect(strip, Rect2i(0, 0, take, strip.get_height()), Vector2i(x, 0))
		x += take
	img.blit_rect(cap, Rect2i(0, 0, cw, cap.get_height()), Vector2i(0, 0))
	var flipped: Image = cap.duplicate()
	flipped.flip_x()
	img.blit_rect(flipped, Rect2i(0, 0, cw, flipped.get_height()), Vector2i(total - cw, 0))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _make_texture(w: int, h: int) -> ImageTexture:
	var key := Vector2i(w, h)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + w * 13 + h
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 0.09
	# Perfil: profundidade da rocha em cada coluna.
	var depth: Array[int] = []
	for x in range(w):
		var t: float = absf(2.0 * (float(x) + 0.5) / float(w) - 1.0)
		var d: float = float(h - 14) * pow(maxf(0.0, 1.0 - pow(t, 2.4)), 0.8)
		d += noise.get_noise_1d(float(x)) * 5.0
		depth.append(maxi(3, int(round(d))) + 3)
	# Estalactites.
	@warning_ignore("integer_division")
	var n_stal: int = maxi(6, w / 14)
	for i in range(n_stal):
		var cx: int = rng.randi_range(8, w - 9)
		var seg_len: int = rng.randi_range(5, 13)
		var half_w: int = rng.randi_range(1, 3)
		for dx in range(-half_w, half_w + 1):
			var x: int = cx + dx
			@warning_ignore("integer_division")
			var ext: int = seg_len - absi(dx) * (seg_len / (half_w + 1))
			depth[x] = mini(h - 2, maxi(depth[x], depth[cx] + ext - 2))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in range(w):
		var dcol: int = depth[x]
		var lit: bool = float(x) < float(w) * 0.5
		for y in range(mini(dcol, h)):
			var col: Color
			if y == 0 or y == 1:
				col = C_LIP
			elif y == 2:
				col = C_LIP_DARK
			else:
				var r: float = float(y) / float(maxi(1, h))
				var n: float = noise.get_noise_2d(float(x) * 1.7, float(y) * 2.3) * 0.12
				var v: float = r + n + (-0.04 if lit else 0.04)
				if v < 0.34:
					col = C_ROCK_1
				elif v < 0.66:
					col = C_ROCK_2
				else:
					col = C_ROCK_3
				# Pontos de luz espalhados (só no lado iluminado).
				if lit and col == C_ROCK_1 and ((x * 7 + y * 13) % 17 == 0):
					col = C_HIGHLIGHT
			img.set_pixel(x, y, col)
	# Contorno escuro nas bordas da silhueta (abaixo e nos lados).
	var outlined := img.duplicate() as Image
	for x in range(w):
		for y in range(h):
			if img.get_pixel(x, y).a > 0.0:
				var edge := false
				for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
					var nx: int = x + off.x
					var ny: int = y + off.y
					if nx < 0 or nx >= w or ny >= h or img.get_pixel(nx, ny).a == 0.0:
						edge = true
				if edge and y > 2:
					outlined.set_pixel(x, y, C_OUTLINE)
	img = outlined
	# Cristais violeta pendurados / espetados na rocha.
	@warning_ignore("integer_division")
	for i in range(maxi(3, w / 40)):
		var cx2: int = rng.randi_range(12, w - 13)
		var y0: int = depth[cx2] - 1
		var clen: int = rng.randi_range(3, 6)
		for k in range(clen):
			var yy: int = y0 + k
			if yy < h:
				img.set_pixel(cx2, yy, C_CRYSTAL_TIP if k == clen - 1 else C_CRYSTAL)
				if k < clen - 2 and cx2 + 1 < w:
					img.set_pixel(cx2 + 1, yy, C_CRYSTAL)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
