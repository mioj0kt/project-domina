class_name SuddenDeathView
extends CanvasLayer

# Visual da Morte Súbita: (1) aviso grande de início de fase e (2) o contador
# fixo no canto da tela (número grande, barrinhas de turnos, pulsa nos últimos).
# Quem manda nele é o SuddenDeathManager (set_state) e o main (play_intro).

const C_RED := Color(1.0, 0.33, 0.35)
const C_RED_DARK := Color(0.09, 0.015, 0.03)
const C_CREAM := Color(0.94, 0.9, 0.81)
const C_BLUE := Color(0.5, 0.78, 1.0)
const WARN_TURNS: int = 3

const EDGE_SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;   // 0..1
uniform int mode = 0;            // variações do efeito (ver abaixo)
uniform float progress = 0.0;    // 0..1: quanto da Morte Súbita já passou
uniform vec4 tint : source_color = vec4(1.0, 0.12, 0.16, 1.0);
uniform vec2 pixels = vec2(480.0, 270.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; }
	return v;
}

void fragment() {
	vec2 uv = floor(UV * pixels) / pixels;
	float d = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y) * 1.78);
	vec3 col = tint.rgb;
	float a = 0.0;

	if (mode == 0) {
		// ONDAS: linhas que sobem das bordas.
		float wob = sin(uv.y * 14.0 + TIME * 1.6) * 0.012 + sin(uv.x * 11.0 - TIME * 1.2) * 0.012;
		float dd = d + wob;
		float ripple = fract(dd * 7.0 - TIME * 0.28);
		float line = smoothstep(0.0, 0.08, ripple) * (1.0 - smoothstep(0.08, 0.26, ripple));
		float vig = 1.0 - smoothstep(0.0, 0.20, dd);
		a = vig * 0.40 + vig * line * 0.30;
		a = floor(a * 6.0) / 6.0;
	} else if (mode == 1) {
		// CHAMAS E BRASAS nas quatro bordas.
		float vmax = -1.0;
		for (int sd = 0; sd < 4; sd++) {
			float s; float depth;
			if (sd == 0) { s = uv.x; depth = (1.0 - uv.y) * 1.78; }
			else if (sd == 1) { s = uv.x + 3.0; depth = uv.y * 1.78; }
			else if (sd == 2) { s = uv.y * 1.78 + 7.0; depth = uv.x; }
			else { s = uv.y * 1.78 + 11.0; depth = 1.0 - uv.x; }
			float f = fbm(vec2(s * 14.0, depth * 7.0 - TIME * 2.2));
			vmax = max(vmax, f - depth * 3.2 - 0.12);
		}
		if (vmax > 0.0) {
			a = 0.96;
			if (vmax < 0.07) col = vec3(0.45, 0.04, 0.05);
			else if (vmax < 0.15) col = vec3(0.95, 0.18, 0.05);
			else if (vmax < 0.24) col = vec3(1.0, 0.55, 0.08);
			else col = vec3(1.0, 0.9, 0.4);
		}
		// brasas subindo
		float colid = floor(uv.x * 64.0);
		float xr = (colid + hash(vec2(colid, 1.0))) / 64.0;
		float spd = 0.08 + 0.12 * hash(vec2(colid, 3.0));
		float yr = 1.0 - fract(hash(vec2(colid, 7.0)) + TIME * spd);
		if (abs(uv.x - xr) < 0.0022 && abs(uv.y - yr) < 0.005 && (uv.x < 0.24 || uv.x > 0.76)) {
			a = 1.0; col = vec3(1.0, 0.7, 0.2);
		}
	} else if (mode == 2) {
		// RACHADURAS que crescem a cada turno.
		vec2 p = uv * vec2(9.0, 5.0);
		vec2 ip = floor(p); vec2 fp = fract(p);
		float d1 = 8.0; float d2 = 8.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 o = vec2(float(x), float(y));
				vec2 r = o + vec2(hash(ip + o), hash(ip + o + 17.0)) - fp;
				float dd = dot(r, r);
				if (dd < d1) { d2 = d1; d1 = dd; } else if (dd < d2) { d2 = dd; }
			}
		}
		float edge = sqrt(d2) - sqrt(d1);
		float reach = 0.16 + 0.26 * progress;
		float mask = 1.0 - smoothstep(0.0, reach, d);
		float width = 0.035 + 0.03 * progress;
		a = 0.22 * mask;
		col = vec3(0.35, 0.02, 0.05);
		if (edge < width && mask > 0.05) {
			a = 1.0; col = vec3(1.0, 0.25, 0.1);
			if (edge < width * 0.4) col = vec3(1.0, 0.8, 0.35);
		}
	} else if (mode == 3) {
		// CERCO: a escuridão vermelha avança para o centro conforme os turnos passam.
		float r = mix(0.10, 0.34, progress);
		float vig = 1.0 - smoothstep(0.0, r, d);
		a = floor(vig * 5.0) / 5.0 * 0.85;
		col = vec3(0.45, 0.02, 0.06);
		if (abs(d - r * 0.96) < 0.0035) { a = 0.9; col = vec3(1.0, 0.25, 0.25); }
	} else if (mode == 4) {
		// NÉVOA vermelha lenta.
		float n = fbm(uv * vec2(4.0, 2.5) + vec2(TIME * 0.05, -TIME * 0.03));
		float mask = 1.0 - smoothstep(0.0, 0.36, d);
		a = clamp(mask * (n * 1.5), 0.0, 0.72);
		a = floor(a * 7.0) / 7.0;
		col = vec3(0.85, 0.1, 0.16);
	} else if (mode == 5) {
		// RAIOS nos cantos.
		float idc = floor(uv.x + 0.5) + 2.0 * floor(uv.y + 0.5);
		vec2 q = vec2(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)) * vec2(1.0, 0.5625);
		float r = length(q);
		float ang = atan(q.y, q.x);
		float t = floor(TIME * 7.0);
		float on = step(0.4, hash(vec2(t, idc)));
		float a0 = mix(0.25, 1.3, hash(vec2(t, idc + 3.0)));
		float jag = (noise(vec2(r * 38.0, t + idc * 5.0)) - 0.5) * 0.7;
		float dist = abs(ang - (a0 + jag)) * r;
		a = 0.18 * (1.0 - smoothstep(0.0, 0.2, r));
		col = vec3(0.4, 0.02, 0.06);
		if (on > 0.5 && r < 0.3) {
			if (dist < 0.0035) { a = 1.0; col = vec3(1.0, 0.85, 0.9); }
			else if (dist < 0.011) { a = 0.55; col = vec3(1.0, 0.2, 0.25); }
		}
	} else if (mode == 6) {
		// GLITCH: barras de ruído nas laterais.
		float row = floor(uv.y * 90.0);
		float tt = floor(TIME * 10.0);
		float n = hash(vec2(row, tt));
		float L = 0.04 + 0.2 * hash(vec2(row, tt + 9.0));
		float dx = min(uv.x, 1.0 - uv.x);
		float vig = 1.0 - smoothstep(0.0, 0.14, d);
		a = vig * 0.22;
		col = vec3(0.6, 0.04, 0.08);
		if (n > 0.9 && dx < L) {
			a = 0.95;
			col = hash(vec2(row, tt + 4.0)) > 0.5 ? vec3(1.0, 0.15, 0.2) : vec3(0.25, 0.95, 1.0);
		}
		if (mod(floor(uv.y * pixels.y), 2.0) < 1.0) a *= 0.8;
	} else if (mode == 10) {
		// ZIGUE-ZAGUE: ondas em "V" subindo das bordas.
		float along = (min(uv.x, 1.0 - uv.x) < min(uv.y, 1.0 - uv.y) * 1.78) ? uv.y : uv.x;
		float tri = abs(fract(along * 14.0) - 0.5) * 0.05;
		float dd = d + tri;
		float ripple = fract(dd * 7.0 - TIME * 0.28);
		float line = smoothstep(0.0, 0.08, ripple) * (1.0 - smoothstep(0.08, 0.26, ripple));
		float vig = 1.0 - smoothstep(0.0, 0.20, dd);
		a = floor((vig * 0.40 + vig * line * 0.30) * 6.0) / 6.0;
	} else if (mode == 11) {
		// PILARES: colunas que sobem das quatro bordas, alturas variando devagar.
		float hmax = 0.0; float best = -1.0;
		for (int sd = 0; sd < 4; sd++) {
			float s; float depth;
			if (sd == 0) { s = uv.x; depth = (1.0 - uv.y) * 1.78; }
			else if (sd == 1) { s = uv.x; depth = uv.y * 1.78; }
			else if (sd == 2) { s = uv.y * 1.78; depth = uv.x; }
			else { s = uv.y * 1.78; depth = 1.0 - uv.x; }
			float colid = floor(s * 34.0);
			float h = 0.03 + 0.11 * noise(vec2(colid * 0.8 + float(sd) * 9.0, TIME * 0.7));
			float gap = step(0.18, fract(s * 34.0));
			if (depth < h && gap > 0.5) { best = max(best, 1.0 - depth / h); }
		}
		if (best >= 0.0) { a = 0.55 + 0.4 * floor(best * 3.0) / 3.0; col = mix(vec3(0.7, 0.05, 0.1), vec3(1.0, 0.35, 0.3), best); }
	} else if (mode == 12) {
		// PARTÍCULAS subindo pelas laterais.
		float vig = 1.0 - smoothstep(0.0, 0.22, d);
		a = vig * 0.14;
		col = vec3(0.5, 0.03, 0.07);
		for (int layer = 0; layer < 3; layer++) {
			float fl = float(layer);
			float colid = floor(uv.x * (36.0 + fl * 14.0));
			float sp = (0.35 + 0.8 * hash(vec2(colid, fl))) * (1.0 + fl * 0.5);
			vec2 p = vec2(uv.x * (36.0 + fl * 14.0), uv.y * (20.0 + fl * 8.0) + TIME * sp);
			vec2 cell = floor(p); vec2 f = fract(p);
			if (hash(cell + fl * 7.0) > 0.84 && f.x > 0.3 && f.x < 0.7 && f.y > 0.3 && f.y < 0.7 && vig > 0.15) {
				a = 0.95; col = mix(vec3(1.0, 0.3, 0.3), vec3(1.0, 0.8, 0.7), fl / 2.0);
			}
		}
	} else if (mode == 13) {
		// ARCOS: ondas circulares saindo dos quatro cantos.
		vec2 q = vec2(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)) * vec2(1.0, 0.5625);
		float r = length(q);
		float ripple = fract(r * 9.0 - TIME * 0.3);
		float line = smoothstep(0.0, 0.1, ripple) * (1.0 - smoothstep(0.1, 0.34, ripple));
		float fade = 1.0 - smoothstep(0.0, 0.38, r);
		a = floor((fade * 0.25 + fade * line * 0.55) * 6.0) / 6.0;
	} else if (mode == 14) {
		// LISTRAS diagonais correndo pelas bordas.
		float st = fract((uv.x + uv.y * 0.5625) * 22.0 - TIME * 0.18);
		float vig = 1.0 - smoothstep(0.0, 0.17, d);
		a = vig * (st < 0.5 ? 0.55 : 0.12);
		a = floor(a * 6.0) / 6.0;
	} else if (mode == 15) {
		// SETAS ">" apontando para o centro (cerco direcional).
		bool horiz = min(uv.x, 1.0 - uv.x) < min(uv.y, 1.0 - uv.y) * 1.78;
		float depth = horiz ? min(uv.x, 1.0 - uv.x) : min(uv.y, 1.0 - uv.y) * 1.78;
		float along = horiz ? uv.y * 1.78 : uv.x;
		float v = depth * 7.0 + abs(fract(along * 7.0) - 0.5) * 1.1 - TIME * 0.5;
		float line = step(fract(v), 0.22);
		float vig = 1.0 - smoothstep(0.0, 0.2, d);
		a = floor(vig * (0.12 + 0.6 * line) * 6.0) / 6.0;
	} else if (mode == 16) {
		// PONTILHADO: bolinhas que diminuem de tamanho da borda para dentro.
		vec2 cell = fract(uv * vec2(64.0, 36.0) + vec2(0.0, TIME * 0.15)) - 0.5;
		float rad = 0.62 * (1.0 - smoothstep(0.0, 0.24, d));
		a = length(cell) < rad ? 0.9 : 0.0;
		col = vec3(0.95, 0.15, 0.2);
	} else if (mode == 17) {
		// FEIXES de luz subindo do rodapé e descendo do topo.
		float bot = (1.0 - uv.y);
		float top = uv.y;
		float colid = floor(uv.x * 22.0);
		float hb = 0.08 + 0.22 * noise(vec2(colid * 0.7, TIME * 0.4));
		float ht = 0.05 + 0.16 * noise(vec2(colid * 0.7 + 30.0, TIME * 0.4));
		float gap = step(0.15, fract(uv.x * 22.0));
		if (bot < hb && gap > 0.5) a = floor((1.0 - bot / hb) * 4.0) / 4.0 * 0.75;
		if (top < ht && gap > 0.5) a = max(a, floor((1.0 - top / ht) * 4.0) / 4.0 * 0.6);
		float vig = 1.0 - smoothstep(0.0, 0.14, min(uv.x, 1.0 - uv.x));
		a = max(a, vig * 0.3);
		col = vec3(0.95, 0.15, 0.2);
	} else if (mode == 7) {
		// GOTEJAR: sangue escorrendo do topo.
		float nlen = noise(vec2(uv.x * 24.0, 1.0));
		float len = 0.03 + 0.26 * nlen * nlen * nlen * 2.4 + 0.015 * sin(TIME * 0.9 + uv.x * 40.0);
		float dtop = uv.y;
		if (dtop < len) {
			a = 0.97;
			col = vec3(0.55, 0.02, 0.05);
			if (fract(uv.x * 24.0) < 0.22) col = vec3(0.85, 0.1, 0.12);
			if (dtop > len - 0.012) col = vec3(0.95, 0.2, 0.2);
		}
		float vig = 1.0 - smoothstep(0.0, 0.12, min(uv.x, 1.0 - uv.x));
		if (a < 0.1) { a = vig * 0.3; col = vec3(0.5, 0.02, 0.06); }
	}
	COLOR = vec4(col, a * intensity);
}
"""

var _edge: ColorRect
var _edge_mat: ShaderMaterial
var _edge_tween: Tween
var _counter: Control
var _num_label: Label
var _title_label: Label
var _sub_label: Label
var _turns: int = 0
var _max: int = 1
var _paused: bool = false
var _active: bool = false
var _time: float = 0.0
var _intro_busy: bool = false

func _init() -> void:
	layer = 90
	_build_edge()
	_build_counter()
	_counter.visible = false

func _ready() -> void:
	set_process(true)

# ---------------------------------------------------------------------
# BORDAS (ondas vermelhas)
# ---------------------------------------------------------------------
func _build_edge() -> void:
	var shader := Shader.new()
	shader.code = EDGE_SHADER
	_edge_mat = ShaderMaterial.new()
	_edge_mat.shader = shader
	_edge_mat.set_shader_parameter("intensity", 0.0)
	_edge_mat.set_shader_parameter("mode", 0)
	_edge_mat.set_shader_parameter("progress", 0.0)
	_edge = ColorRect.new()
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.material = _edge_mat
	_edge.visible = false
	# Camada própria, abaixo da HUD (80), para não cobrir cartas nem painéis.
	var edge_layer := CanvasLayer.new()
	edge_layer.layer = 70
	edge_layer.add_child(_edge)
	add_child(edge_layer)

# Troca o formato do efeito das bordas (0 ondas, 1 chamas, 2 rachaduras, 3 cerco,
# 4 névoa, 5 raios, 6 glitch, 7 gotejar). `progress` 0..1 = quanto já passou.
func set_edge_mode(mode: int, progress: float = 0.0) -> void:
	_edge_mat.set_shader_parameter("mode", mode)
	_edge_mat.set_shader_parameter("progress", progress)

func _update_edge(active: bool, paused: bool) -> void:
	var target: float = 0.0
	if active:
		target = 0.35 if paused else 1.0
	_edge_mat.set_shader_parameter("tint", Color(0.35, 0.65, 1.0) if paused else Color(1.0, 0.12, 0.16))
	if _edge_tween != null and _edge_tween.is_valid():
		_edge_tween.kill()
	if active:
		_edge.visible = true
	_edge_tween = create_tween().set_parallel(true)
	_edge_tween.tween_property(_edge_mat, "shader_parameter/intensity", target, 1.2 if active else 0.4)
	if not active:
		_edge_tween.chain().tween_callback(func(): _edge.visible = false)

# ---------------------------------------------------------------------
# CONTADOR
# ---------------------------------------------------------------------
func _build_counter() -> void:
	_counter = Control.new()
	_counter.position = Vector2(40.0, 10.0)
	_counter.size = Vector2(440.0, 100.0)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter.draw.connect(_draw_counter)
	add_child(_counter)

	_num_label = Label.new()
	_num_label.position = Vector2(10.0, 10.0)
	_num_label.size = Vector2(80.0, 80.0)
	_num_label.pivot_offset = Vector2(40.0, 40.0)
	_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_num_label.add_theme_font_size_override("font_size", 72)
	_num_label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02))
	_num_label.add_theme_constant_override("outline_size", 8)
	_counter.add_child(_num_label)

	_title_label = Label.new()
	_title_label.position = Vector2(104.0, 8.0)
	_title_label.size = Vector2(320.0, 34.0)
	_title_label.text = "MORTE SÚBITA"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", C_RED)
	_title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02))
	_title_label.add_theme_constant_override("outline_size", 6)
	_counter.add_child(_title_label)

	_sub_label = Label.new()
	_sub_label.position = Vector2(104.0, 40.0)
	_sub_label.size = Vector2(320.0, 24.0)
	_sub_label.add_theme_font_size_override("font_size", 20)
	_sub_label.add_theme_color_override("font_color", C_CREAM)
	_counter.add_child(_sub_label)

# Retângulo do contador na tela (o tutorial destaca essa área).
func get_counter_rect() -> Rect2:
	return Rect2(_counter.position, _counter.size)

# Chamado pelo manager sempre que algo muda.
func set_state(active: bool, turns_left: int, max_turns: int, paused: bool) -> void:
	var changed_turn: bool = active and _active and turns_left != _turns
	_active = active
	_turns = turns_left
	_max = maxi(1, max_turns)
	_paused = paused
	_counter.visible = active
	_refresh_texts()
	_update_edge(active, paused)
	if changed_turn:
		_pop_number()
	_counter.queue_redraw()

func _refresh_texts() -> void:
	_num_label.text = str(maxi(_turns, 0))
	_sub_label.text = "PAUSADA" if _paused else ("ÚLTIMO TURNO!" if _turns == 1 else "TURNOS RESTANTES")
	_num_label.add_theme_color_override("font_color", _num_color())
	_sub_label.add_theme_color_override("font_color", C_BLUE if _paused else (C_RED if _turns <= WARN_TURNS else C_CREAM))
	_title_label.add_theme_color_override("font_color", C_BLUE if _paused else C_RED)

func _num_color() -> Color:
	if _paused:
		return C_BLUE
	if _turns <= WARN_TURNS:
		return Color(1.0, 0.85, 0.8)
	return C_RED

func _pop_number() -> void:
	_num_label.scale = Vector2(1.7, 1.7)
	var tw := create_tween()
	tw.tween_property(_num_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_counter.queue_redraw()

func _draw_counter() -> void:
	var rect := Rect2(Vector2.ZERO, _counter.size)
	var urgent: bool = _turns <= WARN_TURNS and not _paused
	var speed: float = 9.0 if urgent else 3.0
	var pulse: float = 0.5 + 0.5 * sin(_time * speed)
	var edge: Color = C_BLUE if _paused else C_RED
	var bg := Color(0.04, 0.07, 0.12, 0.96) if _paused else C_RED_DARK
	if urgent:
		bg = bg.lerp(Color(0.32, 0.03, 0.06), pulse * 0.8)
	_counter.draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.45))
	_counter.draw_rect(rect, bg)
	_counter.draw_rect(rect, edge.darkened(0.25 + 0.2 * (1.0 - pulse)), false, 3.0)
	_counter.draw_rect(rect.grow(-6.0), edge.darkened(0.55), false, 1.0)
	PixelRenderer.draw_pixel_corners(_counter, rect, edge.lightened(0.25), 10.0, 3.0)
	# Caixa do número.
	var box := Rect2(8, 8, 84, 84)
	_counter.draw_rect(box, Color(0, 0, 0, 0.45))
	_counter.draw_rect(box, edge.darkened(0.3), false, 2.0)
	# Barrinhas: uma por turno do total; as que restam ficam acesas.
	var n: int = mini(_max, 16)
	var gap: float = 4.0
	var area_w: float = 316.0
	var pw: float = minf(26.0, (area_w - gap * float(n - 1)) / float(n))
	var x0: float = 104.0
	for i in range(n):
		var lit: bool = i < _turns
		var r := Rect2(x0 + float(i) * (pw + gap), 74.0, pw, 14.0)
		if lit:
			var c: Color = edge
			if urgent:
				c = edge.lerp(Color(1, 0.85, 0.8), pulse * 0.6)
			_counter.draw_rect(r, c)
			_counter.draw_rect(Rect2(r.position, Vector2(r.size.x, 4.0)), c.lightened(0.35))
		else:
			_counter.draw_rect(r, Color(0.2, 0.08, 0.1, 0.8))
		_counter.draw_rect(r, Color(0.04, 0.0, 0.02), false, 1.0)

# ---------------------------------------------------------------------
# AVISO DE INÍCIO
# ---------------------------------------------------------------------
# Faixa vermelha cruzando a tela com "MORTE SÚBITA". `stall`: começou por
# impasse (ninguém avançava). Bloqueia cliques e some sozinho (~3 s).
func play_intro(_turns_left: int = 0, _stall: bool = false, shake_node: Node = null) -> void:
	if _intro_busy:
		return
	_intro_busy = true
	Sfx.play("morte_subita")   # o impacto cai junto com a palavra batendo (~0,16 s)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.2, 0.0, 0.03, 0.0)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)

	var vp: Vector2 = root.get_viewport().get_visible_rect().size
	var band_h: float = 190.0
	var band := Control.new()
	band.position = Vector2(0.0, (vp.y - band_h) / 2.0)
	band.size = Vector2(vp.x, band_h)
	band.pivot_offset = Vector2(vp.x / 2.0, band_h / 2.0)
	band.scale = Vector2(1.0, 0.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)

	var fill := ColorRect.new()
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.color = Color(0.1, 0.01, 0.03, 0.94)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(fill)
	for top in [true, false]:
		var line := ColorRect.new()
		line.color = C_RED
		line.size = Vector2(vp.x, 6.0)
		line.position = Vector2(0.0, 0.0 if top else band_h - 6.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(line)
		var line2 := ColorRect.new()
		line2.color = Color(1.0, 0.75, 0.3)
		line2.size = Vector2(vp.x, 2.0)
		line2.position = Vector2(0.0, 10.0 if top else band_h - 12.0)
		line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(line2)

	var word := Label.new()
	word.text = "MORTE SÚBITA"
	word.set_anchors_preset(Control.PRESET_FULL_RECT)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.add_theme_font_size_override("font_size", 128)
	word.add_theme_color_override("font_color", C_RED)
	word.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02))
	word.add_theme_constant_override("outline_size", 18)
	word.modulate.a = 0.0
	band.add_child(word)

	await get_tree().process_frame
	word.pivot_offset = word.size / 2.0
	word.scale = Vector2(1.5, 1.5)

	# Entrada rápida: a faixa abre e a palavra "bate" na tela.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(tint, "color:a", 0.35, 0.12)
	tw.tween_property(band, "scale:y", 1.0, 0.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(word, "modulate:a", 1.0, 0.06).set_delay(0.06)
	tw.tween_property(word, "scale", Vector2.ONE, 0.14).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.16).timeout
	if shake_node != null:
		Juice.shake(shake_node, 12.0, 0.25)
	await tw.finished
	await get_tree().create_timer(0.7).timeout

	var out := create_tween().set_parallel(true)
	out.tween_property(tint, "color:a", 0.0, 0.18)
	out.tween_property(band, "scale:y", 0.0, 0.15).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	out.tween_property(word, "modulate:a", 0.0, 0.1)
	await out.finished
	root.queue_free()
	_intro_busy = false
	# O contador entra com um "tapa" depois que a faixa some.
	_pop_number()
