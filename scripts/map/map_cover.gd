class_name MapCover
extends Node2D

# GRUTA da Mina dos Cristais no mapa. Uma gruta cobre de 1 a 3 nodos (às vezes
# dois nodos ligados por um túnel): o teto de rocha esconde os nodos (só se vê
# um "?") e as paredes de rocha acompanham o contorno, dos dois lados.
# Quando a peça entra, abre um foco dentro da gruta: o exterior escurece e os
# cristais de dentro brilham. Cada nodo visitado ganha uma "janela" permanente
# no teto; quando todos foram visitados o teto se desfaz em pixels, e ficam as
# paredes e os cristais.

const PX: int = 3                          # escala do mapa (pixels nativos -> tela)
const TILE: float = 78.0
const RX_PX: float = 2.4 * TILE            # meia-largura da gruta em volta de cada nodo
const RY_PX: float = 2.7 * TILE            # meia-altura
const TUNNEL: float = 0.8                  # espessura do túnel entre dois nodos (relativa)
const REF_PX: float = 160.0                # distância de referência para abrir o foco
const SPOT_PX: float = 210.0               # raio máximo do foco (tela)
const PERM_R: float = 46.0                 # raio da janela permanente de um nodo visitado (nativo)
const MAX_MEMBERS: int = 3
const FACE_D: int = 22                     # altura da face frontal do bloco de rocha (px nativos)
const FACE_SH: int = 0                     # sombra no chão sob a face

const SHADER_CODE := """
shader_type canvas_item;
uniform vec2 hole_pos = vec2(-1000.0);
uniform float hole_r = 0.0;
uniform vec2 perm_pos[3];
uniform float perm_r[3];
uniform vec2 tex_size = vec2(96.0, 112.0);
uniform float dissolve = 0.0;
uniform vec4 rim_col : source_color = vec4(0.91, 0.72, 0.19, 1.0);
uniform float hover = 0.0;
uniform sampler2D ceil_tex : filter_nearest;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 cell = floor(UV * tex_size);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float inner = texture(TEXTURE, UV + vec2(px.x, 0.0)).a * texture(TEXTURE, UV - vec2(px.x, 0.0)).a * texture(TEXTURE, UV + vec2(0.0, px.y)).a * texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	if (hover > 0.0 && c.a > 0.5 && inner < 0.5) {
		c.rgb = mix(c.rgb, vec3(1.0, 0.86, 0.35), hover);
	}
	float is_ceil = texture(ceil_tex, UV).a;
	if (is_ceil >= 0.5) {
		bool carved = false;
		float rim = 0.0;
		float shade = 0.0;
		for (int i = 0; i < 4; i++) {
			vec2 hp = hole_pos;
			float hr = hole_r;
			float rs = 0.9;
			if (i > 0) { hp = perm_pos[i - 1]; hr = perm_r[i - 1]; rs = 0.45; }
			if (hr > 0.5) {
				float d = distance(cell + vec2(0.5), hp);
				float edge = hr + (h(cell) - 0.5) * 2.5;
				if (d < edge) { carved = true; }
				else if (d < edge + 2.0) { rim = max(rim, rs); }
				else if (d < edge + 5.0 && h(cell + vec2(7.0, 3.0)) < 0.5) { shade = 1.0; }
			}
		}
		if (carved) { c.a = 0.0; }
		else if (rim > 0.0) { c.rgb = mix(c.rgb, rim_col.rgb, rim); }
		else if (shade > 0.0) { c.rgb *= 0.55; }
		if (h(cell + vec2(1.0, 9.0)) < dissolve) { c.a = 0.0; }
	}
	COLOR = c;
}
"""

const DARK_SHADER := """
shader_type canvas_item;
uniform vec2 radii = vec2(200.0, 240.0);
uniform vec2 box = vec2(4000.0);
uniform vec2 pts[3];
uniform int count = 1;
uniform bool has_edge = false;
uniform float strength = 0.0;
uniform vec4 segs[4];
uniform int seg_count = 0;
uniform float light_r = 120.0;
void fragment() {
	vec2 p = (UV - 0.5) * box;
	float e = 1000.0;
	for (int i = 0; i < 3; i++) {
		if (i < count) { e = min(e, length((p - pts[i]) / radii)); }
	}
	if (has_edge) {
		vec2 a = pts[0] / radii;
		vec2 b = pts[1] / radii;
		vec2 q = p / radii;
		vec2 ab = b - a;
		float t = clamp(dot(q - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
		e = min(e, length(q - (a + ab * t)) / 0.8);
	}
	float a2 = smoothstep(0.75, 1.15, e) * strength;
	for (int i = 0; i < 4; i++) {
		if (i < seg_count) {
			vec2 sa = segs[i].xy;
			vec2 sb = segs[i].zw;
			vec2 sab = sb - sa;
			float st = clamp(dot(p - sa, sab) / max(dot(sab, sab), 0.0001), 0.0, 1.0);
			float sd = length(p - (sa + sab * st));
			a2 *= smoothstep(light_r * 0.55, light_r * 1.5, sd);
		}
	}
	COLOR = vec4(0.02, 0.01, 0.06, a2);
}
"""

const CRYSTAL_DIR := "res://assets/sprites/biomas/mina/tabuleiro/cristais/"
const CRYSTALS: Array[String] = [
	"cristal_1_violeta_alto_escura", "cristal_2_violeta_largo_escura", "cristal_3_gelo_pequeno_escura",
	"cristal_4_gelo_alto_escura", "cristal_5_esmeralda_escura", "cristal_6_misto_escura",
]
const GLOW_COLORS: Array[Color] = [
	Color(0.56, 0.42, 0.82), Color(0.56, 0.42, 0.82), Color(0.66, 0.86, 0.94),
	Color(0.66, 0.86, 0.94), Color(0.25, 0.7, 0.5), Color(0.75, 0.55, 0.9),
]
const GRUTA_DIR := "res://assets/sprites/biomas/mina/gruta/"
static var _glow_tex: ImageTexture = null
static var _rock_imgs: Array = []
static var _casa_imgs: Array = []   # [claras, escuras]: casas do tabuleiro da mina
const CASAS_DIR := "res://assets/sprites/biomas/mina/tabuleiro/casas/"

static func _casa_images() -> Array:
	if _casa_imgs.is_empty():
		for kind in ["clara", "escura"]:
			var lst: Array = []
			for i in range(1, 9):
				var t := load(CASAS_DIR + "casa_%s_%d.png" % [kind, i]) as Texture2D
				if t != null:
					var im: Image = t.get_image()
					if im.is_compressed():
						im.decompress()
					im.convert(Image.FORMAT_RGBA8)
					lst.append(im)
			_casa_imgs.append(lst)
	return _casa_imgs

static var _tex_cache: Dictionary = {}
static var _tint_cache: Dictionary = {}

static func _gtex(file: String) -> Texture2D:
	if not _tex_cache.has(file):
		_tex_cache[file] = load(GRUTA_DIR + file + ".png") as Texture2D
	return _tex_cache[file]

static var _topo_imgs: Array = []
static var _face_imgs: Array = []

static func _load_imgs(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var t := _gtex(n)
		if t != null:
			var im: Image = t.get_image()
			if im.is_compressed():
				im.decompress()
			im.convert(Image.FORMAT_RGBA8)
			out.append(im)
	return out

static func _topo_images() -> Array:
	if _topo_imgs.is_empty():
		_topo_imgs = _load_imgs(["teto_topo_1", "teto_topo_2", "teto_topo_3", "teto_topo_4"])
		if _topo_imgs.size() < 4:
			_topo_imgs = []
	return _topo_imgs

static func _face_images() -> Array:
	if _face_imgs.is_empty():
		_face_imgs = _load_imgs(["teto_face_1", "teto_face_2", "teto_face_3"])
	return _face_imgs

static func _rock_images() -> Array:
	if _rock_imgs.is_empty():
		for i in range(1, 4):
			var t := _gtex("rocha_%d" % i)
			if t != null:
				var im: Image = t.get_image()
				if im.is_compressed():
					im.decompress()
				im.convert(Image.FORMAT_RGBA8)
				_rock_imgs.append(im)
	return _rock_imgs

# Cor de brilho de um sprite de cristal: média dos pixels saturados e claros.
static func _glow_tint(file: String) -> Color:
	if _tint_cache.has(file):
		return _tint_cache[file]
	var tex := _gtex(file)
	var col := Color(0.7, 0.6, 0.95)
	if tex != null:
		var im: Image = tex.get_image()
		var acc := Vector3.ZERO
		var n: int = 0
		for y in range(im.get_height()):
			for x in range(im.get_width()):
				var c: Color = im.get_pixel(x, y)
				if c.a > 0.9 and c.s > 0.3 and c.v > 0.6:
					acc += Vector3(c.r, c.g, c.b)
					n += 1
		if n > 0:
			acc /= float(n)
			col = Color(acc.x, acc.y, acc.z)
	_tint_cache[file] = col
	return col

var members: Array[Vector2] = []          # posições (locais, px) dos nodos da gruta
var has_edge: bool = false                # members[0] e members[1] ligados por um túnel
var revealed: Array[bool] = []
var lit: float = 0.0                      # 0..1: quanto o foco está aberto (o céu usa)
signal hovered(idx: int, on: bool)
signal clicked(idx: int)

var _sprite: Sprite2D
var _mat: ShaderMaterial
var _tex_size: Vector2 = Vector2.ONE
var _ceil_tex: ImageTexture
var _wall_tex: ImageTexture
var _outer: Node2D          # cristais nas paredes (ficam depois)
var _inner: Node2D          # cristais dentro da gruta (aparecem no foco)
var _roof: Node2D           # cristais embutidos no teto (somem com ele)
var _roof_items: Array = [] # [sprite, glow_sprite, pos]
var _dark: ColorRect
var _dark_mat: ShaderMaterial
var _glyphs: Array[Sprite2D] = []
var _buttons: Array[Button] = []
var _perm_r: Array[float] = [0.0, 0.0, 0.0]
var _hover_idx: int = -1
var _lit_target: float = 0.0
var _glows: Array = []      # [sprite, base_alpha, fase]
var _crystal_sprites: Array = []
var _pawn_local: Vector2 = Vector2(-9999, -9999)
var _t: float = 0.0
var dissolving: bool = false

# --------------------------------------------------------------- geometria ----

# Valor do "campo" da gruta num ponto (px): <= 1 é dentro. Estático: o mapa usa
# para saber que nodos ficam debaixo do teto.
static func mask_value(p: Vector2, pts: Array, edge: bool) -> float:
	var r := Vector2(RX_PX, RY_PX)
	var e: float = 1000.0
	for m in pts:
		e = minf(e, ((p - m) / r).length())
	if edge and pts.size() >= 2:
		var a: Vector2 = pts[0] / r
		var b: Vector2 = pts[1] / r
		var q: Vector2 = p / r
		var ab: Vector2 = b - a
		var t: float = clampf((q - a).dot(ab) / maxf(ab.dot(ab), 0.0001), 0.0, 1.0)
		e = minf(e, (q - (a + ab * t)).length() / TUNNEL)
	return e

func _dist_to_cave(p: Vector2) -> float:
	var best: float = 1e9
	for m in members:
		best = minf(best, p.distance_to(m))
	if has_edge and members.size() >= 2:
		var a: Vector2 = members[0]
		var ab: Vector2 = members[1] - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.dot(ab), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

# ------------------------------------------------------------------ setup ----

# `world_pts`: posições (mundo) dos nodos; `edge`: os dois primeiros são ligados
# por túnel; `done`: quais já foram visitados (a janela já nasce aberta).
# Centro (mundo) de uma gruta, alinhado a uma casa do tabuleiro.
static func cave_center(world_pts: Array) -> Vector2:
	var minp := Vector2(1e9, 1e9)
	var maxp := Vector2(-1e9, -1e9)
	for wp in world_pts:
		minp = Vector2(minf(minp.x, wp.x - RX_PX), minf(minp.y, wp.y - RY_PX))
		maxp = Vector2(maxf(maxp.x, wp.x + RX_PX), maxf(maxp.y, wp.y + RY_PX))
	var mid: Vector2 = (minp + maxp) / 2.0
	return Vector2(roundf(mid.x / TILE) * TILE, roundf(mid.y / TILE) * TILE)

var board_rect: Rect2 = Rect2()   # área (mundo) do tabuleiro: a gruta não sai dela; definir ANTES do setup
var pawn_paths: Array = []  # caminhos (casas do mundo) que a PEÇA faz ao entrar/sair; definir ANTES do setup
var neighbors: Array = []   # grutas vizinhas: {pts (mundo), edge, seed}; definir ANTES do setup
var _nb_cells: Dictionary = {}   # casas (relativas a esta gruta) cobertas pelo teto de uma vizinha

func _calc_nb_cells(cells_x: Vector2i, cells_y: Vector2i, my_seed: int) -> void:
	# Casas que são teto de uma gruta VIZINHA. Onde as duas se sobrepõem, a casa fica com a gruta
	# mais próxima (empate: menor semente), para nenhuma rocha ser desenhada duas vezes.
	_nb_cells = {}
	for nb in neighbors:
		var ctr: Vector2 = cave_center(nb["pts"])
		var g0 := Vector2i(int(roundf(ctr.x / TILE)), int(roundf(ctr.y / TILE)))
		var loc: Array = []
		for wp in nb["pts"]:
			loc.append(wp - ctr)
		var sd: int = nb["seed"]
		for sy in range(cells_y.x, cells_y.y + 1):
			for sx in range(cells_x.x, cells_x.y + 1):
				var cn := Vector2i(_grid0.x + sx - g0.x, _grid0.y + sy - g0.y)
				var e: float = mask_value(Vector2(cn) * TILE, loc, nb["edge"])
				if e > 0.9 + (_hash(cn.x, cn.y, sd + 21) - 0.5) * 0.34:
					continue
				var em: float = mask_value(Vector2(float(sx), float(sy)) * TILE, members, has_edge)
				var mine: bool = em <= 0.9 + (_hash(sx, sy, my_seed + 21) - 0.5) * 0.34
				if mine and (em < e or (em == e and my_seed < sd)):
					continue
				_nb_cells[Vector2i(sx, sy)] = true

# A casa (relativa à gruta) está inteira dentro do tabuleiro?
func _cell_on_board(sx: int, sy: int) -> bool:
	if board_rect.size.x <= 0.0:
		return true
	var wc: Vector2 = position + Vector2(float(sx), float(sy)) * TILE
	return wc.x - TILE * 0.5 >= board_rect.position.x - 1.0 and wc.y - TILE * 0.5 >= board_rect.position.y - 1.0 and wc.x + TILE * 0.5 <= board_rect.end.x + 1.0 and wc.y + TILE * 0.5 <= board_rect.end.y + 1.0

# Abre o foco nesta gruta por causa da gruta VIZINHA (sem acender nada aqui).
func ext_spot(pawn_world: Vector2, r_px: float) -> void:
	if _mat == null or dissolving:
		return
	_mat.set_shader_parameter("hole_pos", (pawn_world - position) / float(PX) + _tex_size / 2.0)
	_mat.set_shader_parameter("hole_r", r_px / float(PX))

var spot_r: float = 0.0   # raio atual do foco (px de tela)

func setup(world_pts: Array, edge: bool, done: Array, seed_value: int, others: Array = [], paths: Array = []) -> void:
	has_edge = edge
	_others_w = others
	_paths_g = paths
	var minp := Vector2(1e9, 1e9)
	var maxp := Vector2(-1e9, -1e9)
	for wp in world_pts:
		minp = Vector2(minf(minp.x, wp.x - RX_PX), minf(minp.y, wp.y - RY_PX))
		maxp = Vector2(maxf(maxp.x, wp.x + RX_PX), maxf(maxp.y, wp.y + RY_PX))
	var mid: Vector2 = (minp + maxp) / 2.0
	var center := Vector2(roundf(mid.x / TILE) * TILE, roundf(mid.y / TILE) * TILE)   # centro de uma casa do tabuleiro
	var ext := Vector2(maxf(center.x - minp.x, maxp.x - center.x), maxf(center.y - minp.y, maxp.y - center.y)) * 2.0
	position = center
	_grid0 = Vector2i(int(roundf(center.x / TILE)), int(roundf(center.y / TILE)))
	z_index = 20
	for wp in world_pts:
		members.append(wp - center)
		revealed.append(false)
	for i in range(mini(done.size(), members.size())):
		revealed[i] = done[i]
		if revealed[i]:
			_perm_r[i] = PERM_R
	var tex := _build_texture(seed_value, ext)
	_wall_sprite = Sprite2D.new()
	_wall_sprite.texture = _wall_tex
	_wall_sprite.centered = true
	_wall_sprite.scale = Vector2(PX, PX)
	_wall_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_size = Vector2(tex.get_width(), tex.get_height())
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.centered = true
	_sprite.scale = Vector2(PX, PX)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat.shader = sh
	_mat.set_shader_parameter("tex_size", _tex_size)
	_mat.set_shader_parameter("ceil_tex", _ceil_tex)
	_sprite.material = _mat
	_push_perm()
	# Escurecimento do exterior (abaixo da rocha, acima do chão do mapa).
	_dark = ColorRect.new()
	_dark.size = Vector2(5000, 5000)
	_dark.position = -_dark.size / 2.0
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.z_index = -2
	_dark_mat = ShaderMaterial.new()
	var dsh := Shader.new()
	dsh.code = DARK_SHADER
	_dark_mat.shader = dsh
	_dark_mat.set_shader_parameter("radii", Vector2(RX_PX * 0.95, RY_PX * 0.95))
	_dark_mat.set_shader_parameter("box", _dark.size)
	var parr := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for i in range(members.size()):
		parr[i] = members[i]
	_dark_mat.set_shader_parameter("pts", parr)
	_dark_mat.set_shader_parameter("count", members.size())
	_dark_mat.set_shader_parameter("has_edge", has_edge)
	_dark.material = _dark_mat
	add_child(_dark)
	_inner = Node2D.new()
	_inner.z_index = -1
	add_child(_inner)
	add_child(_wall_sprite)
	add_child(_sprite)
	_outer = Node2D.new()
	_outer.z_index = 1
	add_child(_outer)
	_roof = Node2D.new()
	_roof.z_index = 1
	add_child(_roof)
	_build_crystals(seed_value)
	_build_roof(seed_value)
	# "?" de cada nodo escondido + botão para hover/clique.
	for i in range(members.size()):
		var g := Sprite2D.new()
		g.texture = _build_glyph()
		g.scale = Vector2(PX, PX)
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.position = members[i]
		add_child(g)
		_glyphs.append(g)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.size = Vector2(RX_PX * 0.9, RY_PX * 0.8)
		b.position = members[i] - b.size / 2.0
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var idx: int = i
		b.mouse_entered.connect(func(): hovered.emit(idx, true))
		b.mouse_exited.connect(func(): hovered.emit(idx, false))
		b.pressed.connect(func(): clicked.emit(idx))
		add_child(b)
		_buttons.append(b)

func _finish_now() -> void:
	_spawn_remains()
	queue_free()

func all_revealed() -> bool:
	for r in revealed:
		if not r:
			return false
	return true

func _process(delta: float) -> void:
	_t += delta
	_light_tick()
	for i in range(_glyphs.size()):
		var g: Sprite2D = _glyphs[i]
		var near_foco: bool = lit > 0.05 and _pawn_local.distance_to(members[i]) < SPOT_PX * 1.0
		g.visible = (not revealed[i]) and (not near_foco) and not dissolving
		if not g.visible:
			continue
		var hv: bool = _hover_idx == i
		if not _reach[i] and not hv:
			# fora de alcance: pequeno, parado e escuro, quase da cor da rocha
			g.position = members[i] + Vector2(0, -2.0)
			var s0: float = lerpf(g.scale.x / float(PX), 0.8, minf(1.0, delta * 14.0))
			g.scale = Vector2(s0, s0) * float(PX)
			g.modulate = Color(0.56, 0.47, 0.6, 0.9)
			continue
		var bob: float = sin(_t * 2.2 + float(i)) * 3.0
		g.position = members[i] + Vector2(0, bob - 2.0)
		var s: float = lerpf(g.scale.x / float(PX), 1.45 if hv else 1.15, minf(1.0, delta * 14.0))
		g.scale = Vector2(s, s) * float(PX)
		g.modulate = Color(1.0, 0.9, 0.45) if hv else Color(0.85, 1.0, 1.0, 0.85 + 0.15 * sin(_t * 2.2 + float(i)))

func _light_tick() -> void:
	lit = lerpf(lit, _lit_target, 0.12)
	_roof_tick()
	if _dark_mat != null:
		_dark_mat.set_shader_parameter("strength", 0.5 * lit)
	for g in _glows:
		var sp: Sprite2D = g[0]
		if not is_instance_valid(sp):
			continue
		var pulse: float = 0.75 + 0.25 * sin(_t * 1.6 + float(g[2]))
		sp.modulate.a = float(g[1]) * pulse * (1.0 + 0.9 * lit)
	for cs in _crystal_sprites:
		if is_instance_valid(cs):
			cs.modulate = Color(1, 1, 1).lerp(Color(1.12, 1.1, 1.18), lit)

func _push_perm() -> void:
	if _mat == null:
		return
	var pp := PackedVector2Array([Vector2(-1000, -1000), Vector2(-1000, -1000), Vector2(-1000, -1000)])
	var pr := PackedFloat32Array([0.0, 0.0, 0.0])
	for i in range(members.size()):
		pp[i] = members[i] / float(PX) + _tex_size / 2.0
		pr[i] = _perm_r[i]
	_mat.set_shader_parameter("perm_pos", pp)
	_mat.set_shader_parameter("perm_r", pr)

# Caminhos que saem da gruta: segmentos (mundo) que ficam iluminados mesmo com o exterior escuro.
func set_exits(segs: Array) -> void:
	if _dark_mat == null:
		return
	var arr := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
	var n: int = mini(segs.size(), 4)
	for i in range(n):
		var a: Vector2 = segs[i][0] - position
		var b: Vector2 = segs[i][1] - position
		arr[i] = Vector4(a.x, a.y, b.x, b.y)
	_dark_mat.set_shader_parameter("segs", arr)
	_dark_mat.set_shader_parameter("seg_count", n)

# O jogador pode clicar neste nodo agora? (só os filhos do nodo atual)
var _ceil_img: Image = null
var _reach: Array[bool] = [false, false, false]

# A peça está atravessando uma entrada? Devolve [visibilidade 0..1, já está do lado de dentro],
# ou [] se não está em nenhuma. Ela escurece e some ao entrar na boca e reaparece lá dentro.
func mouth_state(world: Vector2) -> Array:
	var p: Vector2 = world - position
	for sg in mouth_segs:
		var a: Vector2 = sg[0]
		var ab: Vector2 = sg[1] - a
		var t: float = (p - a).dot(ab) / ab.dot(ab)
		if t < -0.02 or t > 1.02 or p.distance_to(a + ab * t) > 14.0:
			continue
		var tv: float = sg[2]
		var w: float = 0.17
		if t < tv:
			return [1.0 - smoothstep(tv - w, tv, t), false]
		return [smoothstep(tv, tv + w, t), true]
	return []

# Há rocha desta gruta (teto, face ou boca) neste ponto do mundo?
func roof_at(world: Vector2) -> bool:
	if _ceil_img == null:
		return false
	var q: Vector2 = (world - position) / float(PX) + _tex_size / 2.0
	var qx: int = int(floor(q.x))
	var qy: int = int(floor(q.y))
	if qx < 0 or qy < 0 or qx >= _ceil_img.get_width() or qy >= _ceil_img.get_height():
		return false
	return _ceil_img.get_pixel(qx, qy).a > 0.5

# O "?" de um nodo que o jogador pode escolher agora fica aceso; os outros ficam apagados.
func set_reachable(idx: int, on: bool) -> void:
	if idx >= 0 and idx < _reach.size():
		_reach[idx] = on

func set_clickable(idx: int, on: bool) -> void:
	if idx < 0 or idx >= _buttons.size():
		return
	_buttons[idx].mouse_filter = Control.MOUSE_FILTER_STOP if (on and not revealed[idx]) else Control.MOUSE_FILTER_IGNORE
	if not on and _hover_idx == idx:
		set_hover(false, idx)

# Atualiza o foco: `pawn_world` é a posição da peça no mundo; só abre quando `active`.
func update_spot(pawn_world: Vector2, active: bool) -> void:
	if _mat == null or dissolving:
		return
	if not active:
		_mat.set_shader_parameter("hole_r", 0.0)
		_lit_target = 0.0
		spot_r = 0.0
		_pawn_local = Vector2(-9999, -9999)
		return
	var p: Vector2 = pawn_world - position
	_pawn_local = p
	var dist: float = _dist_to_cave(p)
	var t: float = clampf((REF_PX * 1.15 - dist) / (REF_PX * 0.65), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_mat.set_shader_parameter("hole_pos", p / float(PX) + _tex_size / 2.0)
	_mat.set_shader_parameter("hole_r", SPOT_PX * t / float(PX))
	_lit_target = t
	spot_r = SPOT_PX * t

func set_hover(on: bool, idx: int) -> void:
	if on:
		_hover_idx = idx
	elif _hover_idx == idx:
		_hover_idx = -1
	var any: bool = _hover_idx >= 0
	if _sprite != null:
		_sprite.modulate = Color(1.25, 1.2, 1.35) if any else Color.WHITE
	if _mat != null:
		_mat.set_shader_parameter("hover", 1.0 if any else 0.0)

# O nodo `idx` foi visitado: abre uma janela permanente nele.
func reveal_node(idx: int, duration: float = 0.45) -> void:
	revealed[idx] = true
	if idx < _buttons.size():
		_buttons[idx].mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_perm_r[idx] = v
		_push_perm(), 0.0, PERM_R, duration)
	await tw.finished

# O teto se desfaz em pixels; paredes e cristais ficam no mapa.
func dissolve_away(duration: float = 0.8) -> void:
	if _mat == null:
		queue_free()
		return
	dissolving = true
	for b in _buttons:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lit_target = 0.0
	_roof_items.clear()
	var roof_tw := _roof.create_tween()
	roof_tw.tween_property(_roof, "modulate:a", 0.0, duration * 0.6)
	var tw := create_tween()
	tw.tween_method(func(v: float): _mat.set_shader_parameter("dissolve", v), 0.0, 1.05, duration)
	await tw.finished
	_spawn_remains()
	queue_free()

# Paredes e cristais viram nós independentes do pai (ficam depois do teto sumir).
func _spawn_remains() -> void:
	var par := get_parent()
	if par == null:
		return
	var wall := Sprite2D.new()
	wall.texture = _wall_tex
	wall.scale = Vector2(PX, PX)
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.position = position
	wall.z_index = 6
	par.add_child(wall)
	for pair in [[_inner, 7], [_outer, 8]]:
		var nd: Node2D = pair[0]
		if nd != null and is_instance_valid(nd):
			var gp: Vector2 = nd.global_position
			remove_child(nd)
			par.add_child(nd)
			nd.global_position = gp
			nd.z_index = pair[1]
	for g in _glows:
		var sp: Sprite2D = g[0]
		if is_instance_valid(sp):
			sp.modulate.a = 0.2
			var tw2 := sp.create_tween().set_loops()
			tw2.tween_property(sp, "modulate:a", 0.32, 1.4 + float(g[2]) * 0.1).set_trans(Tween.TRANS_SINE)
			tw2.tween_property(sp, "modulate:a", 0.12, 1.4 + float(g[2]) * 0.1).set_trans(Tween.TRANS_SINE)
	for cs in _crystal_sprites:
		if is_instance_valid(cs):
			cs.modulate = Color.WHITE
	_glows = []
	_crystal_sprites = []

# ------------------------------------------------------------- textura ----

func _hash(x: int, y: int, s: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0

var _wall_l: PackedFloat32Array = PackedFloat32Array()   # x (nativo) da parede esquerda por linha
var _wall_r: PackedFloat32Array = PackedFloat32Array()
var _tex_origin: Vector2 = Vector2.ZERO
var _wall_range: Vector2 = Vector2.ZERO
var _dep: PackedByteArray = PackedByteArray()
var _wall_sprite: Sprite2D
var _others_w: Array = []      # posições (mundo) dos outros nodos do mapa: a parede abre espaço
var _paths_g: Array = []       # trilhas do mapa: listas de casas (grade do mundo)
var _busy_cells: Dictionary = {}   # casas com trilha (e as vizinhas das diagonais)
var mouth_segs: Array = []   # [fora (local px), dentro (local px), fração onde a peça some na boca]
var _mouth_pts: Array = []   # centro (local, px) de cada entrada
var _pawn_cells: Dictionary = {}
var _trail_cells: Dictionary = {}   # casas (relativas à gruta) por onde passa alguma trilha
var _won_l: PackedByteArray = PackedByteArray()   # linha tem parede à esquerda / direita
var _won_r: PackedByteArray = PackedByteArray()
var _ceil_store: PackedByteArray = PackedByteArray()
var _cw: int = 0
var _ch: int = 0
var _cx0: int = 0
var _cy0: int = 0
var _grid0: Vector2i = Vector2i.ZERO   # casa (coluna, fileira) do centro da gruta
var _wall_ol: PackedFloat32Array = PackedFloat32Array()   # x externo da parede esquerda por linha
var _wall_or: PackedFloat32Array = PackedFloat32Array()

func _build_texture(seed_value: int, span_px: Vector2) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pw: float = float(rng.randi_range(14, 18))          # espessura das paredes (px nativos)
	var w: int = int(ceil(span_px.x / float(PX))) + int(pw) * 2 + 10
	var h: int = int(ceil(span_px.y / float(PX) * 1.12)) + 10 + 2 * (FACE_D + FACE_SH + 2)
	w += 64   # folga: bordas, face e bocas nunca são cortadas pelo limite da textura
	h += 64
	w += w % 2
	h += h % 2
	var c := Vector2(w / 2.0, h / 2.0)
	var _ph1: float = rng.randf() * TAU
	var _ph2: float = rng.randf() * TAU
	var ceil_m := PackedByteArray()
	var wall_m := PackedByteArray()
	ceil_m.resize(w * h)
	wall_m.resize(w * h)
	var y_first: int = h
	var y_last: int = -1
	var xl := PackedFloat32Array()
	var xr := PackedFloat32Array()
	xl.resize(h)
	xr.resize(h)
	@warning_ignore("integer_division")
	_calc_nb_cells(Vector2i(-int(w / 52) - 2, int(w / 52) + 2), Vector2i(-int(h / 52) - 2, int(h / 52) + 2), seed_value)
	# Casas do teto desta gruta (com os buraquinhos entre grutas coladas tapados).
	var cellc: Dictionary = {}
	@warning_ignore("integer_division")
	var crx: int = int(w / 52) + 2
	@warning_ignore("integer_division")
	var cry: int = int(h / 52) + 2
	for csy in range(-cry, cry + 1):
		for csx in range(-crx, crx + 1):
			var ce: float = mask_value(Vector2(float(csx), float(csy)) * TILE, members, has_edge)
			if ce <= 0.9 + (_hash(csx, csy, seed_value + 21) - 0.5) * 0.34 and not _nb_cells.has(Vector2i(csx, csy)) and _cell_on_board(csx, csy):
				cellc[Vector2i(csx, csy)] = true
	var fill: Array = []
	for csy in range(-cry, cry + 1):
		for csx in range(-crx, crx + 1):
			var cc := Vector2i(csx, csy)
			if cellc.has(cc) or _nb_cells.has(cc) or not _cell_on_board(csx, csy):
				continue
			var has: Array = []
			var own_n: int = 0
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var hit: bool = cellc.has(cc + o) or _nb_cells.has(cc + o)
				has.append(hit)
				if cellc.has(cc + o):
					own_n += 1
			# fenda de uma casa entre duas rochas (lado a lado ou em cima/embaixo): tapa
			if own_n >= 1 and ((has[0] and has[1]) or (has[2] and has[3])):
				fill.append(cc)
	for cc in fill:
		cellc[cc] = true
	# Cada caminho da peça que chega/sai de um nodo DESTA gruta cruza a borda UMA vez só:
	# andando do nodo para fora, depois da primeira casa aberta, toda rocha desta gruta que
	# o caminho ainda encostaria é removida (senão a peça entraria e sairia em zigue-zague).
	var mcells2: Dictionary = {}
	for m in members:
		mcells2[Vector2i(int(roundf(m.x / TILE)), int(roundf(m.y / TILE)))] = true
	for path in pawn_paths:
		if path.is_empty():
			continue
		var seq: Array = []
		for g in path:
			seq.append(Vector2i(g.x - _grid0.x, g.y - _grid0.y))
		if mcells2.has(seq[-1]) and not mcells2.has(seq[0]):
			seq.reverse()
		elif not mcells2.has(seq[0]):
			continue
		var outside: bool = false
		for i in range(seq.size()):
			var sc3: Vector2i = seq[i]
			if not outside:
				if not cellc.has(sc3) and not _nb_cells.has(sc3):
					outside = true
			elif cellc.has(sc3) and not mcells2.has(sc3):
				cellc.erase(sc3)
				# as casas ao lado do passo em diagonal também abrem (a peça passa pela quina)
				var pv: Vector2i = seq[i - 1]
				for sd in [Vector2i(sc3.x, pv.y), Vector2i(pv.x, sc3.y)]:
					if cellc.has(sd) and not mcells2.has(sd):
						cellc.erase(sd)
	for y in range(h):
		xl[y] = 1e9
		xr[y] = -1e9
		for x in range(w):
			# O teto é feito de CASAS do tabuleiro (26x26): cada casa ou é rocha ou não é.
			var sx: int = int(floor((float(x) - c.x + 13.0) / 26.0))
			var sy: int = int(floor((float(y) - c.y + 13.0) / 26.0))
			var pp := Vector2(float(sx), float(sy)) * 26.0 * float(PX)
			var _e: float = mask_value(pp, members, has_edge)
			var _jit: float = (_hash(sx, sy, seed_value + 21) - 0.5) * 0.34
			if cellc.has(Vector2i(sx, sy)):
				ceil_m[y * w + x] = 1
				xl[y] = minf(xl[y], float(x))
				xr[y] = maxf(xr[y], float(x))
		if xr[y] >= 0.0:
			y_first = mini(y_first, y)
			y_last = maxi(y_last, y)
	# Contorno suavizado por linha (mín/máx numa janela) e extensão nas pontas.
	var sl := PackedFloat32Array()
	var sr := PackedFloat32Array()
	sl.resize(h)
	sr.resize(h)
	for y in range(h):
		var yy: int = clampi(y, y_first, y_last)
		var lo: float = 1e9
		var hi: float = -1e9
		for k in range(-6, 7):
			var y2: int = clampi(yy + k, y_first, y_last)
			if xr[y2] >= 0.0:
				lo = minf(lo, xl[y2])
				hi = maxf(hi, xr[y2])
		sl[y] = lo
		sr[y] = hi
	var half_h: float = float(y_last - y_first) / 2.0 * 1.12
	var cy: float = float(y_first + y_last) / 2.0
	for y in range(h):
		var ty: float = (float(y) - cy) / half_h
		if absf(ty) >= 1.0:
			continue
		@warning_ignore("integer_division")
		var band: int = int(y / 3)
		var taper: float = 1.0 - pow(absf(ty), 3.0) * 0.7
		var hwl: float = pw * taper + (_hash(band, 1, seed_value + 5) - 0.5) * 5.0
		var hwr: float = pw * taper + (_hash(band, 2, seed_value + 5) - 0.5) * 5.0
		for x in range(w):
			if ceil_m[y * w + x] == 1:
				continue
			var fx: float = float(x)
			if false and fx < c.x and fx >= sl[y] - hwl and fx <= sl[y] + 6.0:
				wall_m[y * w + x] = 1
			elif false and fx >= c.x and fx <= sr[y] + hwr and fx >= sr[y] - 6.0:
				wall_m[y * w + x] = 1
	_wall_ol.resize(h)
	_wall_or.resize(h)
	for y in range(h):
		_wall_ol[y] = sl[y]
		_wall_or[y] = sr[y]
		for x in range(w):
			if wall_m[y * w + x] == 1:
				if float(x) < c.x:
					_wall_ol[y] = minf(_wall_ol[y], float(x))
				else:
					_wall_or[y] = maxf(_wall_or[y], float(x))
	_wall_l = sl
	_wall_r = sr
	_tex_origin = c
	_wall_range = Vector2(float(y_first), float(y_last))
	# Volume: cada bloco de rocha ganha uma FACE FRONTAL (extrusão para baixo, como as
	# colunas e a borda do tabuleiro, vistos de cima e levemente de frente) e uma sombra no chão.
	# cls: 1 = topo, 2 = face, 3 = sombra. own: 1 = teto (se desfaz), 2 = parede (fica).
	var cls := PackedByteArray()
	var own := PackedByteArray()
	cls.resize(w * h)
	own.resize(w * h)
	_dep = PackedByteArray()
	_dep.resize(w * h)
	for x in range(w):
		var last_own: int = 0
		var since: int = 0
		for y in range(h):
			var i: int = y * w + x
			var top_own: int = 1 if ceil_m[i] == 1 else (2 if wall_m[i] == 1 else 0)
			if top_own != 0:
				cls[i] = 1
				own[i] = top_own
				last_own = top_own
				since = 0
			elif last_own != 0:
				since += 1
				if _nb_cells.has(Vector2i(int(floor((float(x) - c.x + 13.0) / 26.0)), int(floor((float(y) - c.y + 13.0) / 26.0)))):
					last_own = 0   # ali é o teto da gruta vizinha: sem face por cima
				elif since <= FACE_D:
					cls[i] = 2
					own[i] = last_own
					_dep[i] = since
				elif since <= FACE_D + FACE_SH:
					cls[i] = 3
					own[i] = last_own
				else:
					last_own = 0
	_ceil_store = ceil_m
	_cw = w
	_ch = h
	_cx0 = int(c.x) - 13
	_cy0 = int(c.y) - 13
	_trail_cells = {}
	_pawn_cells = {}
	_busy_cells = {}
	for path in _paths_g:
		for gi in range(path.size()):
			var tg: Vector2i = path[gi]
			_busy_cells[Vector2i(tg.x - _grid0.x, tg.y - _grid0.y)] = true
			if gi > 0:
				var tg0: Vector2i = path[gi - 1]
				_busy_cells[Vector2i(tg.x - _grid0.x, tg0.y - _grid0.y)] = true
				_busy_cells[Vector2i(tg0.x - _grid0.x, tg.y - _grid0.y)] = true
	_mouth_pts = []
	mouth_segs = []
	for path in pawn_paths:
		for gi in range(path.size()):
			var g: Vector2i = path[gi]
			_pawn_cells[Vector2i(g.x - _grid0.x, g.y - _grid0.y)] = true
			if gi > 0:
				var g0: Vector2i = path[gi - 1]
				_pawn_cells[Vector2i(g.x - _grid0.x, g0.y - _grid0.y)] = true
				_pawn_cells[Vector2i(g0.x - _grid0.x, g.y - _grid0.y)] = true
	for path in _paths_g + pawn_paths:
		for g in path:
			_trail_cells[Vector2i(g.x - _grid0.x, g.y - _grid0.y)] = true
	var img_all := _paint_vol(cls, own, 0, w, h, c, seed_value)
	var cm := Image.create(w, h, false, Image.FORMAT_RGBA8)
	cm.fill(Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			if own[y * w + x] == 1:
				cm.set_pixel(x, y, Color(1, 1, 1, 1))
	_add_mouths(img_all, cm)
	_add_fringe(img_all, cm, cls, ceil_m, w, h, c, seed_value)
	_ceil_tex = ImageTexture.create_from_image(cm)
	_wall_img = _build_walls(w, h, c, seed_value, y_first, y_last)
	# A parede só existe DEBAIXO da rocha: nada dela aparece com a gruta fechada (nem pelas
	# frestas da face), só quando o foco abre.
	for wy in range(h):
		for wx2 in range(w):
			if _wall_img.get_pixel(wx2, wy).a > 0.0 and img_all.get_pixel(wx2, wy).a < 0.5:
				_wall_img.set_pixel(wx2, wy, Color(0, 0, 0, 0))
	_wall_tex = ImageTexture.create_from_image(_wall_img)
	_ceil_img = img_all
	return ImageTexture.create_from_image(img_all)


# Beiradas e quinas: células vazias coladas no teto ganham as peças de borda (rocha irregular),
# no lugar do contorno reto de 1 px. Entram na máscara do teto (somem junto com ele).
func _add_fringe(img: Image, cm: Image, cls: PackedByteArray, ceil_m: PackedByteArray, w: int, h: int, c: Vector2, _seed_value: int) -> void:
	var P: Array = _load_imgs(["teto_beirada_N", "teto_beirada_L", "teto_beirada_O", "teto_quina_NE", "teto_quina_NO", "teto_quina_SE", "teto_quina_SO"])
	if P.size() < 7:
		return
	var x0: int = int(c.x) - 13
	var y0: int = int(c.y) - 13
	var nx: int = int(ceil(float(w) / 26.0)) + 2
	var ny: int = int(ceil(float(h) / 26.0)) + 2
	var csx: int = -int(ceil(float(x0) / 26.0)) - 1
	var csy: int = -int(ceil(float(y0) / 26.0)) - 1
	var is_c := func(sx: int, sy: int) -> bool:
		var px: int = x0 + sx * 26 + 13
		var py: int = y0 + sy * 26 + 13
		if px < 0 or py < 0 or px >= w or py >= h:
			return false
		return ceil_m[py * w + px] == 1
	for sy in range(csy, csy + ny):
		for sx in range(csx, csx + nx):
			if is_c.call(sx, sy) or _pawn_cells.has(Vector2i(sx, sy)) or _nb_cells.has(Vector2i(sx, sy)) or not _cell_on_board(sx, sy):
				continue
			var piece: int = -1
			if is_c.call(sx, sy + 1):
				piece = 0   # teto ao sul: borda norte
			elif is_c.call(sx - 1, sy):
				piece = 1   # teto a oeste: borda leste (rocha à esquerda)
			elif is_c.call(sx + 1, sy):
				piece = 2   # teto a leste (rocha à direita)
			elif is_c.call(sx - 1, sy + 1):
				piece = 3   # diagonal SO
			elif is_c.call(sx + 1, sy + 1):
				piece = 4   # diagonal SE
			elif is_c.call(sx - 1, sy - 1):
				piece = 5   # diagonal NO
			elif is_c.call(sx + 1, sy - 1):
				piece = 6
			if piece < 0:
				continue
			var im: Image = P[piece]
			# peça inteira ou nada: se a casa já tem rocha (face de cima, etc.) ou sai da textura, pula
			var free: bool = x0 + sx * 26 >= 0 and y0 + sy * 26 >= 0 and x0 + sx * 26 + 25 < w and y0 + sy * 26 + 25 < h
			if free:
				for ly in range(26):
					for lx in range(26):
						if cls[(y0 + sy * 26 + ly) * w + x0 + sx * 26 + lx] != 0:
							free = false
			if not free:
				continue
			for ly in range(26):
				for lx in range(26):
					var px: int = x0 + sx * 26 + lx
					var py: int = y0 + sy * 26 + ly
					if px < 0 or py < 0 or px >= w or py >= h:
						continue
					var pc: Color = im.get_pixel(lx, ly)
					if pc.a < 0.05 or cls[py * w + px] != 0:
						continue
					if img.get_pixel(px, py).a > 0.9:
						continue
					img.set_pixel(px, py, pc)
					if pc.a > 0.5:
						cm.set_pixel(px, py, Color(1, 1, 1, 1))
	# onde não coube peça de borda, o topo do teto fecha com o contorno escuro
	var outline := Color("#1f161d")
	for y in range(h):
		for x in range(w):
			if cls[y * w + x] != 1:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				var ax: int = x + o.x
				var ay: int = y + o.y
				if ax < 0 or ay < 0 or ax >= w or ay >= h:
					continue
				if img.get_pixel(ax, ay).a < 0.05 and not _nb_cells.has(Vector2i(int(floor(float(ax - x0) / 26.0)), int(floor(float(ay - y0) / 26.0)))):
					img.set_pixel(x, y, outline)
					break


func _cell_ceil(sx: int, sy: int) -> bool:
	var px: int = _cx0 + sx * 26 + 13
	var py: int = _cy0 + sy * 26 + 13
	if px < 0 or py < 0 or px >= _cw or py >= _ch:
		return false
	return _ceil_store[py * _cw + px] == 1

# ENTRADAS: onde uma trilha cruza a borda do teto, a rocha ganha uma boca escura em arco.
func _union_ceil(c: Vector2i) -> bool:
	return _cell_ceil(c.x, c.y) or _nb_cells.has(c)

func _add_mouths(img: Image, cm: Image) -> void:
	var done: Dictionary = {}
	for path in (pawn_paths if not pawn_paths.is_empty() else _paths_g):
		# Todo passo em que a peça cruza a borda da ROCHA (desta gruta ou de uma vizinha colada)
		# ganha a sua entrada. Cada gruta pinta a parte que cai na rocha dela.
		for k in range(path.size() - 1):
			var a := Vector2i(path[k].x - _grid0.x, path[k].y - _grid0.y)
			var b := Vector2i(path[k + 1].x - _grid0.x, path[k + 1].y - _grid0.y)
			var ca: bool = _union_ceil(a)
			var cb: bool = _union_ceil(b)
			if ca == cb:
				continue
			var inn: Vector2i = a if ca else b
			var out: Vector2i = b if ca else a
			var d: Vector2i = out - inn
			# A peça anda de centro a centro em diagonal: cruza a borda pela QUINA entre as casas.
			var m := Vector2i(inn.x + d.x, inn.y)   # casa ao lado, por cuja face a peça passa se vier de baixo
			var mp: Vector2
			var arch: bool = d.y > 0 and _union_ceil(m) and not _union_ceil(Vector2i(m.x, m.y + 1))
			if arch:
				mp = Vector2(float(m.x) * TILE, float(m.y) * TILE + 24.0 * float(PX))
			else:
				mp = Vector2((float(inn.x) + 0.5 * float(d.x)) * TILE, (float(inn.y) + 0.5 * float(d.y)) * TILE)
			# duas entradas quase no mesmo lugar viram uma só (nada de bocas emboladas)
			var dup: bool = false
			for q in _mouth_pts:
				if q.distance_to(mp) < 70.0 and q.distance_to(mp) > 0.5:
					dup = true
			var key := Vector2i(int(mp.x), int(mp.y))
			if dup or done.has(key):
				if not dup:
					mouth_segs.append([Vector2(out) * TILE, Vector2(inn) * TILE, 0.2 if arch else 0.5])
				continue
			done[key] = true
			if arch:
				if _cell_ceil(m.x, m.y):
					_paint_mouth(img, cm, m, Vector2i(0, 1), d)
			else:
				_paint_corner_mouth(img, cm, inn, d)
			_mouth_pts.append(mp)
			mouth_segs.append([Vector2(out) * TILE, Vector2(inn) * TILE, 0.2 if arch else 0.5])

# Boca na QUINA da casa (a peça entra exatamente por ali): um vão escuro redondo na rocha.
func _paint_corner_mouth(img: Image, _cm: Image, cell: Vector2i, d: Vector2i) -> void:
	var fill := Color("#0d070c")
	var line := Color("#1f161d")
	var rim := Color("#685563")
	var kx: float = float(_cx0 + cell.x * 26) + 12.5 + 13.0 * float(d.x)
	var ky: float = float(_cy0 + cell.y * 26) + 12.5 + 13.0 * float(d.y)
	var R: float = 14.0
	for py in range(int(ky - R - 3.0), int(ky + R + 4.0)):
		for px in range(int(kx - R - 3.0), int(kx + R + 4.0)):
			if px < 0 or py < 0 or px >= _cw or py >= _ch:
				continue
			if img.get_pixel(px, py).a < 0.5:
				continue
			var v: float = Vector2(float(px) - kx, float(py) - ky).length() / R
			if v <= 0.84:
				img.set_pixel(px, py, fill)
			elif v <= 1.0:
				img.set_pixel(px, py, line)
			elif v <= 1.12:
				img.set_pixel(px, py, rim)

func _paint_mouth(img: Image, cm: Image, cell: Vector2i, side: Vector2i, _d: Vector2i = Vector2i.ZERO) -> void:
	var fill := Color("#0d070c")
	var line := Color("#1f161d")
	var rim := Color("#685563")
	var cx: float = float(_cx0 + cell.x * 26) + 12.5
	var cy: float = float(_cy0 + cell.y * 26) + 12.5
	var HW: float = 12.0
	for ly in range(-16, 40):
		for lx in range(-16, 40):
			var px: int = _cx0 + cell.x * 26 + lx
			var py: int = _cy0 + cell.y * 26 + ly
			if px < 0 or py < 0 or px >= _cw or py >= _ch:
				continue
			var v: float = 9.0   # > 1 fora; <= 1 dentro da boca
			if side.y > 0:
				# boca na FACE frontal (abaixo da casa): arco em pé, do alto da face até o chão
				var dep: float = float(py) - (cy + 12.5)        # 0.5 .. 22 dentro da face
				if dep < 0.0 or dep > 22.0:
					continue
				var dx: float = absf(float(px) - cx) / HW
				if dep >= 10.0:
					v = dx
				else:
					v = sqrt(dx * dx + pow((10.0 - dep) / 9.0, 2.0))
			elif side.y < 0:
				var dep2: float = float(py) - (cy - 13.0)       # entra pela borda de cima
				if dep2 < 0.0:
					continue
				v = sqrt(pow(absf(float(px) - cx) / HW, 2.0) + pow(dep2 / 12.0, 2.0))
			else:
				var edge_x: float = cx + float(side.x) * 13.0
				var dep3: float = (edge_x - float(px)) * float(side.x)
				if dep3 < 0.0:
					continue
				v = sqrt(pow(absf(float(py) - cy) / HW, 2.0) + pow(dep3 / 12.0, 2.0))
			var col: Color
			if v <= 0.86:
				col = fill
			elif v <= 1.0:
				col = line
			elif v <= 1.16:
				if img.get_pixel(px, py).a < 0.5:
					continue
				col = rim
			else:
				continue
			img.set_pixel(px, py, col)
			cm.set_pixel(px, py, Color(1, 1, 1, 1))

static var _wall_tile_imgs: Array = []

# Coluna de rocha com as DUAS bordas irregulares: parede_N (borda irregular à direita) por
# cima de parede_N_esq (irregular à esquerda), defasadas na vertical para os estreitamentos
# não coincidirem.
static func _wall_tiles() -> Array:
	if _wall_tile_imgs.is_empty():
		var a: Array = _load_imgs(["parede_1", "parede_2", "parede_3"])
		var b: Array = _load_imgs(["parede_1_esq", "parede_2_esq", "parede_3_esq"])
		if a.size() < 3 or b.size() < 3:
			return []
		for i in range(3):
			var t := Image.create(44, 52, false, Image.FORMAT_RGBA8)
			t.fill(Color(0, 0, 0, 0))
			var bi: Image = b[(i + 1) % 3]
			for y in range(52):
				for x in range(30):
					var pc: Color = bi.get_pixel(x, (y + 26) % 52)
					if pc.a > 0.05:
						t.set_pixel(x, y, pc)
			var ai: Image = a[i]
			for y in range(52):
				for x in range(30):
					var pc2: Color = ai.get_pixel(x, y)
					if pc2.a > 0.5 or (pc2.a > 0.05 and t.get_pixel(x + 14, y).a < 0.05):
						t.set_pixel(x + 14, y, pc2)
			_wall_tile_imgs.append(t)
	return _wall_tile_imgs

# PAREDES: colunas de rocha que acompanham o contorno da gruta, por BAIXO do teto. Metade fica
# para fora, metade para dentro (aparece quando o foco abre). Abrem passagem onde há trilha ou
# outro nodo do mapa; cada trecho termina com uma face frontal e pedras soltas no pé.
func _build_walls(w: int, h: int, c: Vector2, seed_value: int, y_first: int, y_last: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_won_l.resize(h)
	_won_r.resize(h)
	_won_l.fill(0)
	_won_r.fill(0)
	_wall_ol.resize(h)
	_wall_or.resize(h)
	var tiles: Array = []
	var faces: Array = []
	_wm = PackedByteArray()
	_wm.resize(w * h)
	_wfeet = []
	var block: Array = []   # [pos nativa, meia-largura, meia-altura]
	for wp in _others_w:
		block.append([c + (wp - position) / float(PX), 30.0, 22.0])
	for cell in _trail_cells:
		block.append([Vector2(float(_cx0 + cell.x * 26) + 13.0, float(_cy0 + cell.y * 26) + 13.0), 30.0, 17.0])
	for m in members:
		block.append([c + m / float(PX), 44.0, 26.0])
	var half_h: float = maxf(float(y_last - y_first) / 2.0, 1.0)
	var cy: float = float(y_first + y_last) / 2.0
	var loose: Array = _load_imgs(["rocha_solta_1", "rocha_solta_2", "rocha_solta_3", "rocha_solta_4"])
	for side in [-1, 1]:
		var on := PackedByteArray()
		var ex := PackedInt32Array()
		on.resize(h)
		ex.resize(h)
		for y in range(h):
			if absf((float(y) - cy) / half_h) > 0.86:
				continue
			var found: int = -1
			var x: int = 0 if side < 0 else w - 1
			while x >= 0 and x < w:
				var pp := Vector2(float(x) - c.x, float(y) - c.y) * float(PX)
				if mask_value(pp, members, has_edge) <= 0.94:
					found = x
					break
				x -= side * 2
			if found < 0:
				continue
			var wx: int = found + side * 6
			ex[y] = wx
			var ok: bool = not _nb_cells.has(Vector2i(int(floor((float(wx) - c.x + 13.0) / 26.0)), int(floor((float(y) - c.y + 13.0) / 26.0))))
			for bl in block:
				var bp: Vector2 = bl[0]
				if absf(bp.x - float(wx)) < float(bl[1]) and absf(bp.y - float(y)) < float(bl[2]):
					ok = false
					break
			on[y] = 1 if ok else 0
		# Colunas em degraus: o contorno é quantizado em blocos de 26 linhas (a mediana do bloco),
		# para a rocha subir reta e mudar de posição em degraus, sem inclinar o sprite.
		var yq: int = ((int(c.y) - 13) % 26) - 26
		while yq < h:
			var acc: int = 0
			var cnt: int = 0
			for k in range(maxi(yq, 0), mini(yq + 26, h)):
				if ex[k] != 0:
					acc += ex[k]
					cnt += 1
			if cnt > 0:
				var q: int = int(roundf(float(acc) / float(cnt)))
				for k in range(maxi(yq, 0), mini(yq + 26, h)):
					if ex[k] != 0:
						ex[k] = q
			yq += 26
		# descarta trechos curtos demais
		var y: int = 0
		while y < h:
			if on[y] == 0:
				y += 1
				continue
			var y2: int = y
			while y2 < h and on[y2] == 1:
				y2 += 1
			if y2 - y < 30:
				for k in range(y, y2):
					on[k] = 0
			else:
				_paint_wall_run(img, tiles, faces, loose, on, ex, y, y2, side, w, h, seed_value)
			y = y2
		for yy in range(h):
			if side < 0:
				_won_l[yy] = on[yy]
				_wall_ol[yy] = float(ex[yy] - 18)
			else:
				_won_r[yy] = on[yy]
				_wall_or[yy] = float(ex[yy] + 18)
	_paint_wall_volume(img, w, h, c, seed_value)
	return img

var _wm: PackedByteArray = PackedByteArray()
var _wfeet: Array = []

# Marca na máscara um trecho de parede: cordão de rocha de largura ondulada, pontas arredondadas.
func _paint_wall_run(_img: Image, _tiles: Array, _faces: Array, _loose: Array, _on: PackedByteArray, ex: PackedInt32Array, ya: int, yb: int, side: int, w: int, _h: int, seed_value: int) -> void:
	var n: int = yb - ya
	for y in range(ya, yb):
		var r: int = y - ya
		@warning_ignore("integer_division")
		var band: int = y / 5
		var t: float = float(y % 5) / 5.0
		var h0: float = _hash(band, side + 11, seed_value + 81)
		var h1: float = _hash(band + 1, side + 11, seed_value + 81)
		var hw: float = 8.0 + lerpf(h0, h1, t) * 5.0
		var endd: int = mini(r, n - 1 - r)
		if endd < 6:
			hw *= 0.45 + 0.55 * sqrt(float(endd + 1) / 7.0)
		var sh: float = (lerpf(_hash(band, side + 17, seed_value + 82), _hash(band + 1, side + 17, seed_value + 82), t) - 0.5) * 4.0
		for px in range(int(float(ex[y]) + sh - hw), int(float(ex[y]) + sh + hw) + 1):
			if px >= 0 and px < w:
				_wm[y * w + px] = 1
	_wfeet.append(Vector2i(ex[yb - 1], yb - 1))

# Pinta as paredes como o teto: topo de pedra, face frontal e contorno (um cordão baixo de rocha).
func _paint_wall_volume(img: Image, w: int, h: int, c: Vector2, seed_value: int) -> void:
	var FH: int = 13
	var tops: Array = _topo_images()
	var faces: Array = _face_images()
	var loose: Array = _load_imgs(["rocha_solta_1", "rocha_solta_2", "rocha_solta_3", "rocha_solta_4"])
	var outline := Color("#1f161d")
	var kind := PackedByteArray()   # 1 topo, 2 face
	var dep := PackedByteArray()
	kind.resize(w * h)
	dep.resize(w * h)
	for x in range(w):
		var since: int = 999
		for y in range(h):
			var i: int = y * w + x
			if _wm[i] == 1:
				kind[i] = 1
				since = 0
			elif since < FH:
				since += 1
				kind[i] = 2
				dep[i] = since
			else:
				since = 999
	for y in range(h):
		for x in range(w):
			var i: int = y * w + x
			var k: int = kind[i]
			if k == 0:
				continue
			var edge: bool = false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or kind[ny * w + nx] == 0:
					edge = true
			if edge:
				img.set_pixel(x, y, outline)
				continue
			var col := Color("#4a3a46")
			if k == 1:
				if not tops.is_empty():
					var psx: int = int(floor((float(x) - c.x + 13.0) / 26.0))
					var psy: int = int(floor((float(y) - c.y + 13.0) / 26.0))
					var tim: Image = tops[int(_hash(psx, psy, seed_value + 91) * 2.0) % 2]
					var lx: int = (((x - int(c.x) + 13) % 26) + 26) % 26
					var ly: int = (((y - int(c.y) + 13) % 26) + 26) % 26
					col = tim.get_pixel(lx, ly)
				# fio de luz na aresta de cima/esquerda, sombra junto da face
				if y > 0 and kind[(y - 1) * w + x] == 1 and y > 1 and kind[(y - 2) * w + x] == 0:
					col = Color("#685563")
				elif x > 1 and kind[i - 2] == 0:
					col = col.lightened(0.08)
			else:
				if not faces.is_empty():
					@warning_ignore("integer_division")
					var fim: Image = faces[int(_hash(x / 52, 5, seed_value + 92) * float(faces.size())) % faces.size()]
					var fc: Color = fim.get_pixel(x % 52, clampi(int(dep[i]) + 2, 0, 15))
					col = fc if fc.a > 0.5 else Color("#31252f")
				else:
					col = Color("#31252f")
			img.set_pixel(x, y, col)
	# sombra no chão sob a face
	for y in range(1, h):
		for x in range(w):
			var i: int = y * w + x
			if kind[i] == 0 and img.get_pixel(x, y).a < 0.05:
				var up: int = 0
				for d in range(1, 4):
					if y - d >= 0 and kind[(y - d) * w + x] == 2:
						up = d
						break
				if up > 0:
					img.set_pixel(x, y, Color(0.07, 0.03, 0.08, 0.42 - 0.1 * float(up)))
	# pedras soltas ao pé de cada trecho
	if not loose.is_empty():
		for f in _wfeet:
			for k in range(2):
				var li: Image = loose[int(_hash(f.y, k + f.x, seed_value + 75) * float(loose.size())) % loose.size()]
				@warning_ignore("integer_division")
				var bx: int = f.x + int((_hash(f.y, k, seed_value + 76) - 0.5) * 30.0) - li.get_width() / 2
				var by: int = f.y + FH - 1 + int(_hash(f.y, k + 9, seed_value + 77) * 5.0)
				for ly in range(li.get_height()):
					for lx in range(li.get_width()):
						var qx: int = bx + lx
						var qy: int = by + ly
						if qx < 0 or qy < 0 or qx >= w or qy >= h:
							continue
						var lc: Color = li.get_pixel(lx, ly)
						if lc.a > 0.5 or (lc.a > 0.05 and img.get_pixel(qx, qy).a < 0.05):
							img.set_pixel(qx, qy, lc)

# Pinta o volume. `only_own`: 0 = tudo; 1/2 = só os pixels desse dono (usado para as paredes).
func _paint_vol(cls: PackedByteArray, own: PackedByteArray, only_own: int, w: int, h: int, c: Vector2, seed_value: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rocks: Array = _rock_images()
	var outline := Color("#1f161d")
	var rim := Color("#685563")
	for y in range(h):
		for x in range(w):
			var i: int = y * w + x
			var k: int = cls[i]
			if k == 0 or (only_own != 0 and own[i] != only_own):
				continue
			if k == 3:
				img.set_pixel(x, y, Color(0.07, 0.03, 0.08, 0.38))
				continue
			var edge: bool = false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					edge = true
				else:
					var j: int = ny * w + nx
					var kk: int = cls[j]
					if kk == 0 or kk == 3 or (only_own != 0 and own[j] != only_own):
						edge = true
			if edge and not (k == 1 and own[i] == 1 and not _topo_images().is_empty()) and not (k == 2 and not _face_images().is_empty()):
				img.set_pixel(x, y, outline)
				continue
			var col: Color
			if not rocks.is_empty():
				@warning_ignore("integer_division")
				var vi: int = int(_hash(x / 52, y / 52, seed_value + 11) * float(rocks.size())) % rocks.size()
				var im: Image = rocks[vi]
				col = im.get_pixel(x % im.get_width(), y % im.get_height())
			else:
				col = Color("#4a3a46")
			var done_px: bool = false
			if k == 1:
				var psx: int = int(floor((float(x) - c.x + 13.0) / 26.0))
				var psy: int = int(floor((float(y) - c.y + 13.0) / 26.0))
				var light_sq: bool = (((_grid0.x + psx) + (_grid0.y + psy)) % 2 + 2) % 2 == 0
				var tops: Array = _topo_images()
				if not tops.is_empty():
					var hv: float = _hash(psx, psy, seed_value + 33)
					var pick: int = int(hv * 2.0) % 2
					# paredes usam sempre o tom escuro; o teto segue a paridade do tabuleiro
					var tim: Image = tops[(0 if (light_sq and own[i] == 1) else 2) + pick]
					var lx: int = (((x - int(c.x) + 13) % 26) + 26) % 26
					var ly: int = (((y - int(c.y) + 13) % 26) + 26) % 26
					if _hash(psx, psy, seed_value + 55) > 0.5:
						lx = 25 - lx
					col = tim.get_pixel(lx, ly)
					done_px = true
			if k == 2:
				var faces: Array = _face_images()
				if not faces.is_empty():
					var blk: int = int(floor(float(x) / 52.0))
					var fim: Image = faces[int(_hash(blk, 7, seed_value + 44) * float(faces.size())) % faces.size()]
					var fxx: int = x % 52
					if _hash(blk, 9, seed_value + 66) > 0.5:
						fxx = 51 - fxx
					var fc: Color = fim.get_pixel(fxx, mini(_dep[i] - 1, fim.get_height() - 1))
					if fc.a >= 0.5:
						img.set_pixel(x, y, fc)
					continue
			if k == 2 and not done_px:
				# face frontal: mais escura, com um fio de sombra no pé
				col = col.darkened(0.34)
				if y + 1 < h and cls[(y + 1) * w + x] == 3:
					col = col.darkened(0.25)
			else:
				# aresta superior da face (onde o topo vira parede) ganha um fio de luz
				if not done_px and y + 1 < h and cls[(y + 1) * w + x] == 2:
					col = rim
			img.set_pixel(x, y, col)
	return img

# Pedra em blocos irregulares (estilo das paredes de tijolo do tabuleiro): cada
# bloco tem um tom chapado de ameixa, junta escura entre eles, brilho fino na
# borda de cima/esquerda e sombra embaixo. Os blocos vêm de uma grade com
# sementes sorteadas (a mesma para teto e paredes, para as duas peças casarem).
const STONE_G: int = 11
const STONE_TONES: Array[String] = ["#31252f", "#3a2d37", "#4a3a46", "#5a4855"]
const STONE_LIGHT := "#685563"
const STONE_JOINT := "#241a21"

func _cell_seed(gx: int, gy: int, seed_value: int) -> Vector2:
	return Vector2((float(gx) + 0.15 + _hash(gx, gy, seed_value + 1) * 0.7) * STONE_G, (float(gy) + 0.15 + _hash(gx, gy, seed_value + 2) * 0.7) * STONE_G)

func _paint_tiles(inside: PackedByteArray, w: int, h: int, seed_value: int, rocks: Array) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outline := Color("#1f161d")
	for y in range(h):
		for x in range(w):
			if inside[y * w + x] == 0:
				continue
			var edge: bool = false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or inside[ny * w + nx] == 0:
					edge = true
			if edge:
				img.set_pixel(x, y, outline)
				continue
			@warning_ignore("integer_division")
			var vi: int = int(_hash(x / 52, y / 52, seed_value + 11) * float(rocks.size())) % rocks.size()
			var im: Image = rocks[vi]
			img.set_pixel(x, y, im.get_pixel(x % im.get_width(), y % im.get_height()))
	return img

func _paint(inside: PackedByteArray, w: int, h: int, c: Vector2, seed_value: int) -> Image:
	var rocks: Array = _rock_images()
	if not rocks.is_empty():
		return _paint_tiles(inside, w, h, seed_value, rocks)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	var rx: float = w / 2.0
	var ry: float = h / 2.0
	var outline := Color("#1f161d")
	var cell_id := PackedInt32Array()
	var joint := PackedByteArray()
	cell_id.resize(w * h)
	joint.resize(w * h)
	for y in range(h):
		for x in range(w):
			@warning_ignore("integer_division")
			var gx0: int = x / STONE_G
			@warning_ignore("integer_division")
			var gy0: int = y / STONE_G
			var d1: float = 1e9
			var d2: float = 1e9
			var id1: int = 0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var sd := _cell_seed(gx0 + ox, gy0 + oy, seed_value)
					# o bloco é "achatado": mais largo que alto, como tijolos de rocha
					var dd: float = sqrt(pow((float(x) + 0.5 - sd.x) * 0.8, 2.0) + pow(float(y) + 0.5 - sd.y, 2.0) * 1.15)
					if dd < d1:
						d2 = d1
						d1 = dd
						id1 = (gx0 + ox) * 7919 + (gy0 + oy)
					elif dd < d2:
						d2 = dd
			cell_id[y * w + x] = id1
			joint[y * w + x] = 1 if (d2 - d1) < 1.25 else 0
	var tones: Array[Color] = []
	for t in STONE_TONES:
		tones.append(Color(t))
	var light := Color(STONE_LIGHT)
	var jc := Color(STONE_JOINT)
	for y in range(h):
		for x in range(w):
			if inside[y * w + x] == 0:
				continue
			var edge: bool = false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or inside[ny * w + nx] == 0:
					edge = true
			if edge:
				img.set_pixel(x, y, outline)
				continue
			if joint[y * w + x] == 1:
				img.set_pixel(x, y, jc)
				continue
			var id: int = cell_id[y * w + x]
			var ti: int = int(_hash(id & 0xffff, id >> 16, seed_value + 3) * 4.0) % 4
			# luz do canto superior esquerdo: sobe um tom perto do topo, desce embaixo
			var d2c := Vector2(x + 0.5, y + 0.5) - c
			var lt: float = clampf(0.5 - (d2c.x / rx + d2c.y / ry) * 0.5, 0.0, 1.0)
			if lt > 0.72:
				ti = mini(3, ti + 1)
			elif lt < 0.28:
				ti = maxi(0, ti - 1)
			var col: Color = tones[ti]
			# brilho na borda de cima/esquerda do bloco, sombra na de baixo
			var up_j: bool = y > 0 and (joint[(y - 1) * w + x] == 1 or cell_id[(y - 1) * w + x] != id)
			var left_j: bool = x > 0 and (joint[y * w + x - 1] == 1 or cell_id[y * w + x - 1] != id)
			var down_j: bool = y < h - 1 and (joint[(y + 1) * w + x] == 1 or cell_id[(y + 1) * w + x] != id)
			if up_j or left_j:
				col = light if ti >= 1 else tones[mini(3, ti + 1)]
			elif down_j:
				col = tones[maxi(0, ti - 1)]
			img.set_pixel(x, y, col)
	# Rachaduras finas (poucas) e pontinhos de cristal embutidos.
	var cracks: int = 3 + members.size() * 3
	for k in range(cracks):
		var p := Vector2(c.x + rng.randf_range(-rx * 0.9, rx * 0.9), c.y + rng.randf_range(-ry * 0.8, ry * 0.8))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for st in range(rng.randi_range(6, 14)):
			var ix := int(p.x)
			var iy := int(p.y)
			if ix > 0 and iy > 0 and ix < w - 1 and iy < h - 1 and inside[iy * w + ix] == 1:
				img.set_pixel(ix, iy, jc)
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			p += dir
	var glints: Array[Color] = [Color("#8f6bd1"), Color("#a9dcef"), Color("#3f9b79")]
	for k in range(4 + members.size() * 3):
		var gx: int = int(c.x + rng.randf_range(-rx * 0.9, rx * 0.9))
		var gy: int = int(c.y + rng.randf_range(-ry * 0.8, ry * 0.8))
		var gc: Color = glints[rng.randi() % glints.size()]
		for o in [Vector2i(0, 0), Vector2i(0, 1)]:
			var qx: int = gx + o.x
			var qy: int = gy + o.y
			if qx > 0 and qy > 0 and qx < w - 1 and qy < h - 1 and inside[qy * w + qx] == 1 and joint[qy * w + qx] == 0:
				img.set_pixel(qx, qy, gc if o == Vector2i(0, 0) else gc.darkened(0.35))
	return img

# ---------------------------------------------------------- cristais ----

# Cristais embutidos no teto: aglomerados e cristais soltos espalhados pelo meio da
# rocha (longe dos nodos, para não atrapalhar a leitura). Somem junto com o teto e
# ficam escondidos onde o foco abre.
func _build_roof(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 31
	var tries: int = 0
	var placed: int = 0
	var want: int = 6 + members.size() * 6
	while placed < want and tries < 600:
		tries += 1
		var m: Vector2 = members[rng.randi() % members.size()]
		var p := m + Vector2(rng.randf_range(-RX_PX, RX_PX), rng.randf_range(-RY_PX, RY_PX))
		if mask_value(p, members, has_edge) > 0.78:
			continue
		var too_close: bool = false
		for mm in members:
			if p.distance_to(mm) < 150.0:
				too_close = true
		for it in _roof_items:
			if p.distance_to(it[2]) < 85.0:
				too_close = true
		for mp in _mouth_pts:
			if p.distance_to(mp) < 110.0:
				too_close = true
		# só em cima de rocha de verdade: a casa e as vizinhas têm de ser teto DESTA gruta
		var rc := Vector2i(int(roundf(p.x / TILE)), int(roundf(p.y / TILE)))
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not _cell_ceil(rc.x + o.x, rc.y + o.y):
				too_close = true
		if too_close:
			continue
		var cluster: int = 1 + (1 if rng.randf() < 0.3 else 0)
		for k in range(cluster):
			var pk: Vector2 = p + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-10.0, 10.0)) * (1.0 if k > 0 else 0.0)
			var rf: String = "cristal_teto_%d" % (1 + rng.randi() % 6)
			var rtex := _gtex(rf)
			var pair: Array = []
			if rtex != null:
				pair = _add_tex_crystal(_roof, rtex, rf, pk, rng.randf() < 0.5, rng, 0.7)
			else:
				pair = _add_crystal(_roof, pk, float(PX) * rng.randf_range(0.5, 0.85), rng, rng.randf_range(-0.4, 0.4))
			if pair.size() == 2:
				_roof_items.append([pair[0], pair[1], pk])
		placed += 1
	# Esses cristais têm brilho próprio: tira da lista dos que ficam (paredes).
	for it in _roof_items:
		for i in range(_glows.size() - 1, -1, -1):
			if _glows[i][0] == it[1]:
				_glows.remove_at(i)
		_crystal_sprites.erase(it[0])

func _roof_tick() -> void:
	if _roof_items.is_empty():
		return
	var hole_r: float = SPOT_PX * lit + 14.0
	for it in _roof_items:
		var sp: Sprite2D = it[0]
		var gl: Sprite2D = it[1]
		if not is_instance_valid(sp):
			continue
		var d: float = _pawn_local.distance_to(it[2])
		var vis: float = clampf((d - hole_r) / 40.0, 0.0, 1.0) if lit > 0.02 else 1.0
		sp.modulate.a = vis
		var pulse: float = 0.75 + 0.25 * sin(_t * 1.6 + it[2].x * 0.01)
		gl.modulate.a = 0.2 * pulse * vis

func _build_crystals(seed_value: int) -> void:
	if _glow_tex == null:
		var n: int = 64
		var gi := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in range(n):
			for x in range(n):
				var dd: float = Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				var a: float = clampf(1.0 - dd, 0.0, 1.0)
				gi.set_pixel(x, y, Color(1, 1, 1, a * a))
		_glow_tex = ImageTexture.create_from_image(gi)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	# Cristais nas laterais: só onde a borda da rocha é reta e de verdade (medida na própria
	# máscara do teto), com a base ENTERRADA na rocha. Nada solto, nada fora do tabuleiro.
	var y0: float = _wall_range.x + (_wall_range.y - _wall_range.x) * 0.1
	var y1: float = _wall_range.x + (_wall_range.y - _wall_range.x) * 0.9
	var yy: float = y0
	var side: float = -1.0
	while yy < y1:
		var yi: int = clampi(int(yy), 10, _ch - 11)
		var n: int = 1 + rng.randi() % 6
		var file: String = "cristal_parede_%d" % n + ("_esq" if side < 0.0 else "")
		var tex := _gtex(file)
		var placed_c: bool = false
		if tex != null:
			@warning_ignore("integer_division")
			var half_rows: int = int(tex.get_height() / 2) + 2
			var ex0: int = _row_edge(yi, side)
			var flat: bool = ex0 > -9000
			if flat:
				for dy in range(-half_rows, half_rows + 1):
					if _row_edge(clampi(yi + dy, 0, _ch - 1), side) != ex0:
						flat = false
						break
			if flat:
				var wv: float = float(tex.get_width())
				var centre_x: float = (float(ex0) + 6.0 - wv / 2.0) if side < 0.0 else (float(ex0) + 1.0 - 6.0 + wv / 2.0)
				var pos := Vector2((centre_x - _tex_origin.x) * float(PX), (yy - _tex_origin.y) * float(PX))
				var okc: bool = true
				var ccell := Vector2i(int(floor(pos.x / TILE + 0.5)), int(floor(pos.y / TILE + 0.5)))
				if _nb_cells.has(ccell) or _pawn_cells.has(ccell) or _busy_cells.has(ccell) or not _cell_on_board(ccell.x, ccell.y):
					okc = false
				for mp in _mouth_pts:
					if pos.distance_to(mp) < 110.0:
						okc = false
				for wp in _others_w:
					if pos.distance_to(wp - position) < 95.0:
						okc = false
				if okc:
					_add_tex_crystal(_outer, tex, file, pos, false, rng, 0.9)
					placed_c = true
		side = -side
		yy += rng.randf_range(16.0, 28.0) if placed_c else 5.0
	# Dentro da gruta: só em casas de chão LIVRES (sem trilha, sem caminho da peça, sem nodo,
	# sem parede), no centro da casa. Nada de cristal em cima de trilho, parede ou entrada.
	var cand: Array = []
	@warning_ignore("integer_division")
	var rxc: int = int(_cw / 52) + 1
	@warning_ignore("integer_division")
	var ryc: int = int(_ch / 52) + 1
	for sy in range(-ryc, ryc + 1):
		for sx in range(-rxc, rxc + 1):
			var cc := Vector2i(sx, sy)
			if not _cell_ceil(sx, sy) or _trail_cells.has(cc) or _pawn_cells.has(cc) or _busy_cells.has(cc):
				continue
			var cp := Vector2(float(sx), float(sy)) * TILE
			var bad: bool = false
			for mm in members:
				if cp.distance_to(mm) < 110.0:
					bad = true
			for wp in _others_w:
				if cp.distance_to(wp - position) < 110.0:
					bad = true
			for mp in _mouth_pts:
				if cp.distance_to(mp) < 120.0:
					bad = true
			# precisa estar bem dentro: as 4 vizinhas também são teto
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not _cell_ceil(sx + o.x, sy + o.y):
					bad = true
			if bad or _wall_in_cell(sx, sy):
				continue
			cand.append(cc)
	var chosen: Array = []
	var want_in: int = 2 + members.size() * 2
	while not cand.is_empty() and chosen.size() < want_in:
		var ci: int = rng.randi() % cand.size()
		var pick: Vector2i = cand[ci]
		cand.remove_at(ci)
		var okp: bool = true
		for ch in chosen:
			if absi(ch.x - pick.x) + absi(ch.y - pick.y) < 2:
				okp = false
		if not okp:
			continue
		chosen.append(pick)
		_add_crystal(_inner, Vector2(float(pick.x), float(pick.y)) * TILE + Vector2(0.0, 6.0), float(PX) * rng.randf_range(0.55, 0.75), rng, 0.0)
	# Cristaizinhos que BRILHAM, espalhados pelo chão da gruta (aparecem quando o foco abre).
	var small: Array = []
	for sy in range(-ryc, ryc + 1):
		for sx in range(-rxc, rxc + 1):
			var sc2 := Vector2i(sx, sy)
			if not _cell_ceil(sx, sy) or _trail_cells.has(sc2) or _pawn_cells.has(sc2) or _busy_cells.has(sc2) or chosen.has(sc2):
				continue
			var sp2 := Vector2(float(sx), float(sy)) * TILE
			var bad2: bool = false
			for mm in members:
				if sp2.distance_to(mm) < 75.0:
					bad2 = true
			for wp in _others_w:
				if sp2.distance_to(wp - position) < 75.0:
					bad2 = true
			for mp in _mouth_pts:
				if sp2.distance_to(mp) < 100.0:
					bad2 = true
			if bad2 or _wall_in_cell(sx, sy):
				continue
			small.append(sc2)
	var want_small: int = mini(small.size(), 5 + members.size() * 4)
	for k in range(want_small):
		var si: int = rng.randi() % small.size()
		var cell2: Vector2i = small[si]
		small.remove_at(si)
		var kind: int = rng.randi() % 3
		for j in range(1 + rng.randi() % 2):
			var off := Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-14.0, 20.0))
			off = Vector2(roundf(off.x / float(PX)) * float(PX), roundf(off.y / float(PX)) * float(PX))
			_add_mini_crystal(Vector2(float(cell2.x), float(cell2.y)) * TILE + off, kind, rng)

const MINI_COLS: Array = [
	["#b48cf0", "#dcc6fc", "#7a55c8"],   # violeta: corpo, luz, sombra
	["#8fd3f5", "#dff4ff", "#5a9bd0"],   # gelo
	["#5fd6a0", "#c0f5da", "#2f9a70"],   # esmeralda
]
static var _mini_tex: Dictionary = {}

# Grupinho de 2-3 lascas de cristal em pixel art (13x12), no estilo dos cristais do mapa.
static func _mini_texture(kind: int, variant: int) -> ImageTexture:
	var key: int = kind * 10 + variant
	if _mini_tex.has(key):
		return _mini_tex[key]
	var img := Image.create(13, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color(MINI_COLS[kind][0])
	var light := Color(MINI_COLS[kind][1])
	var dark := Color(MINI_COLS[kind][2])
	var _line := Color("#1f161d")
	# lascas: [x do centro, altura, meia-largura]
	var shards: Array = [[[6, 10, 2], [2, 6, 1], [10, 7, 1]], [[4, 9, 2], [9, 6, 1]], [[7, 10, 2], [3, 7, 1], [11, 5, 1]]][variant % 3]
	for sh in shards:
		var cx: int = sh[0]
		var hh: int = sh[1]
		var hw: int = sh[2]
		for r in range(hh):
			var y: int = 11 - r
			var wv: int = hw if r < hh - 2 else (maxi(hw - 1, 0) if r < hh - 1 else 0)
			for x in range(cx - wv, cx + wv + 1):
				if x >= 0 and x < 13:
					img.set_pixel(x, y, light if x < cx else (body if x == cx else dark))
		if hh >= 6:
			img.set_pixel(cx, 11 - hh + 3, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_mini_tex[key] = tex
	return tex

func _add_mini_crystal(pos: Vector2, kind: int, rng: RandomNumberGenerator) -> void:
	var g := Sprite2D.new()
	g.texture = _glow_tex
	g.position = pos + Vector2(0, -6.0)
	g.scale = Vector2.ONE * 2.1
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = gm
	var gc := Color(MINI_COLS[kind][0])
	g.modulate = Color(gc.r, gc.g, gc.b, 0.6)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_inner.add_child(g)
	_glows.append([g, 0.6, rng.randf() * TAU])
	# miolo claro, pequeno e forte, para o cristal parecer aceso por dentro
	var g2 := Sprite2D.new()
	g2.texture = _glow_tex
	g2.position = pos + Vector2(0, -8.0)
	g2.scale = Vector2.ONE * 0.8
	g2.material = gm
	var lc := Color(MINI_COLS[kind][1])
	g2.modulate = Color(lc.r, lc.g, lc.b, 0.55)
	g2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_inner.add_child(g2)
	_glows.append([g2, 0.55, rng.randf() * TAU])
	var sp := Sprite2D.new()
	sp.texture = _mini_texture(kind, rng.randi() % 3)
	sp.position = pos
	sp.offset = Vector2(0, -5)
	sp.scale = Vector2(PX, PX)
	sp.flip_h = rng.randf() < 0.5
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_inner.add_child(sp)
	_crystal_sprites.append(sp)

# x (nativo) da borda do teto numa linha: primeiro pixel de rocha à esquerda ou último à direita.
func _row_edge(y: int, side: float) -> int:
	if side < 0.0:
		for x in range(_cw):
			if _ceil_store[y * _cw + x] == 1:
				return x
	else:
		for x in range(_cw - 1, -1, -1):
			if _ceil_store[y * _cw + x] == 1:
				return x
	return -9999

func _wall_in_cell(sx: int, sy: int) -> bool:
	if _wall_img == null:
		return false
	for ly in range(-4, 30, 3):
		for lx in range(-4, 30, 3):
			var px: int = _cx0 + sx * 26 + lx
			var py: int = _cy0 + sy * 26 + ly
			if px >= 0 and py >= 0 and px < _cw and py < _ch and _wall_img.get_pixel(px, py).a > 0.05:
				return true
	return false

var _wall_img: Image = null

func _add_tex_crystal(parent: Node2D, tex: Texture2D, file: String, pos: Vector2, flip: bool, rng: RandomNumberGenerator, glow_k: float) -> Array:
	var g := Sprite2D.new()
	g.texture = _glow_tex
	g.position = pos
	g.scale = Vector2.ONE * float(maxi(tex.get_width(), tex.get_height())) * float(PX) / 64.0 * 1.6
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = gm
	var gc: Color = _glow_tint(file)
	g.modulate = Color(gc.r, gc.g, gc.b, 0.16 * glow_k)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(g)
	_glows.append([g, 0.16 * glow_k, rng.randf() * TAU])
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = pos
	sp.scale = Vector2(PX, PX)
	sp.flip_h = flip
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sp)
	return [sp, g]

# Peças de borda (arte): quinas nas pontas das paredes, ressaltos na borda externa,
# estalactites e lascas soltas.
func _add_piece(file: String, pos: Vector2, flip_h: bool, flip_v: bool) -> void:
	var tex := _gtex(file)
	if tex == null:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = pos
	sp.scale = Vector2(PX, PX)
	sp.flip_h = flip_h
	sp.flip_v = flip_v
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_outer.add_child(sp)

func _wp(x: float, y: float) -> Vector2:
	return Vector2((x - _tex_origin.x) * float(PX), (y - _tex_origin.y) * float(PX))

func _build_fringe(rng: RandomNumberGenerator) -> void:
	var yt: int = int(_wall_range.x)
	var yb: int = int(_wall_range.y)
	for side in [-1.0, 1.0]:
		var fh: bool = side > 0.0
		var xt: float = _wall_ol[yt + 6] if side < 0.0 else _wall_or[yt + 6]
		var xb: float = _wall_ol[yb - 6] if side < 0.0 else _wall_or[yb - 6]
		_add_piece("borda_2", _wp(xt + side * 2.0, float(yt) + 4.0), fh, false)
		_add_piece("borda_2", _wp(xb + side * 2.0, float(yb) - 4.0), fh, true)
		_add_piece("borda_4", _wp(xb - side * 4.0, float(yb) + 8.0), false, false)
		for k in range(2):
			var yr: int = int(lerpf(float(yt) + 20.0, float(yb) - 20.0, rng.randf()))
			var xe: float = _wall_ol[yr] if side < 0.0 else _wall_or[yr]
			_add_piece("borda_1", _wp(xe + side * 4.0, float(yr)), fh, rng.randf() < 0.5)
		_add_piece("borda_3", _wp(xb + side * 14.0, float(yb) + 6.0), rng.randf() < 0.5, false)

func _add_crystal(parent: Node2D, pos: Vector2, sc: float, rng: RandomNumberGenerator, rot: float) -> Array:
	var idx: int = rng.randi() % CRYSTALS.size()
	var tex := load(CRYSTAL_DIR + CRYSTALS[idx] + ".png") as Texture2D
	if tex == null:
		return []
	var g := Sprite2D.new()
	g.texture = _glow_tex
	g.position = pos
	g.scale = Vector2.ONE * sc * 1.8
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = gm
	var gc: Color = GLOW_COLORS[idx]
	g.modulate = Color(gc.r, gc.g, gc.b, 0.2)
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(g)
	_glows.append([g, 0.2, rng.randf() * TAU])
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = pos
	sp.scale = Vector2.ONE * sc
	sp.rotation = rot
	sp.flip_h = rng.randf() < 0.5
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sp)
	_crystal_sprites.append(sp)
	return [sp, g]

# Glifo "?" separado da rocha (balança e reage ao mouse). 5x7, cada ponto = 2x2.
func _build_glyph() -> ImageTexture:
	var glyph: Array[String] = [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."]
	var img := Image.create(10, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for gy in range(glyph.size()):
		for gx in range(5):
			if glyph[gy][gx] == "#":
				for ox in range(2):
					for oy in range(2):
						img.set_pixel(gx * 2 + ox, gy * 2 + oy, Color.WHITE)
	return ImageTexture.create_from_image(img)
