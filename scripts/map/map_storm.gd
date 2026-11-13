class_name MapStorm
extends Node2D

# Tempestade de areia do Deserto das Torres: uma RAJADA de areia e vento que entra por um
# lado da tela, atravessa a fileira inteira e sai pelo outro. Só os DUELOS da fileira ficam
# dentro dela (a areia engrossa neles e eles ganham o selo); em volta dos outros nodos a
# areia se abre. O nodo continua à vista. O duelo travado ali recebe o efeito da tempestade
# (RunManager.current_node_storm).

const PX: int = 3
const TILE: float = 78.0
const BAND_W: float = 3200.0        # largura da faixa (passa das bordas da tela)
const BAND_H: float = 4.0 * TILE    # altura total do retângulo
const HALF_H: float = 1.25 * TILE   # meia-altura do corpo da rajada
const MAX_PTS: int = 6

const SHADER_CODE := """
shader_type canvas_item;
uniform vec2 box = vec2(100.0);
uniform vec2 duels[6];
uniform int duel_n = 0;
uniform vec2 clears[6];
uniform int clear_n = 0;
uniform float half_h = 80.0;
uniform float px = 3.0;
uniform float dir = 1.0;        // +1: da esquerda para a direita; -1: o contrário
uniform float focus = 0.0;      // 0..1: peça dentro (a areia engrossa e corre mais)
uniform float tt = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 17.0) * 0.3 + vnoise(p * 4.1 + 51.0) * 0.15;
}

void fragment() {
	vec2 p = (UV - 0.5) * box;
	p = floor(p / px) * px;                        // pixels do tamanho dos do mapa
	float fx = p.x * dir - tt * 520.0;             // tudo corre no sentido do vento
	// a faixa ondula e tem a borda rasgada
	float wav = (vnoise(vec2(fx * 0.0035, 3.0)) - 0.5) * half_h * 0.9;
	float y = (p.y - wav) / half_h;
	float edge_n = fbm(vec2(fx * 0.006, p.y * 0.03));
	float band = 1.0 - smoothstep(0.45, 1.0, abs(y) + (edge_n - 0.5) * 0.7);
	// rajadas: ondas de areia que entram por um lado e saem pelo outro
	float gust = 0.6 + 0.4 * smoothstep(0.30, 0.75, vnoise(vec2(fx * 0.0016, 9.0)));
	// fios compridos de areia
	float streak = fbm(vec2(fx * 0.0045, p.y * 0.075));
	float dens = band * gust * (0.50 + 0.50 * smoothstep(0.30, 0.75, streak));
	// nos duelos a areia engrossa (nuvem), e abre só um pouco em cima do ícone
	float dd = 10000.0;
	for (int i = 0; i < duel_n; i++) {
		dd = min(dd, length((p - duels[i]) * vec2(0.75, 1.0)));
	}
	float puff = 1.0 - smoothstep(50.0, 120.0, dd + (edge_n - 0.5) * 50.0);
	dens = max(dens, puff * 0.8);
	dens *= mix(0.32, 1.0, smoothstep(24.0, 52.0, dd));
	// em volta dos nodos que NÃO são duelo a areia se abre
	float cd = 10000.0;
	for (int i = 0; i < clear_n; i++) {
		cd = min(cd, length(p - clears[i]));
	}
	dens *= smoothstep(52.0, 104.0, cd + (edge_n - 0.5) * 30.0);
	// some nas pontas (fora da tela)
	dens *= 1.0 - smoothstep(0.42, 0.5, abs(UV.x - 0.5));
	dens = clamp(dens * (1.0 + 0.3 * focus), 0.0, 1.0);
	float a = floor(dens * 2.0 + 0.5) / 2.0;      // degraus (pixel art, sem degradê liso)
	vec3 dark = vec3(0.60, 0.38, 0.17);
	vec3 mid = vec3(0.80, 0.57, 0.28);
	vec3 light = vec3(0.95, 0.79, 0.48);
	float tone = floor(streak * 3.0 + 0.5) / 3.0;
	vec3 col = tone < 0.4 ? dark : (tone < 0.72 ? mid : light);
	COLOR = vec4(col, a * 0.34);
}
"""

var members: Array[Vector2] = []      # duelos dentro da rajada (local)
var dir: float = 1.0
var _rect: ColorRect
var _mat: ShaderMaterial
var _badges: Array[Sprite2D] = []
var _grains: Array = []       # [pos, velocidade, fase, comprimento]
var _clears: Array[Vector2] = []
var _t: float = 0.0
var _tt: float = 0.0
var _focus: float = 0.0
var _focus_target: float = 0.0

# `duel_pts`: duelos da fileira (mundo); `clear_pts`: os outros nodos da fileira (a areia abre
# em volta); `center_x`: centro do tabuleiro; `direction`: +1 ou -1.
func setup(duel_pts: Array, clear_pts: Array, center_x: float, direction: float, seed_value: int) -> void:
	dir = direction
	var y: float = duel_pts[0].y
	position = Vector2(center_x, y)
	z_index = 15
	for wp in duel_pts:
		members.append(wp - position)
	for wp in clear_pts:
		_clears.append(wp - position)
	var size := Vector2(BAND_W, BAND_H)
	_rect = ColorRect.new()
	_rect.size = size
	_rect.position = -size / 2.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat.shader = sh
	_mat.set_shader_parameter("box", size)
	var da := PackedVector2Array()
	var ca := PackedVector2Array()
	da.resize(MAX_PTS)
	ca.resize(MAX_PTS)
	for i in range(mini(members.size(), MAX_PTS)):
		da[i] = members[i]
	for i in range(mini(_clears.size(), MAX_PTS)):
		ca[i] = _clears[i]
	_mat.set_shader_parameter("duels", da)
	_mat.set_shader_parameter("duel_n", mini(members.size(), MAX_PTS))
	_mat.set_shader_parameter("clears", ca)
	_mat.set_shader_parameter("clear_n", mini(_clears.size(), MAX_PTS))
	_mat.set_shader_parameter("half_h", HALF_H)
	_mat.set_shader_parameter("px", float(PX))
	_mat.set_shader_parameter("dir", dir)
	_rect.material = _mat
	add_child(_rect)
	# Selo de "tempestade" no canto de cada duelo coberto.
	for m in members:
		var b := Sprite2D.new()
		b.texture = _badge_texture()
		b.scale = Vector2(PX, PX)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.position = m + Vector2(30.0, -30.0)
		b.z_index = 1
		add_child(b)
		_badges.append(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Centenas de risquinhos de pixel (areia voando), em três tons: é isso que faz a rajada.
	for i in range(1150):
		var tone: int = rng.randi() % 20
		_grains.append([
			Vector2(rng.randf_range(-BAND_W / 2.0, BAND_W / 2.0), rng.randf_range(-HALF_H * 1.2, HALF_H * 1.2)),
			rng.randf_range(520.0, 1050.0), rng.randf() * TAU, rng.randi_range(2, 9),
			0 if tone < 6 else (1 if tone < 13 else 2),
		])

func set_focus(on: bool) -> void:
	_focus_target = 1.0 if on else 0.0

func _process(delta: float) -> void:
	_t += delta
	_focus = lerpf(_focus, _focus_target, minf(1.0, delta * 4.0))
	var sp: float = 1.0 + 0.5 * _focus
	_tt += delta * sp
	if _mat != null:
		_mat.set_shader_parameter("focus", _focus)
		_mat.set_shader_parameter("tt", _tt)
	for i in range(_badges.size()):
		_badges[i].position = members[i] + Vector2(30.0, -30.0 + roundf(sin(_t * 2.4 + float(i))) * float(PX))
	var half: float = BAND_W / 2.0
	var lim: float = HALF_H * 1.2
	for g in _grains:
		var p: Vector2 = g[0]
		var v: float = float(g[1]) * delta * sp
		p.x += v * dir
		p.y += v * 0.3            # o vento desce um pouco: os riscos voam em diagonal
		if p.x > half:
			p.x -= BAND_W
		elif p.x < -half:
			p.x += BAND_W
		if p.y > lim:
			p.y -= lim * 2.0
		g[0] = p
	queue_redraw()

func _near_clear(p: Vector2, r: float) -> bool:
	for c in _clears:
		if p.distance_to(c) < r:
			return true
	return false

const GRAIN_COLS: Array = [Color(1.0, 0.94, 0.72), Color(0.86, 0.66, 0.36), Color(0.40, 0.26, 0.14)]

func _draw() -> void:
	var u: float = float(PX)
	for g in _grains:
		var p: Vector2 = g[0]
		if _near_clear(p, 60.0):
			continue
		var on_icon: bool = false
		for m in members:
			if p.distance_to(m) < 36.0:
				on_icon = true
		if on_icon:
			continue   # o ícone do duelo fica limpo
		var fade: float = 1.0 - clampf((absf(p.y) - HALF_H * 0.75) / (HALF_H * 0.45), 0.0, 1.0)
		if fade <= 0.05:
			continue
		var col: Color = GRAIN_COLS[int(g[4])]
		col.a = 0.9 * fade
		var q := Vector2(floor(p.x / u) * u, floor(p.y / u) * u)
		# risco em escadinha: a cada 3 pixels para o lado, 1 para baixo (cauda para trás e para cima)
		var n: int = int(g[3])
		var k: int = 0
		while k < n:
			var seg: int = mini(3, n - k)
			var ox: float = -float(k + seg) * u if dir > 0.0 else float(k) * u
			@warning_ignore("integer_division")
			draw_rect(Rect2(q + Vector2(ox, -float(k / 3) * u), Vector2(float(seg) * u, u)), col)
			k += 3

static var _badge_tex: ImageTexture = null

# Selo 11x11: redemoinho de areia num disco escuro.
static func _badge_texture() -> ImageTexture:
	if _badge_tex != null:
		return _badge_tex
	var rows: Array[String] = [
		"...#####...",
		"..#######..",
		".##ooooo##.",
		"##o#####o##",
		"##o#ooo##o#",
		"##o#o#o##o#",
		"##o#o##oo##",
		"##o#ooooo##",
		".##o#####..",
		"..##ooo##..",
		"...#####...",
	]
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(11):
		for x in range(11):
			var ch: String = rows[y][x]
			if ch == "#":
				img.set_pixel(x, y, Color("#4a2a12"))
			elif ch == "o":
				img.set_pixel(x, y, Color("#f6d98a"))
	_badge_tex = ImageTexture.create_from_image(img)
	return _badge_tex
