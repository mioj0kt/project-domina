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
# Arte por bioma (assets/sprites/mapa/ilha/<bioma>/): pontas esquerda e direita,
# 4 faixas que encaixam entre si em qualquer ordem e 6 pendentes soltos.
const BIOME_DIR := "res://assets/sprites/mapa/ilha/%s/"
const PEND_MARGIN: int = 34          # espaço abaixo da arte para os pendentes
# deserto: areia escorrendo da rocha, feita grão a grão por código
const SAND_GRAVITY: float = 70.0     # px de arte / s²
const SAND_COLORS: Array[Color] = [Color("efdcaa"), Color("dcc08a"), Color("c49f66"), Color("a98250")]
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

## Bioma do mapa ("tutorial", "floresta", "deserto", "mina"). Defina antes de build().
var biome: String = ""
var _unit: int = 3
var _sand: bool = false              # deserto: desenha a areia caindo
var _sand_spots: Array = []          # [x, y, semente, comprimento, ritmo, intermitente]
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
	if biome != "" and ResourceLoader.exists((BIOME_DIR % biome) + "base_faixa_1.png"):
		_tex = _make_biome_texture(biome, w, _sand_spots)
		_height_px = float(ART_HEIGHT * unit)
		_sand = biome == "deserto" and not _sand_spots.is_empty()
	else:
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
	# deserto: fios de areia caindo da rocha, em loop
	if _sand:
		for sp in _sand_spots:
			_draw_sand_stream(sp)

# Cada fio solta grãos num ritmo fixo; o grão j nasceu em j/ritmo e cai com
# gravidade, abrindo um pouco para os lados e sumindo no fim do percurso.
# Tudo derivado do tempo, então não guarda estado nenhum.
func _draw_sand_stream(sp: Array) -> void:
	var u: float = float(_unit)
	var x0: float = float(sp[0])
	var y0: float = float(sp[1])
	var sd: int = int(sp[2])
	var length: float = float(sp[3])
	var rate: float = float(sp[4])
	var gaps: bool = bool(sp[5])
	var t: float = _t + float(sd % 997) * 0.37
	var max_age: float = sqrt(2.0 * length / SAND_GRAVITY)
	var newest: int = int(floor(t * rate))
	var oldest: int = int(floor((t - max_age) * rate))
	# fio contínuo grudado na rocha (some quando o fio pausa)
	if not gaps or _sand_on(newest, sd):
		draw_rect(Rect2(Vector2(x0, y0) * u, Vector2(1.0, 2.0) * u), SAND_COLORS[1])
	for j in range(oldest, newest + 1):
		if gaps and not _sand_on(j, sd):
			continue
		var age: float = t - float(j) / rate
		if age < 0.0:
			continue
		var h: int = absi(hash(Vector2i(j, sd)))
		var fall: float = 0.5 * SAND_GRAVITY * age * age + 6.0 * age
		if fall > length:
			continue
		var k: float = fall / length
		# começa num fio e abre num leque estreito
		var drift: float = (float(h % 7) - 3.0) / 3.0 * (0.4 + k * 2.2)
		var gx: float = round(x0 + drift)
		var gy: float = round(y0 + 1.0 + fall)
		var c: Color = SAND_COLORS[(h >> 3) % SAND_COLORS.size()]
		c.a = 1.0 - k * k
		draw_rect(Rect2(Vector2(gx, gy) * u, Vector2(u, u)), c)
		# grãos rápidos deixam um rastro de 1 px logo acima
		if k > 0.25 and (h >> 6) % 3 == 0:
			c.a *= 0.45
			draw_rect(Rect2(Vector2(gx, gy - 1.0) * u, Vector2(u, u)), c)

static func _sand_on(j: int, sd: int) -> bool:
	# rajadas: blocos de 8 grãos, ~60% ligados, variando por fio
	@warning_ignore("integer_division")
	var block: int = (j + sd) / 8
	return absi(hash(Vector2i(block, sd * 31))) % 5 < 3

func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_t += delta
	if _sand:
		queue_redraw()
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

static func _img(path: String) -> Image:
	var im: Image = (load(path) as Texture2D).get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im

# Base do bioma: ponta esquerda + faixas sorteadas (nunca a mesma duas vezes
# seguidas) + ponta direita, e pendentes grudados no contorno de baixo. O
# sorteio é fixo para o bioma e a largura, então a ilha não muda entre visitas.
static func _make_biome_texture(b: String, w: int, sand_out: Array) -> ImageTexture:
	var key := "%s_%d" % [b, w]
	var dir: String = BIOME_DIR % b
	var left: Image = _img(dir + "base_ponta_esq.png")
	var right: Image = _img(dir + "base_ponta_dir.png")
	var strips: Array = []
	for i in range(1, 5):
		if ResourceLoader.exists(dir + "base_faixa_%d.png" % i):
			strips.append(_img(dir + "base_faixa_%d.png" % i))
	var pends: Array = []
	for i in range(1, 7):
		if b == "deserto" and i == 1:
			continue  # fio de areia parado: no deserto a areia cai por código
		if ResourceLoader.exists(dir + "pendente_%d.png" % i):
			pends.append(_img(dir + "pendente_%d.png" % i))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var lw: int = left.get_width()
	var rw: int = right.get_width()
	var total: int = maxi(w, lw + rw)
	var h: int = ART_HEIGHT + PEND_MARGIN
	var img := Image.create(total, h, false, Image.FORMAT_RGBA8)
	img.blit_rect(left, Rect2i(0, 0, lw, mini(left.get_height(), ART_HEIGHT)), Vector2i(0, 0))
	var x: int = lw
	var last: int = -1
	while x < total - rw and not strips.is_empty():
		var k: int = rng.randi() % strips.size()
		if strips.size() > 1 and k == last:
			k = (k + 1 + rng.randi() % (strips.size() - 1)) % strips.size()
		last = k
		var st: Image = strips[k]
		var take: int = mini(st.get_width(), total - rw - x)
		img.blend_rect(st, Rect2i(0, 0, take, mini(st.get_height(), ART_HEIGHT)), Vector2i(x, 0))
		x += take
	img.blend_rect(right, Rect2i(0, 0, rw, mini(right.get_height(), ART_HEIGHT)), Vector2i(total - rw, 0))
	# contorno de baixo de cada coluna (último pixel opaco)
	var bottom: Array[int] = []
	for cx in range(total):
		var yb: int = -1
		for yy in range(ART_HEIGHT - 1, -1, -1):
			if img.get_pixel(cx, yy).a > 0.5:
				yb = yy
				break
		bottom.append(yb)
	# pendentes: espalhados, longe das pontas e uns dos outros
	var used: Array[int] = []
	if not pends.is_empty():
		@warning_ignore("integer_division")
		var n: int = clampi(total / 70, 4, 9)
		var tries: int = 0
		while used.size() < n and tries < 200:
			tries += 1
			@warning_ignore("integer_division")
			var px: int = rng.randi_range(lw / 2, total - rw / 2)
			var ok := true
			for u in used:
				if absi(u - px) < 18:
					ok = false
			if not ok or bottom[px] < 8:
				continue
			var pe: Image = pends[rng.randi() % pends.size()]
			var pw: int = pe.get_width()
			@warning_ignore("integer_division")
			var x0: int = clampi(px - pw / 2, 0, total - pw)
			# gruda pelo ponto mais alto do contorno embaixo da peça (2 px de encaixe)
			var top: int = ART_HEIGHT
			for cx2 in range(x0, x0 + pw):
				if bottom[cx2] >= 0:
					top = mini(top, bottom[cx2])
			if top >= ART_HEIGHT:
				continue
			img.blend_rect(pe, Rect2i(0, 0, pw, pe.get_height()), Vector2i(x0, maxi(0, top - 2)))
			used.append(px)
	# deserto: onde a areia escorre (fora dos pendentes)
	sand_out.clear()
	if b == "deserto":
		var tries2: int = 0
		@warning_ignore("integer_division")
		var want: int = clampi(total / 55, 4, 10)
		while sand_out.size() < want and tries2 < 400:
			tries2 += 1
			@warning_ignore("integer_division")
			var sx: int = rng.randi_range(lw / 2, total - rw / 2)
			if bottom[sx] < 20:
				continue
			# desce até a ponta mais baixa por perto: a areia escorre das pontas
			for _i in range(6):
				var best: int = sx
				for dx in [-2, -1, 1, 2]:
					var nx: int = clampi(sx + dx, 0, total - 1)
					if bottom[nx] > bottom[best]:
						best = nx
				sx = best
			var near := false
			for u in used:
				if absi(u - sx) < 10:
					near = true
			for sp in sand_out:
				if absi(int(sp[0]) - sx) < 16:
					near = true
			if not near:
				var gaps: bool = rng.randf() < 0.55
				sand_out.append([sx, bottom[sx], rng.randi() % 100000, rng.randf_range(26.0, 54.0),
					rng.randf_range(12.0, 18.0) if gaps else rng.randf_range(9.0, 15.0), gaps])
	return ImageTexture.create_from_image(img)

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
