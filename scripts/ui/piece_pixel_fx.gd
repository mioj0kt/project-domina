class_name PiecePixelFx
extends Node2D
## Peça do jogador desfeita em pixels.
##  - play_dissolve(): o receptáculo se desfaz e os pixels sobem (rumo ao Oráculo).
##  - play_assemble(): o Oráculo refaz o receptáculo; os pixels descem e se juntam.
## (0,0) é o centro da peça; size_px é o lado dela na tela.

signal finished

enum Mode { IDLE, DISSOLVE, ASSEMBLE }

var mode: int = Mode.IDLE
var size_px: float = 128.0
var alpha: float = 1.0          # opacidade global (fade do conjunto)
var shake: float = 0.0          # tremor dos pixels em repouso (px de tela)
var tint: Color = Color(1, 1, 1, 1)

var _cells: Array = []          # {h: Vector2 (casa), c: Color, d: float, r: float, s: Vector2, w: float}
var _cell: float = 4.0
var _t: float = 0.0
var _dur: float = 1.0
var _dist: float = 800.0
var _done: bool = false
var _rng := RandomNumberGenerator.new()

func setup(tex: Texture2D, p_size_px: float) -> void:
	size_px = p_size_px
	_cells.clear()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var h: int = img.get_height()
	_cell = size_px / float(w)
	_rng.seed = 1337
	for y in h:
		for x in w:
			var col: Color = img.get_pixel(x, y)
			if col.a < 0.5:
				continue
			var home := Vector2((x + 0.5) * _cell - size_px * 0.5, (y + 0.5) * _cell - size_px * 0.5)
			_cells.append({
				"h": home, "c": col,
				"d": float(y) / float(h),            # 0 topo .. 1 base
				"r": _rng.randf(),                    # sorteio 1
				"s": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf()),
				"w": _rng.randf_range(-1.0, 1.0),
			})
	queue_redraw()

func play_dissolve(dur: float, rise_px: float) -> void:
	mode = Mode.DISSOLVE
	_dur = maxf(dur, 0.1)
	_dist = rise_px
	_t = 0.0
	_done = false
	shake = 0.0

func play_assemble(dur: float, spread_px: float) -> void:
	mode = Mode.ASSEMBLE
	_dur = maxf(dur, 0.1)
	_dist = spread_px
	_t = 0.0
	_done = false
	shake = 0.0

func progress() -> float:
	return clampf(_t / _dur, 0.0, 1.0)

func _process(delta: float) -> void:
	if mode == Mode.IDLE and shake <= 0.0:
		return
	if mode != Mode.IDLE and not _done:
		_t += delta
		if _t >= _dur:
			_t = _dur
			_done = true
			finished.emit()
	elif mode == Mode.IDLE:
		_t += delta
	queue_redraw()

static func _smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _draw() -> void:
	var tt: float = _t
	var n: int = _cells.size()
	for i in n:
		var cd: Dictionary = _cells[i]
		var home: Vector2 = cd["h"]
		var col: Color = cd["c"] * tint
		var pos: Vector2 = home
		var a: float = alpha
		var sz: float = _cell
		match mode:
			Mode.IDLE:
				if shake > 0.0:
					var j: float = tt * 38.0 + float(i) * 1.7
					pos += Vector2(sin(j), cos(j * 1.31)) * shake * (0.4 + float(cd["r"]))
			Mode.DISSOLVE:
				# começa pelo topo; cada pixel espera a vez e sobe acelerando
				var delay: float = (float(cd["d"]) * 0.62 + float(cd["r"]) * 0.22) * _dur * 0.55
				var life: float = _dur * 0.45
				var p: float = clampf((tt - delay) / life, 0.0, 1.0)
				if p > 0.0:
					var sv: Vector2 = cd["s"]
					var rise: float = (p * 0.25 + p * p * 0.75) * _dist * (0.55 + sv.y * 0.45)
					pos = home + Vector2(sv.x * 46.0 * p + sin(p * 9.0 + float(i)) * 8.0 * p, -rise)
					a *= 1.0 - _smooth(0.7, 1.0, p)
					sz = _cell * (1.0 - 0.45 * p)
				else:
					# antes de soltar: treme levemente, já "instável"
					var j2: float = tt * 40.0 + float(i) * 1.7
					var k: float = clampf(tt / (delay + 0.001), 0.0, 1.0) * 0.9
					pos += Vector2(sin(j2), cos(j2 * 1.31)) * k
			Mode.ASSEMBLE:
				var delay2: float = (1.0 - float(cd["d"])) * 0.30 * _dur + float(cd["r"]) * 0.12 * _dur
				var life2: float = _dur * 0.58
				var p2: float = clampf((tt - delay2) / life2, 0.0, 1.0)
				var sv2: Vector2 = cd["s"]
				var ang: float = -PI * 0.5 + sv2.x * 1.9
				var far: Vector2 = Vector2.from_angle(ang) * _dist * (0.5 + float(cd["r"]) * 0.9)
				var e: float = 1.0 - pow(1.0 - p2, 3.0)
				var swirl: float = (1.0 - e) * float(cd["w"]) * 0.9
				pos = home + far.rotated(swirl) * (1.0 - e)
				a *= _smooth(0.0, 0.18, p2)
				# rastro: um pixel fantasma um pouco atrás, só enquanto viaja
				if p2 > 0.0 and p2 < 1.0:
					var pb: float = maxf(p2 - 0.08, 0.0)
					var eb: float = 1.0 - pow(1.0 - pb, 3.0)
					var pos_b: Vector2 = home + far.rotated((1.0 - eb) * float(cd["w"]) * 0.9) * (1.0 - eb)
					draw_rect(Rect2(pos_b - Vector2(sz, sz) * 0.4, Vector2(sz, sz) * 0.8), Color(col.r, col.g, col.b, a * 0.28))
		if a <= 0.01:
			continue
		draw_rect(Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col.r, col.g, col.b, col.a * a))
