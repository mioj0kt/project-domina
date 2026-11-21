class_name MapScrollHint
extends CanvasLayer

# Indica que o mapa rola (arrastar / rodinha):
#  - uma barra fininha no canto direito da tela com o trecho visível (e o chefe
#    no topo, a peça do jogador e o começo marcados nela);
#  - setinhas de pixel pulsando na borda de cima/baixo quando há mapa naquela direção;
#  - na primeira vez, uma plaquinha "ARRASTE PARA VER O MAPA" com um mouse
#    mexendo, que some de vez quando o jogador rola o mapa pela primeira vez
#    (MetaProgress.map_drag_seen).

const PX: float = 3.0
const FONT := preload("res://assets/fonts/m5x7.ttf")
const C_OUT := Color("1f161d")
const C_TRACK := Color("31252f")
const C_TRACK_HI := Color("4a3a46")
const C_THUMB := Color("e4d9bc")
const C_THUMB_SH := Color("b9a983")
const C_GOLD := Color("f0d27a")
const C_TXT := Color("efe6cf")
const LEARN_PX: float = 160.0     # quanto o jogador precisa rolar para a dica sumir de vez

var map_view: Node = null
var _canvas: Node2D
var _t: float = 0.0
var _hint_a: float = 0.0
var _hint_on: bool = false
var _scrolled_px: float = 0.0
var _last_y: float = INF
var _ready_delay: float = 1.4     # a dica só aparece depois da entrada no mapa

func _ready() -> void:
	layer = 105
	_canvas = Node2D.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_all)
	add_child(_canvas)
	_hint_on = not MetaProgress.map_drag_seen

func _process(delta: float) -> void:
	_t += delta
	var info: Dictionary = map_view.get_scroll_info() if map_view != null else {}
	if not info.is_empty() and info["scrollable"]:
		var y: float = info["y"]
		if _last_y != INF and info["manual"]:
			_scrolled_px += absf(y - _last_y)
		_last_y = y
		if _hint_on and _scrolled_px >= LEARN_PX:
			_hint_on = false
			MetaProgress.map_drag_seen = true
			MetaProgress.save_data()
	_ready_delay = maxf(0.0, _ready_delay - delta)
	var want: float = 1.0 if (_hint_on and _ready_delay <= 0.0 and not info.is_empty() and info["scrollable"] and not info["busy"]) else 0.0
	_hint_a = move_toward(_hint_a, want, delta * (2.5 if want > 0.0 else 3.5))
	_canvas.queue_redraw()

func _r(p: Vector2, s: Vector2, c: Color) -> void:
	_canvas.draw_rect(Rect2(p.round(), s), c)

func _draw_all() -> void:
	if map_view == null:
		return
	var info: Dictionary = map_view.get_scroll_info()
	if info.is_empty() or not info["scrollable"]:
		return
	var vs: Vector2 = _canvas.get_viewport_rect().size
	var top_y: float = info["min"]
	var bot_y: float = info["max"]
	var y: float = info["y"]
	var k_vis: float = clampf(info["half"] * 2.0 / (bot_y - top_y + info["half"] * 2.0), 0.08, 1.0)
	var at_top: bool = y <= top_y + 2.0
	var at_bot: bool = y >= bot_y - 2.0
	_draw_track(vs, info, k_vis)
	_draw_chevrons(vs, at_top, at_bot)
	if _hint_a > 0.01:
		_draw_hint(vs, _hint_a)

# Barra de rolagem: trilho escuro com contorno, polegar creme do trecho visível,
# coroa no topo (o chefe), bolinha embaixo (o começo) e um losango dourado na peça.
func _draw_track(vs: Vector2, info: Dictionary, k_vis: float) -> void:
	var w: float = 4.0 * PX
	var x: float = vs.x - w - 10.0 * PX
	var y0: float = 120.0
	var h: float = vs.y - 120.0 - 150.0
	_r(Vector2(x - PX, y0 - PX), Vector2(w + PX * 2.0, h + PX * 2.0), C_OUT)
	_r(Vector2(x, y0), Vector2(w, h), C_TRACK)
	_r(Vector2(x, y0), Vector2(PX, h), C_TRACK_HI)
	var span: float = info["max"] - info["min"]
	var f: float = 0.0 if span <= 0.0 else (info["y"] - info["min"]) / span
	var th: float = maxf(8.0 * PX, h * k_vis)
	var ty: float = y0 + (h - th) * f
	_r(Vector2(x, ty), Vector2(w, th), C_THUMB)
	_r(Vector2(x + w - PX, ty), Vector2(PX, th), C_THUMB_SH)
	_r(Vector2(x, ty + th - PX), Vector2(w, PX), C_THUMB_SH)
	# riscos de "pegada" no meio do polegar
	for i in range(3):
		_r(Vector2(x + PX, ty + th / 2.0 + (float(i) - 1.0) * PX * 2.0 - PX * 0.5), Vector2(w - PX * 2.0, PX), C_THUMB_SH)
	# marcas: onde fica a peça do jogador no mapa inteiro
	var full_top: float = info["world_top"]
	var full_h: float = info["world_h"]
	if full_h > 0.0 and info.has("pawn_y"):
		var pf: float = clampf((info["pawn_y"] - full_top) / full_h, 0.0, 1.0)
		var py: float = y0 + h * pf
		var bob: float = roundf(sin(_t * 3.0)) * PX
		var px: float = x - 4.0 * PX + bob
		_r(Vector2(px - PX, py - PX * 2.0), Vector2(PX * 3.0, PX * 5.0), C_OUT)
		_r(Vector2(px - PX * 2.0, py - PX), Vector2(PX * 5.0, PX * 3.0), C_OUT)
		_r(Vector2(px, py - PX), Vector2(PX, PX * 3.0), C_GOLD)
		_r(Vector2(px - PX, py), Vector2(PX * 3.0, PX), C_GOLD)
	# coroa do chefe em cima
	var cx: float = x + w / 2.0
	var cy: float = y0 - 6.0 * PX
	_r(Vector2(cx - PX * 3.5, cy - PX * 2.0), Vector2(PX * 7.0, PX * 5.0), C_OUT)
	_r(Vector2(cx - PX * 2.5, cy), Vector2(PX * 5.0, PX * 2.0), C_GOLD)
	for dx in [-2.5, -0.5, 1.5]:
		_r(Vector2(cx + dx * PX, cy - PX), Vector2(PX, PX), C_GOLD)
	# começo embaixo
	var by: float = y0 + h + 4.0 * PX
	_r(Vector2(cx - PX * 2.0, by - PX * 2.0), Vector2(PX * 4.0, PX * 4.0), C_OUT)
	_r(Vector2(cx - PX, by - PX), Vector2(PX * 2.0, PX * 2.0), C_THUMB)

# Setinhas "^" / "v" pulsando no meio da borda de cima/de baixo do mapa.
func _draw_chevrons(vs: Vector2, at_top: bool, at_bot: bool) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.2)
	var cx: float = vs.x / 2.0
	for dir in [-1, 1]:
		if (dir < 0 and at_top) or (dir > 0 and at_bot):
			continue
		var base_y: float = (96.0 if dir < 0 else vs.y - 40.0) + float(dir) * pulse * PX * 2.0
		for k in range(2):
			var yy: float = base_y - float(dir) * float(k) * PX * 4.0
			var a: float = (0.9 - 0.35 * float(k)) * (0.55 + 0.45 * pulse)
			for j in range(5):
				var ox: float = float(j) * PX
				var oy: float = float(j) * PX * float(-dir)
				for sx in [-1.0, 1.0]:
					var p := Vector2(cx + sx * ox - PX * 0.5, yy + oy)
					_r(p + Vector2(0, PX), Vector2(PX, PX), Color(C_OUT, a * 0.8))
					_r(p, Vector2(PX, PX), Color(C_TXT, a))

# Plaquinha da primeira vez: mouse (botão aceso) subindo e descendo com setas + texto.
func _draw_hint(vs: Vector2, a: float) -> void:
	var txt: String = "ARRASTE PARA VER O MAPA"
	var fs: int = 32
	var tw: float = FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var icon_w: float = 11.0 * PX + 14.0 * PX
	var w: float = ceilf((tw + icon_w + 14.0 * PX) / PX) * PX
	var h: float = 30.0 * PX
	var pos := Vector2(floorf((vs.x - w) / 2.0 / PX) * PX, vs.y - h - 64.0)
	_r(pos - Vector2(PX, PX), Vector2(w + PX * 2.0, h + PX * 2.0), Color(C_OUT, a))
	_r(pos, Vector2(w, h), Color(C_TRACK, a * 0.96))
	_r(pos, Vector2(w, PX), Color(C_TRACK_HI, a))
	_r(pos + Vector2(0, h - PX), Vector2(w, PX), Color(Color("231a22"), a))
	# mouse 11x16 (px do mapa) subindo e descendo; L = botão esquerdo (pisca)
	var bob: float = roundf(sin(_t * 3.0) * 1.5) * PX
	var m: Vector2 = pos + Vector2(7.0 * PX, (h - 16.0 * PX) / 2.0 + bob)
	var blink: bool = int(_t * 2.5) % 2 == 0
	var rows: Array[String] = [
		"...#####...",
		".##LL#WW##.",
		".#LLL#WWW#.",
		"#LLLL#WWWS#",
		"#LLLL#WWWS#",
		"#LLLL#WWWS#",
		"###########",
		"#WWWWWWWWS#",
		"#WWWWWWWWS#",
		"#WWWWWWWWS#",
		"#WWWWWWWWS#",
		"#WWWWWWWWS#",
		"#WWWWWWWSS#",
		".#WWWWWSS#.",
		".##SSSSS##.",
		"...#####...",
	]
	for yy in range(rows.size()):
		for xx in range(11):
			var ch: String = rows[yy][xx]
			var c: Color
			match ch:
				"#": c = C_OUT
				"W": c = C_THUMB
				"S": c = C_THUMB_SH
				"L": c = C_GOLD if blink else C_THUMB
				_: continue
			_r(m + Vector2(xx, yy) * PX, Vector2(PX, PX), Color(c, a))
	# setas para cima e para baixo ao lado do mouse
	var ax: float = m.x + 11.0 * PX + 6.0 * PX
	var mid: float = pos.y + h / 2.0
	for dir in [-1.0, 1.0]:
		var ay: float = mid + dir * 7.0 * PX + dir * (0.5 + 0.5 * sin(_t * 3.0)) * PX * 2.0
		for j in range(4):
			var yy: float = ay - dir * float(j) * PX
			_r(Vector2(ax - float(j) * PX, yy), Vector2(PX, PX), Color(C_GOLD, a))
			_r(Vector2(ax + float(j) * PX, yy), Vector2(PX, PX), Color(C_GOLD, a))
		_r(Vector2(ax, mid - dir * PX * 1.0 + dir * 2.0 * PX), Vector2(PX, PX * 2.0), Color(C_GOLD, a))
	# texto
	var base: float = mid + (FONT.get_ascent(fs) - FONT.get_descent(fs)) / 2.0
	var tx: float = pos.x + icon_w + 6.0 * PX
	_canvas.draw_string(FONT, Vector2(tx, base + PX), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_OUT, a))
	_canvas.draw_string(FONT, Vector2(tx, base), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_TXT, a))
