class_name MapEruption
extends Node2D
# ERUPÇÃO da Caldeira no mapa. Cada erupção tem um vulcão ao lado do tabuleiro, na
# altura da fileira que ela atinge. Um passo antes, marcas de alvo pulsam nas trilhas
# que vão ser cortadas e nos duelos que vão ser chamuscados (e o vulcão esquenta).
# Quando a peça chega na fileira, as bombas voam do vulcão: trilha atingida vira
# cratera (bloqueada) e duelo atingido ganha o selo de chão queimado.
#
# Este nó fica ACIMA das trilhas e abaixo dos nodos (marcas, crateras, bombas, selos);
# os vulcões vão num nó à parte (`under`), abaixo das trilhas, como um marco do chão.

const DIR := "res://assets/sprites/biomas/caldeira/tabuleiro/erupcao/"
const VOLCANO_SIZE := Vector2(78, 72)
const MOUTH_Y: float = 28.0          # altura da boca (px nativos a partir do topo do sprite)
const BOMB_ARC: float = 2.6          # altura do arco das bombas, em casas
const FIRE_FPS: float = 9.0
const BOMB_SCALE: float = 1.5         # bomba/rastro/impacto um pouco maiores que o chão (leitura)
const IMPACT_SCALE: float = 2.2
const GRAVITY: float = 330.0          # px nativos/s² dos estilhaços (vezes px)

var px: float = 3.0
var under: Node2D = null

# [{ "li": int, "volcano": Vector2 (base, centro), "edge_pts": [Vector2], "node_pts": [Vector2],
#    "hit": [bool] (um por alvo: arestas e depois nodos) }]
var _eruptions: Array = []
var _cur_layer: int = -1
var _fired: Dictionary = {}          # índice -> true
var _t: float = 0.0
var _active: int = -1                # erupção sendo animada
var _active_t0: float = 0.0
var _bombs: Array = []               # [{ "e": int, "j": int, "from": Vector2, "to": Vector2, "t0": float, "dur": float }]
var _impacts: Array = []             # [{ "pos": Vector2, "t0": float }]
var _debris: Array = []              # estilhaços: [{ "p": Vector2, "v": Vector2, "t0", "life", "c": Color, "s": float }]
var _rings: Array = []               # onda de choque: [{ "p": Vector2, "t0": float }]
var _flash: ColorRect = null          # clarão laranja na tela inteira a cada impacto
var _volley_hits: int = 0

static var _cache: Dictionary = {}
static var _badge_tex: ImageTexture = null
var _badges: Array = []              # [Sprite2D, erupção, índice do alvo]

# Selo 11x11 (como os do glaciar, da ponte e da tempestade) a partir de linhas de texto.
static func make_badge(rows: Array, pal: Dictionary) -> ImageTexture:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(11):
		for x in range(11):
			var ch: String = String(rows[y])[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)

# Selo do duelo chamuscado: bola de fogo caindo num disco escuro.
static func _badge_texture() -> ImageTexture:
	if _badge_tex == null:
		_badge_tex = make_badge([
			"...#####...",
			"..######r..",
			".#####rr##.",
			"####rro####",
			"###ooo#####",
			"##oyyo#####",
			"##oyyyo####",
			"##ooyyo####",
			".##oooo###.",
			"..######...",
			"...#####...",
		], {"#": Color("#261c24"), "r": Color("#c63a22"), "o": Color("#f0662a"), "y": Color("#ffe08a")})
	return _badge_tex

# O retângulo (mundo) aparece na tela agora? Os sons e os trancos de câmera só
# acontecem para o que o jogador está vendo.
static func on_screen(ci: CanvasItem, world_rect: Rect2, margin: float = 60.0) -> bool:
	if ci == null or not ci.is_inside_tree():
		return false
	var vp := ci.get_viewport()
	var view := Rect2(Vector2.ZERO, vp.get_visible_rect().size).grow(margin)
	return view.intersects(vp.get_canvas_transform() * world_rect)

func volcano_visible(i: int) -> bool:
	return i >= 0 and i < _eruptions.size() and on_screen(self, _volcano_rect(_eruptions[i]))

static func _frames(base: String, n: int) -> Array:
	var key := base + str(n)
	if _cache.has(key):
		return _cache[key]
	var out: Array = []
	for i in range(1, n + 1):
		var p: String = DIR + base + "_f%d.png" % i
		if ResourceLoader.exists(p):
			out.append(load(p))
	_cache[key] = out
	return out

static func _single(file_name: String) -> Texture2D:
	var p: String = DIR + file_name + ".png"
	if _cache.has(p):
		return _cache[p]
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_cache[p] = t
	return t

func setup(eruptions: Array, fired_layers: Array, sprite_scale: float) -> void:
	px = sprite_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_eruptions = eruptions
	for i in range(_eruptions.size()):
		var e: Dictionary = _eruptions[i]
		var n: int = e["edge_pts"].size() + e["node_pts"].size()
		var done: bool = fired_layers.has(int(e["li"]))
		var hit: Array = []
		for j in range(n):
			hit.append(done)
		e["hit"] = hit
		if done:
			_fired[i] = true
	if under != null:
		under.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		under.draw.connect(_draw_under)
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.55, 0.2, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_flash)
	# selos nos duelos chamuscados (aparecem quando a bomba cai), acima dos nodos
	var holder := Node2D.new()
	holder.z_index = 15
	add_child(holder)
	for i in range(_eruptions.size()):
		var e: Dictionary = _eruptions[i]
		for j in range(e["node_pts"].size()):
			var b := Sprite2D.new()
			b.texture = _badge_texture()
			b.scale = Vector2(px, px)
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b.position = Vector2(e["node_pts"][j]) + Vector2(30.0, -30.0)
			b.visible = false
			holder.add_child(b)
			_badges.append([b, i, e["edge_pts"].size() + j])

func set_layer(cur_layer: int) -> void:
	_cur_layer = cur_layer

func index_for_layer(li: int) -> int:
	for i in range(_eruptions.size()):
		if int(_eruptions[i]["li"]) == li:
			return i
	return -1

func is_fired(i: int) -> bool:
	return _fired.has(i)

func _process(delta: float) -> void:
	_t += delta
	# bombas que chegaram: impacto + o alvo passa a mostrar a cratera/selo
	for b in _bombs:
		if not b.get("launched", false) and _t >= float(b["t0"]):
			b["launched"] = true
			if on_screen(self, Rect2(b["from"], Vector2.ZERO).expand(b["to"])):
				Sfx.play("bomba_voo")
		if not b.get("done", false) and _t >= float(b["t0"]) + float(b["dur"]):
			b["done"] = true
			_impact(b["to"])
			_eruptions[int(b["e"])]["hit"][int(b["j"])] = true
	_bombs = _bombs.filter(func(b): return not b.get("done", false))
	_impacts = _impacts.filter(func(im): return _t - float(im["t0"]) < 5.0 / 14.0)
	_debris = _debris.filter(func(d): return _t - float(d["t0"]) < float(d["life"]))
	_rings = _rings.filter(func(r): return _t - float(r["t0"]) < 0.45)
	for bd in _badges:
		var sp: Sprite2D = bd[0]
		sp.visible = bool(_eruptions[int(bd[1])]["hit"][int(bd[2])])
		sp.position.y = Vector2(_eruptions[int(bd[1])]["node_pts"][int(bd[2]) - _eruptions[int(bd[1])]["edge_pts"].size()]).y - 30.0 + roundf(sin(_t * 2.4 + float(bd[2]))) * px
	queue_redraw()
	if under != null:
		under.queue_redraw()

# As bombas saem do vulcão e caem nos alvos. Volta quando a última pousou.
func fire(i: int) -> void:
	if i < 0 or i >= _eruptions.size() or _fired.has(i):
		return
	_fired[i] = true
	_active = i
	_active_t0 = _t
	var e: Dictionary = _eruptions[i]
	await get_tree().create_timer(2.0 / FIRE_FPS).timeout      # a boca incha
	if volcano_visible(i):
		Juice.shake(get_viewport().get_camera_2d(), 6.0, 0.35)
		Sfx.play("vulcao_erupcao")
	_volley_hits = 0
	var mouth: Vector2 = _volcano_rect(e).position + Vector2(VOLCANO_SIZE.x * 0.5, MOUTH_Y) * px
	var targets: Array = e["edge_pts"] + e["node_pts"]
	var last: float = 0.0
	for j in range(targets.size()):
		var to: Vector2 = targets[j]
		var dur: float = clampf(0.45 + mouth.distance_to(to) / (px * 26.0) * 0.07, 0.5, 1.0)
		var t0: float = _t + 0.11 * float(j)
		_bombs.append({"e": i, "j": j, "from": mouth, "to": to, "t0": t0, "dur": dur})
		last = maxf(last, 0.11 * float(j) + dur)
	await get_tree().create_timer(last + 0.4).timeout
	_active = -1

# Altura do arco: baixo em tiro longo (fica na tela), no máximo BOMB_ARC casas.
func _arc_h(from: Vector2, to: Vector2) -> float:
	return clampf(from.distance_to(to) * 0.18, 0.8 * 26.0 * px, BOMB_ARC * 26.0 * px)

func _arc_point(from: Vector2, to: Vector2, u: float) -> Vector2:
	var arc: float = _arc_h(from, to)
	return from.lerp(to, u) + Vector2(0, -arc * 4.0 * u * (1.0 - u))

# Pontinhos (pixels do mapa) ao longo do arco que a bomba vai fazer.
func _draw_trajectory(from: Vector2, to: Vector2, phase: float) -> void:
	var n: int = maxi(10, int(from.distance_to(to) / (px * 9.0)))
	var flow: float = fposmod(_t * 1.4 + phase * 0.13, 1.0)
	for k in range(1, n):
		var u: float = (float(k) + flow) / float(n)
		if u >= 0.9:
			continue
		var p: Vector2 = _arc_point(from, to, u)
		var hot: bool = (k - int(_t * 8.0)) % 5 == 0
		var sz: float = px * 2.0
		var o: Vector2 = (p - Vector2(sz, sz) * 0.5).round()
		draw_rect(Rect2(o - Vector2(px, px) * 0.5, Vector2(sz + px, sz + px)), Color("#31252f", 0.85))
		draw_rect(Rect2(o, Vector2(sz, sz)), Color("#ffe08a") if hot else Color("#f0662a"))

# A bomba bate: estouro, onda de choque, estilhaços de rocha e brasas voando, clarão
# na tela, tranco na câmera (e uma micro-pausa no primeiro impacto da rajada).
func _impact(pos: Vector2) -> void:
	_impacts.append({"pos": pos, "t0": _t})
	_rings.append({"p": pos, "t0": _t})
	for i in range(22):
		var rock: bool = i % 3 == 0
		var a: float = randf_range(-PI * 0.92, -PI * 0.08)      # para cima e para os lados
		var spd: float = randf_range(70.0, 190.0) * px * (0.7 if rock else 1.0)
		var col: Color
		if rock:
			col = Color("#31252f") if randf() < 0.5 else Color("#5a4855")
		else:
			col = [Color("#ffe08a"), Color("#ffa53a"), Color("#f0662a")][randi() % 3]
		_debris.append({"p": pos, "v": Vector2(cos(a), sin(a)) * spd, "t0": _t, "life": randf_range(0.45, 0.9), "c": col, "s": (2.0 if rock else 1.0) * px})
	if not on_screen(self, Rect2(pos - Vector2(20, 20) * px, Vector2(40, 40) * px)):
		return
	Sfx.play("bomba_impacto")
	var cam := get_viewport().get_camera_2d()
	Juice.shake(cam, 11.0, 0.32)
	if _volley_hits == 0:
		Juice.hit_stop(get_tree(), 0.07, 0.08)
	_volley_hits += 1
	if _flash != null:
		_flash.color.a = 0.22
		var tw := create_tween()
		tw.tween_property(_flash, "color:a", 0.0, 0.22)

func _volcano_rect(e: Dictionary) -> Rect2:
	var sz: Vector2 = VOLCANO_SIZE * px
	var base: Vector2 = e["volcano"]
	return Rect2(Vector2(base.x - sz.x * 0.5, base.y - sz.y), sz)

func _warned(i: int) -> bool:
	if _fired.has(i):
		return false
	var li: int = int(_eruptions[i]["li"])
	return _cur_layer == li - 1 or _cur_layer == li

func _draw_under() -> void:
	for i in range(_eruptions.size()):
		var e: Dictionary = _eruptions[i]
		var fr: Array
		var f: int = 0
		if i == _active:
			fr = _frames("vulcao_erupcao", 6)
			f = int((_t - _active_t0) * FIRE_FPS)
			if f >= fr.size():
				fr = _frames("vulcao_aquecendo", 4)
				f = int(_t * 6.0)
		elif not _fired.has(i) and int(e["li"]) - _cur_layer <= 1:
			fr = _frames("vulcao_aquecendo", 4)
			f = int(_t * 6.0)
		else:
			fr = _frames("vulcao_repouso", 4)
			f = int(_t * 4.0)
		if fr.is_empty():
			continue
		under.draw_texture_rect(fr[f % fr.size()], _volcano_rect(e), false)

func _draw() -> void:
	var alvo: Array = _frames("alvo", 3)
	var selo: Array = _frames("selo_chamuscado", 2)
	for i in range(_eruptions.size()):
		var e: Dictionary = _eruptions[i]
		var edge_pts: Array = e["edge_pts"]
		var node_pts: Array = e["node_pts"]
		var hit: Array = e["hit"]
		var warn: bool = _warned(i)
		# trilhas
		for j in range(edge_pts.size()):
			var p: Vector2 = edge_pts[j]
			if hit[j]:
				var k: int = absi(hash(Vector2i(p))) % 3 + 1
				var cf: Array = _frames("anim/cratera_%d" % k, 3)
				var ct: Texture2D = cf[int(_t * 5.0 + float(k)) % cf.size()] if not cf.is_empty() else _single("cratera_%d" % k)
				if ct != null:
					var csz: Vector2 = ct.get_size() * px
					draw_texture_rect(ct, Rect2((p - csz * 0.5).round(), csz), false)
			elif warn and not alvo.is_empty():
				var at: Texture2D = alvo[int(_t * 5.0) % alvo.size()]
				var asz: Vector2 = at.get_size() * px
				draw_texture_rect(at, Rect2((p - asz * 0.5).round(), asz), false)
		# duelos (o soquete do nodo fica por cima: só o anel aparece)
		for j in range(node_pts.size()):
			var p: Vector2 = node_pts[j]
			if hit[edge_pts.size() + j]:
				if not selo.is_empty():
					var st: Texture2D = selo[int(_t * 3.0) % selo.size()]
					var ssz: Vector2 = st.get_size() * px
					draw_texture_rect(st, Rect2((p - ssz * 0.5).round(), ssz), false)
			elif warn and not alvo.is_empty():
				var at2: Texture2D = alvo[int(_t * 5.0) % alvo.size()]
				var big: Vector2 = Vector2(50, 50) * px
				draw_texture_rect(at2, Rect2((p - big * 0.5).round(), big), false)
	# aviso de BOLA DE FOGO: o caminho pontilhado sai da boca do vulcão até cada alvo
	# (os pontos andam na direção do alvo) e uma bombinha balança em cima da marca
	for i in range(_eruptions.size()):
		if not _warned(i) or i == _active:
			continue
		var e2: Dictionary = _eruptions[i]
		var mouth: Vector2 = _volcano_rect(e2).position + Vector2(VOLCANO_SIZE.x * 0.5, MOUTH_Y) * px
		var tg: Array = e2["edge_pts"] + e2["node_pts"]
		for j in range(tg.size()):
			if e2["hit"][j]:
				continue
			_draw_trajectory(mouth, tg[j], float(j))
			var bomba_i: Array = _frames("bomba", 4)
			if not bomba_i.is_empty():
				var bt2: Texture2D = bomba_i[int(_t * 6.0) % bomba_i.size()]
				var bs2: Vector2 = bt2.get_size() * px
				var lift: float = (22.0 if j >= e2["edge_pts"].size() else 14.0) * px + roundf(sin(_t * 4.0 + float(j)) * 1.5) * px
				draw_texture_rect(bt2, Rect2((Vector2(tg[j]) - Vector2(0, lift) - bs2 * 0.5).round(), bs2), false)
	# bombas em voo (com o rastro apontando para trás)
	var bomba: Array = _frames("bomba", 4)
	var rastro: Array = _frames("rastro", 3)
	for b in _bombs:
		var u: float = (_t - float(b["t0"])) / float(b["dur"])
		if u < 0.0 or u > 1.0:
			continue
		var from: Vector2 = b["from"]
		var to: Vector2 = b["to"]
		var arc: float = _arc_h(from, to)
		var pos: Vector2 = from.lerp(to, u) + Vector2(0, -arc * 4.0 * u * (1.0 - u))
		var vel: Vector2 = (to - from) + Vector2(0, -arc * 4.0 * (1.0 - 2.0 * u))
		if not rastro.is_empty() and vel.length() > 0.1:
			var rt: Texture2D = rastro[int(_t * 12.0) % rastro.size()]
			var rsz: Vector2 = rt.get_size() * px * BOMB_SCALE
			draw_set_transform(pos, (-vel).angle() + PI * 0.5, Vector2.ONE)
			draw_texture_rect(rt, Rect2(Vector2(-rsz.x * 0.5, -rsz.y + 3.0 * px * BOMB_SCALE), rsz), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not bomba.is_empty():
			var bt: Texture2D = bomba[int(_t * 12.0) % bomba.size()]
			var bsz: Vector2 = bt.get_size() * px * BOMB_SCALE
			draw_texture_rect(bt, Rect2((pos - bsz * 0.5).round(), bsz), false)
	# onda de choque (anel de pixels que abre e esfria)
	for r in _rings:
		var k: float = (_t - float(r["t0"])) / 0.45
		var rad: float = lerpf(6.0, 34.0, sqrt(k)) * px
		var col: Color = Color("#ffe08a").lerp(Color("#c63a22"), k)
		var n: int = int(TAU * rad / px)
		for i in range(n):
			if (i + int(k * 9.0)) % 3 == 0:
				continue
			var a: float = TAU * float(i) / float(n)
			var q: Vector2 = (Vector2(r["p"]) + Vector2(cos(a), sin(a) * 0.7) * rad - Vector2(px, px) * 0.5).round()
			draw_rect(Rect2(q, Vector2(px, px)), Color(col, 1.0 - k))
		if k < 0.18:
			draw_circle(Vector2(r["p"]), (16.0 + 40.0 * k) * px, Color(1.0, 0.92, 0.65, 0.75 * (1.0 - k / 0.18)))
	# estilhaços
	for d in _debris:
		var dt: float = _t - float(d["t0"])
		var dp: Vector2 = Vector2(d["p"]) + Vector2(d["v"]) * dt + Vector2(0, 0.5 * GRAVITY * px * dt * dt)
		var fade: float = 1.0 - dt / float(d["life"])
		var ds: float = float(d["s"])
		draw_rect(Rect2((dp - Vector2(ds, ds) * 0.5).round(), Vector2(ds, ds)), Color(d["c"], minf(1.0, fade * 1.6)))
	# impactos
	var imp: Array = _frames("impacto", 5)
	for im in _impacts:
		var f: int = int((_t - float(im["t0"])) * 14.0)
		if f < imp.size():
			var it: Texture2D = imp[f]
			var isz: Vector2 = it.get_size() * px * IMPACT_SCALE
			draw_texture_rect(it, Rect2((Vector2(im["pos"]) - isz * 0.5).round(), isz), false)
