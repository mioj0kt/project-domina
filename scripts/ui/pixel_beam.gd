class_name PixelBeam
extends RefCounted

# Efeitos de luz em PIXEL ART: feixes em cunha com dither de Bayer (nearest),
# discos/anéis/linhas feitos de quadrados alinhados à grade. Use sempre com
# `texture_filter = TEXTURE_FILTER_NEAREST` no CanvasItem que desenha.

const BEAM_W: int = 288
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
static var _cache: Dictionary = {}

# Textura de um feixe: ponta no canto esquerdo-centro, abrindo para a direita
# e sumindo (dither) conforme se afasta. Pixels de núcleo ficam mais claros.
static func beam_tex(half: float) -> ImageTexture:
	var key: int = int(roundf(half * 100.0))
	if _cache.has(key):
		return _cache[key]
	var h: float = float(key) / 100.0
	var rows: int = int(ceil(BEAM_W * tan(h))) * 2 + 3
	var cy: float = rows / 2.0
	var img := Image.create(BEAM_W, rows, false, Image.FORMAT_RGBA8)
	for x in range(BEAM_W):
		var wd: float = maxf(0.6, (x + 1.0) * tan(h))
		for y in range(rows):
			var dy: float = absf(y + 0.5 - cy)
			if dy > wd:
				continue
			var fade: float = 1.0 - float(x) / BEAM_W
			var lat: float = 1.0 - dy / wd
			var inten: float = pow(fade, 0.8) * pow(lat, 0.6)
			var th: float = (float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0
			if inten > th * 0.9:
				var core: bool = inten > 0.62 and lat > 0.45
				var v: float = 1.0 if core else 0.62
				img.set_pixel(x, y, Color(v, v, v, 1.0))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

static func beam(g: CanvasItem, origin: Vector2, ang: float, length: float, half: float, col: Color) -> void:
	var t: ImageTexture = beam_tex(half)
	var s: float = length / float(BEAM_W)
	var hh: float = float(t.get_height())
	g.draw_set_transform(origin, ang, Vector2(s, s))
	g.draw_texture_rect(t, Rect2(0.0, -hh * 0.5, float(BEAM_W), hh), false, col)
	g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _snap(v: float, px: float) -> float:
	return roundf(v / px) * px

# Disco cheio feito de linhas de quadrados.
static func disc(g: CanvasItem, c: Vector2, r: float, col: Color, px: float = 6.0) -> void:
	var n: int = int(r / px)
	var cx: float = _snap(c.x, px)
	var cy: float = _snap(c.y, px)
	for ry in range(-n, n + 1):
		var y: float = float(ry) * px
		var half: float = sqrt(maxf(r * r - y * y, 0.0))
		half = floorf(half / px) * px
		if half <= 0.0:
			continue
		g.draw_rect(Rect2(cx - half, cy + y, half * 2.0, px), col)

# Anel de quadrados (espessura em número de quadrados).
static func ring(g: CanvasItem, c: Vector2, r: float, col: Color, px: float = 6.0, thick: int = 1, squash: float = 1.0) -> void:
	var steps: int = maxi(12, int(TAU * r / px * 1.2))
	var last := Vector2(INF, INF)
	for i in range(steps):
		var a: float = TAU * float(i) / float(steps)
		var p := Vector2(_snap(c.x + cos(a) * r, px), _snap(c.y + sin(a) * r * squash, px))
		if p == last:
			continue
		last = p
		g.draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px) * float(thick)), col)

# Linha de quadrados de a até b.
static func line(g: CanvasItem, a: Vector2, b: Vector2, col: Color, px: float = 6.0, thick: int = 1) -> void:
	var d: float = a.distance_to(b)
	var n: int = maxi(1, int(d / px))
	var last := Vector2(INF, INF)
	for i in range(n + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(n))
		p = Vector2(_snap(p.x, px), _snap(p.y, px))
		if p == last:
			continue
		last = p
		g.draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px) * float(thick)), col)
