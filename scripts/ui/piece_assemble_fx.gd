class_name PieceAssembleFx
extends Node2D
## O inverso do estilhaço da captura: os 4 pedaços da peça voam de fora, aceleram
## e se encaixam com impacto (clarão, onda de choque, faíscas, "pop").
## (0,0) = centro da peça; size_px = lado da peça na tela.

signal impact
signal finished

const FLY_TIME: float = 0.95
const AFTER_TIME: float = 0.9

var size_px: float = 128.0
var alpha: float = 1.0
var _shards: Array = []       # {tex, r: Rect2 (px da textura), home, dir, delay, rot0}
var _t: float = -1.0          # <0 = parado/invisível
var _impacted: bool = false
var _sparks: Array = []       # {ang, spd, life}
var _tex_w: float = 32.0

func setup(tex: Texture2D, p_size_px: float) -> void:
	size_px = p_size_px
	_shards.clear()
	if tex == null:
		return
	var tw: float = tex.get_width()
	var th: float = tex.get_height()
	_tex_w = tw
	var sx: float = floorf(tw * 0.5 + randf_range(-3.0, 3.0))
	var sy: float = floorf(th * 0.5 + randf_range(-3.0, 3.0))
	var rects: Array[Rect2] = [
		Rect2(0, 0, sx, sy), Rect2(sx, 0, tw - sx, sy),
		Rect2(0, sy, sx, th - sy), Rect2(sx, sy, tw - sx, th - sy)]
	var dirs: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	var k: float = size_px / tw
	for i in 4:
		var r: Rect2 = rects[i]
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = r
		var centre: Vector2 = (r.position + r.size * 0.5) * k - Vector2(size_px, size_px) * 0.5
		_shards.append({"tex": at, "size": r.size * k, "home": centre,
			"dir": dirs[i].normalized().rotated(randf_range(-0.3, 0.3)),
			"delay": randf_range(0.0, 0.16), "rot0": randf_range(3.0, 6.0) * (1.0 if i % 2 == 0 else -1.0)})
	_sparks.clear()
	for i in 26:
		_sparks.append({"ang": randf() * TAU, "spd": randf_range(0.7, 2.2), "life": randf_range(0.35, 0.8)})

func play() -> void:
	_t = 0.0
	_impacted = false

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if not _impacted and _t >= FLY_TIME + 0.16:
		_impacted = true
		impact.emit()
	if _t >= FLY_TIME + 0.16 + AFTER_TIME:
		_t = -1.0
		finished.emit()
		return
	queue_redraw()

# Disco pixelado: quadradinhos numa grade (em vez de um círculo suave).
func _pix_disc(radius: float, col: Color, px: float = 6.0) -> void:
	var n: int = int(ceil(radius / px))
	for iy in range(-n, n + 1):
		for ix in range(-n, n + 1):
			var c := Vector2(ix, iy) * px
			if c.length() <= radius:
				draw_rect(Rect2(c - Vector2(px, px) * 0.5, Vector2(px, px)), col)

func _draw() -> void:
	if _shards.is_empty():
		return
	var imp: float = _t - (FLY_TIME + 0.16)     # tempo desde o impacto (<0 antes)
	var a: float = alpha
	# antecipação: brilho que cresce no ponto de encaixe
	if imp < 0.0 and _t >= 0.0:
		var g: float = clampf(_t / FLY_TIME, 0.0, 1.0)
		_pix_disc(size_px * (0.15 + 0.35 * g), Color(1.0, 0.85, 0.5, 0.10 * g * a))
		_pix_disc(size_px * (0.08 + 0.18 * g), Color(1.0, 0.95, 0.8, 0.16 * g * a))
	# pop da peça montada logo após o impacto
	var pop: float = 1.0
	if imp >= 0.0:
		pop = 1.0 + 0.2 * maxf(0.0, 1.0 - imp / 0.28) * cos(imp * 22.0)
	for s in _shards:
		var d: float = clampf((_t - float(s["delay"])) / FLY_TIME, 0.0, 1.0)
		var e: float = pow(d, 2.4)                 # acelera como uma queda
		var far: float = size_px * 4.2
		var off: Vector2 = (s["dir"] as Vector2) * far * (1.0 - e)
		var rot: float = float(s["rot0"]) * (1.0 - e)
		var home: Vector2 = s["home"]
		var sz: Vector2 = s["size"]
		# rastro (3 ecos) enquanto viaja
		if d > 0.0 and d < 1.0:
			for n in 3:
				var db: float = maxf(d - 0.035 * float(n + 1), 0.0)
				var eb: float = pow(db, 2.4)
				var ob: Vector2 = (s["dir"] as Vector2) * far * (1.0 - eb)
				draw_set_transform(home * pop + ob, float(s["rot0"]) * (1.0 - eb), Vector2.ONE)
				draw_texture_rect(s["tex"], Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, a * 0.22 * (1.0 - 0.3 * n)))
		draw_set_transform(home * pop + off, rot, Vector2(pop, pop))
		draw_texture_rect(s["tex"], Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, a * clampf(d * 6.0, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if imp >= 0.0:
		# clarão
		var f: float = maxf(0.0, 1.0 - imp / 0.22)
		if f > 0.0:
			_pix_disc(size_px * (0.55 + 0.5 * (1.0 - f)), Color(1, 0.97, 0.88, 0.75 * f * a))
		# onda de choque pixelada (dois anéis)
		for ring in 2:
			var rt: float = imp - 0.05 * ring
			if rt <= 0.0 or rt > 0.6:
				continue
			var rp: float = rt / 0.6
			var rad: float = size_px * (0.55 + 2.2 * (1.0 - pow(1.0 - rp, 2.0)))
			var px: float = 6.0 if ring == 0 else 4.0
			var cnt: int = int(rad * TAU / px)
			var col := Color(1.0, 0.86, 0.52, (1.0 - rp) * (0.85 if ring == 0 else 0.5) * a)
			for i in cnt:
				var an: float = TAU * float(i) / float(cnt)
				var p: Vector2 = Vector2.from_angle(an) * rad
				draw_rect(Rect2(p - Vector2(px, px) * 0.5, Vector2(px, px)), col)
		# faíscas
		for sp in _sparks:
			var lt: float = imp / float(sp["life"])
			if lt <= 0.0 or lt >= 1.0:
				continue
			var dist: float = size_px * 0.5 + float(sp["spd"]) * size_px * 0.9 * (1.0 - pow(1.0 - lt, 2.0))
			var p2: Vector2 = Vector2.from_angle(float(sp["ang"])) * dist
			var ps: float = 5.0 * (1.0 - lt) + 2.0
			draw_rect(Rect2(p2 - Vector2(ps, ps) * 0.5, Vector2(ps, ps)), Color(1.0, 0.9, 0.6, (1.0 - lt) * a))
