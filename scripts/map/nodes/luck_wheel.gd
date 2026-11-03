class_name LuckWheel
extends Control

# Roleta de sorte dos Eventos "?", no tema de damas: a roda é uma PEÇA GIGANTE
# (aro dourado de pedra, anel de casas cream/ameixa que pisca, sulcos
# concêntricos como os de uma peça de dama, cubo central em forma de mini-peça)
# em pixel art de verdade: o corpo é renderizado numa imagem de 96x96 (cada
# pixel vira um bloco de PX telas, filtro nearest), então não há serrilhado
# suave. O ponteiro é um marcador dourado fixo no topo que estala a cada divisa.
#
# O resultado já é conhecido antes de girar (quem chama sorteia e passa a chave
# em spin_to) — a roleta só dramatiza.
#
# segments: [{key, chance, label, kind("good"|"bad"|"danger"|"neutral")}]
# Sinais: tick (ponteiro cruzou uma divisa — gancho pra som) e finished(key).

signal tick()
signal finished(key: String)

const SPIN_SECONDS: float = 3.8
const FULL_TURNS: int = 5
const PX: int = 4                       # tamanho de cada "pixel" da arte, em telas
const GRID: int = 96                    # imagem do corpo: GRID x GRID pixels
const R_BODY: float = 44.0              # raio total (px da arte)
const R_RIM_IN: float = 38.5
const R_RING_IN: float = 34.5
const R_SEG: float = 33.5
const R_HUB: float = 9.0
const RING_SECTORS: int = 24

# Cores da direção de arte (ameixa / creme / ouro + acentos).
const INK := Color("#241a2b")
const PLUM_D := Color("#3a2b41")
const PLUM_M := Color("#5a4561")
const PLUM_L := Color("#7c6489")
const CREAM := Color("#efe6cf")
const CREAM_D := Color("#cfc3a6")
const GOLD := Color("#d9a441")
const GOLD_D := Color("#9a6f2a")
const KIND_COLORS := {
	"good": Color("#5b8f4e"),
	"bad": Color("#d0802f"),
	"danger": Color("#b8454a"),
	"neutral": Color("#7c6489"),
}
# Matriz de Bayer 2x2 (dithering).
const BAYER := [[0, 2], [3, 1]]

var segments: Array = []        # cada um ganha a0/a1 (radianos, no sentido horário a partir do topo)
var wheel_angle: float = 0.0    # rotação horária da roda
var is_spinning: bool = false
var result_key: String = ""
var caption: String = ""
var caption_color: Color = Color.WHITE

var _pointer_kick: float = 0.0
var _last_idx: int = -1
var _highlight_idx: int = -1
var _highlight: float = 0.0
var _tween: Tween = null
var _particles: Array = []
var _clock: float = 0.0
var _img: Image
var _tex: ImageTexture
var _phi: PackedFloat32Array     # ângulo horário a partir do topo, por pixel
var _rad: PackedFloat32Array     # raio (px da arte), por pixel
var _bytes: PackedByteArray

func _init() -> void:
	custom_minimum_size = Vector2(400, 480)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_precompute()

func _center() -> Vector2:
	return Vector2(size.x / 2.0, 200.0)

func _precompute() -> void:
	_phi = PackedFloat32Array()
	_rad = PackedFloat32Array()
	_phi.resize(GRID * GRID)
	_rad.resize(GRID * GRID)
	var c = GRID / 2.0
	for y in range(GRID):
		for x in range(GRID):
			var dx = (x + 0.5) - c
			var dy = (y + 0.5) - c
			_phi[y * GRID + x] = atan2(dx, -dy)
			_rad[y * GRID + x] = sqrt(dx * dx + dy * dy)
	_bytes = PackedByteArray()
	_bytes.resize(GRID * GRID * 4)
	_img = Image.create_from_data(GRID, GRID, false, Image.FORMAT_RGBA8, _bytes)
	_tex = ImageTexture.create_from_image(_img)

func setup(p_segments: Array) -> void:
	segments = []
	var total := 0.0
	for s in p_segments:
		total += float(s["chance"])
	var acc := 0.0
	for s in p_segments:
		var seg: Dictionary = s.duplicate()
		seg["a0"] = acc / total * TAU
		acc += float(s["chance"])
		seg["a1"] = acc / total * TAU
		segments.append(seg)
	wheel_angle = 0.0
	result_key = ""
	caption = ""
	_highlight_idx = -1
	_highlight = 0.0
	_last_idx = -1
	_particles.clear()

func _segment_index_at(local_angle: float) -> int:
	var q = fposmod(local_angle, TAU)
	for i in range(segments.size()):
		if q >= segments[i]["a0"] and q < segments[i]["a1"]:
			return i
	return segments.size() - 1

# Gira e termina na fatia `key` (ponto sorteado dentro dela, longe das bordas).
func spin_to(key: String) -> void:
	var idx := -1
	for i in range(segments.size()):
		if segments[i]["key"] == key:
			idx = i
	if idx < 0:
		finished.emit(key)
		return
	result_key = key
	is_spinning = true
	var seg: Dictionary = segments[idx]
	var p: float = lerpf(seg["a0"], seg["a1"], randf_range(0.2, 0.8))
	# O ponto p (ângulo local) tem que parar no topo: p + rotação ≡ 0 (mod TAU).
	var target: float = TAU * FULL_TURNS - p
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "wheel_angle", target, SPIN_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_on_stopped.bind(idx))

# Clique durante o giro: acelera até o fim (o resultado não muda).
func skip() -> void:
	if is_spinning and _tween != null and _tween.is_valid():
		_tween.set_speed_scale(12.0)

func _on_stopped(idx: int) -> void:
	is_spinning = false
	_highlight_idx = idx
	var seg: Dictionary = segments[idx]
	caption = seg["label"]
	caption_color = KIND_COLORS.get(seg.get("kind", "neutral"), Color.WHITE).lightened(0.45)
	_burst(seg.get("kind", "neutral"))
	var t = create_tween()
	t.tween_property(self, "_highlight", 1.0, 0.12)
	t.tween_property(self, "_highlight", 0.25, 0.18)
	t.tween_property(self, "_highlight", 1.0, 0.12)
	t.tween_property(self, "_highlight", 0.25, 0.18)
	t.tween_property(self, "_highlight", 0.8, 0.5)
	t.tween_interval(0.35)
	t.tween_callback(func(): finished.emit(result_key))

func _burst(kind: String) -> void:
	var pal: Array
	match kind:
		"good": pal = [GOLD, CREAM, Color("#8fbf7a"), GOLD]
		"bad": pal = [Color("#d0802f"), GOLD_D, CREAM_D]
		"danger": pal = [Color("#b8454a"), INK, Color("#d0802f"), PLUM_L]
		_: pal = [CREAM]
	var origin = _center() + Vector2(0, -20)
	for i in range(54):
		var ang = randf_range(-PI * 0.95, -PI * 0.05)
		var spd = randf_range(180.0, 520.0)
		_particles.append({
			"pos": origin + Vector2(randf_range(-20, 20), randf_range(-10, 10)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"col": pal[randi() % pal.size()],
			"life": randf_range(0.8, 1.5),
			"sz": float(PX * randi_range(1, 2)),
			"disc": randf() < 0.35,   # alguns "confetes" são mini-discos de dama
		})

func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if is_spinning:
		var idx = _segment_index_at(-wheel_angle)
		if idx != _last_idx:
			if _last_idx != -1:
				_pointer_kick = 1.0
				tick.emit()
			_last_idx = idx
	_pointer_kick = maxf(0.0, _pointer_kick - delta * 6.0)
	for p in _particles:
		p["vel"].y += 900.0 * delta
		p["pos"] += p["vel"] * delta
		p["life"] -= delta
	_particles = _particles.filter(func(p): return p["life"] > 0.0)
	_render_body()
	queue_redraw()

# ==========================================
# CORPO EM PIXEL ART (imagem GRID x GRID)
# ==========================================

func _put(i: int, c: Color) -> void:
	var o = i * 4
	_bytes[o] = int(c.r * 255.0)
	_bytes[o + 1] = int(c.g * 255.0)
	_bytes[o + 2] = int(c.b * 255.0)
	_bytes[o + 3] = int(c.a * 255.0)

func _render_body() -> void:
	# Pisca do anel de casas: corre rápido girando, devagar parado.
	var flip: int = int(_clock * 14.0) if is_spinning else int(_clock * 2.5)
	var seg_cols: Array = []
	for s in segments:
		seg_cols.append(KIND_COLORS.get(s.get("kind", "neutral"), PLUM_L))
	var shadow_c = GRID / 2.0
	for y in range(GRID):
		for x in range(GRID):
			var i = y * GRID + x
			var r: float = _rad[i]
			var phi: float = _phi[i]
			var col := Color(0, 0, 0, 0)
			var bay: int = BAYER[y & 1][x & 1]
			# Luz vinda do alto-esquerda: +1 lá, -1 no baixo-direita.
			var lit: float = (cos(phi) - sin(phi)) * 0.7071
			if r > R_BODY:
				# Sombra projetada (pontilhada) à direita/baixo.
				var sx = (x + 0.5) - (shadow_c + 2.0)
				var sy = (y + 0.5) - (shadow_c + 3.0)
				if sx * sx + sy * sy <= R_BODY * R_BODY and bay < 3:
					col = Color(0.0, 0.0, 0.0, 0.42)
			elif r > R_BODY - 1.5:
				col = INK
			elif r > R_RIM_IN:
				# Aro dourado de pedra.
				col = GOLD
				if lit > 0.35:
					col = CREAM_D if (r > R_BODY - 3.2 and bay < 2) else GOLD
				elif lit < -0.25:
					col = GOLD_D
				if absf(r - (R_RIM_IN + 1.0)) < 0.5:
					col = GOLD_D
			elif r > R_RING_IN:
				# Anel de casas cream/ameixa (xadrez) que pisca.
				var k = int(floor(fposmod(phi, TAU) / TAU * RING_SECTORS))
				col = CREAM if (k + flip) % 2 == 0 else PLUM_M
			elif r > R_SEG:
				col = INK
			elif r < R_HUB:
				# Cubo central: mini-peça de dama.
				col = INK
				if r < R_HUB - 1.0:
					col = GOLD if (lit > -0.25 or r < 3.0) else GOLD_D
				if r < R_HUB - 3.5:
					col = CREAM
				if r < 2.6:
					col = PLUM_D
			else:
				var local = phi - wheel_angle
				var idx = _segment_index_at(local)
				var base: Color = seg_cols[idx] if idx >= 0 and idx < seg_cols.size() else PLUM_D
				col = base
				# Profundidade: mais claro perto da borda (dither), mais escuro no miolo.
				if r > 27.0 and bay < 2:
					col = base.lightened(0.22)
				elif r < 15.0 and bay > 0:
					col = base.darkened(0.22)
				# Sulcos concêntricos, como numa peça de dama.
				if absf(r - 22.0) < 0.55:
					col = base.darkened(0.38)
				elif absf(r - 14.5) < 0.5:
					col = base.lightened(0.18)
				# Divisas entre fatias.
				var q = fposmod(local, TAU)
				for s in segments:
					var d = absf(q - s["a0"])
					d = minf(d, TAU - d)
					if d * r < 1.15:
						col = INK
				# Fatia vencedora pisca (dither com creme).
				if idx == _highlight_idx and _highlight > 0.0 and float(bay) < _highlight * 4.0 and col != INK:
					col = col.lerp(CREAM, 0.75)
			_put(i, col)
	_img.set_data(GRID, GRID, false, Image.FORMAT_RGBA8, _bytes)
	_tex.update(_img)

# ==========================================
# DESENHO (corpo + ponteiro + rótulos + legenda + partículas)
# ==========================================

static func _dir(phi: float) -> Vector2:
	# Ângulo horário medido a partir do topo.
	return Vector2(sin(phi), -cos(phi))

func _px_rect(p: Vector2, w: int, h: int, col: Color) -> void:
	draw_rect(Rect2(p, Vector2(w * PX, h * PX)), col)

func _draw() -> void:
	var font = ThemeDB.fallback_font
	var c = _center()
	# Corpo.
	draw_texture_rect(_tex, Rect2(c - Vector2(GRID, GRID) * PX / 2.0, Vector2(GRID, GRID) * PX), false)

	# Rótulos tangentes à roda (na fatia vencedora, parada no topo, ficam retos).
	var rl: float = R_SEG * PX * 0.64
	for i in range(segments.size()):
		var seg: Dictionary = segments[i]
		var mid: float = (seg["a0"] + seg["a1"]) / 2.0 + wheel_angle
		var at = c + _dir(mid) * rl
		draw_set_transform(at, mid, Vector2.ONE)
		var w = R_SEG * PX * 0.78
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(2, 2)]:
			draw_string(font, Vector2(-w / 2.0, 7) + o, seg["label"], HORIZONTAL_ALIGNMENT_CENTER, w, 22, INK)
		draw_string(font, Vector2(-w / 2.0, 7), seg["label"], HORIZONTAL_ALIGNMENT_CENTER, w, 22, CREAM)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Ponteiro: marcador dourado em degraus de pixel (uma seta pra baixo), fixo
	# no topo; ao cruzar uma divisa ele "estala" (1 pixel pro lado e pra cima).
	var jx: float = float(int(round(sin(_clock * 60.0) * _pointer_kick))) * PX
	var jy: float = -float(int(round(_pointer_kick))) * PX
	var tip_y: float = c.y - R_BODY * PX + 10.0 + jy     # ponta (parte de baixo)
	var rows = 9
	for k in range(rows):
		var half = rows - 1 - k            # k=0 é o topo largo; k=rows-1 é a ponta
		var y = tip_y - (rows - 1 - k) * PX - PX
		_px_rect(Vector2(c.x + jx - (half + 1) * PX, y - PX * 0.0), (half + 1) * 2, 1, INK)
	for k in range(rows - 1):
		var half2 = rows - 2 - k
		var y2 = tip_y - (rows - 1 - k) * PX - PX
		_px_rect(Vector2(c.x + jx - half2 * PX, y2), half2 * 2, 1, CREAM_D if k < 1 else GOLD)
	# Brilho no ombro esquerdo.
	_px_rect(Vector2(c.x + jx - 6 * PX, tip_y - (rows - 1) * PX - PX), 2, 1, CREAM)

	# Legenda do resultado numa placa ameixa com borda dourada.
	if caption != "":
		var plate_w: float = 300.0
		var plate_h: float = 60.0
		var pr = Rect2(Vector2(size.x / 2.0 - plate_w / 2.0, c.y + R_BODY * PX + 12.0), Vector2(plate_w, plate_h))
		draw_rect(pr.grow(PX), INK)
		draw_rect(pr, GOLD)
		draw_rect(pr.grow(-PX), PLUM_D)
		draw_rect(Rect2(pr.position + Vector2(PX, PX), Vector2(pr.size.x - PX * 2, PX)), PLUM_M)
		var cp = Vector2(pr.position.x, pr.position.y + plate_h / 2.0 + 12.0)
		draw_string(font, cp + Vector2(2, 3), caption, HORIZONTAL_ALIGNMENT_CENTER, plate_w, 34, INK)
		draw_string(font, cp, caption, HORIZONTAL_ALIGNMENT_CENTER, plate_w, 34, caption_color)

	# Confete / faíscas (quadradinhos de pixel; alguns viram mini-discos).
	for p in _particles:
		var a = clampf(p["life"] / 0.5, 0.0, 1.0)
		var col: Color = p["col"]
		col.a = a
		var pos: Vector2 = Vector2(round(p["pos"].x / PX), round(p["pos"].y / PX)) * PX
		var sz: float = p["sz"]
		if p.get("disc", false):
			draw_rect(Rect2(pos - Vector2(sz, sz * 0.5), Vector2(sz * 2.0, sz)), Color(INK.r, INK.g, INK.b, a))
			draw_rect(Rect2(pos - Vector2(sz - 2.0, sz * 0.5 - 2.0), Vector2(sz * 2.0 - 4.0, sz - 4.0)), col)
		else:
			draw_rect(Rect2(pos - Vector2.ONE * sz / 2.0, Vector2.ONE * sz), col)
