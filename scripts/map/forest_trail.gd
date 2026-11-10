class_name ForestTrail
extends Node2D

# Trilha entre dois nós do mapa da floresta, desenhada casa a casa (estilo
# "grade"). Cada peça de res://assets/sprites/biomas/floresta/trilhas_grade/
# <estado>/<casa_clara|casa_escura>/trilha_<direções>.png ocupa UMA casa do
# tabuleiro (26 px nativos, canvas de 36 px com 5 px de sobra pra emendar nas
# vizinhas) e liga o centro da casa às casas vizinhas nas direções do nome
# (ordem sempre N, NE, SE, S, SW, NW). A cor da peça segue a casa: trilha clara
# em casa clara, escura em casa escura.
#
# O caminho de um nó até o outro sobe casa a casa: retos nas pontas e
# diagonais no meio (como o peão anda). Cada casa recebe uma peça com a
# entrada (casa anterior) e a saída (próxima casa); as casas dos nós também
# ganham a ponta, que fica sob o soquete do nó.

const DIR := "res://assets/sprites/biomas/floresta/trilhas_grade/"
const NATIVE_TILE: float = 26.0
const DIR_ORDER: Array[String] = ["N", "NE", "SE", "S", "SW", "NW"]

static var _tex_cache: Dictionary = {}

# Bioma do mapa (ver ForestBackground.THEMES); defina ANTES de setup().
var biome: String = "floresta"

var _sprites: Array[Sprite2D] = []
var _names: Array[String] = []
var _light: Array[bool] = []
var state: String = "normal"
var _outlines: Array[Sprite2D] = []

# Destaque do trecho selecionável SEM mexer na cor da arte: um contorno de 1 px
# nativo (creme quente) desenhado atrás da trilha, que pulsa de leve. A trilha
# em si continua exatamente a arte original.
const OUTLINE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0, 0.93, 0.66, 1.0);
uniform float speed = 2.2;
uniform float min_alpha = 0.35;
uniform float max_alpha = 0.95;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float a = texture(TEXTURE, UV).a;
	float n = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			n = max(n, texture(TEXTURE, UV + vec2(float(i), float(j)) * px).a);
		}
	}
	float edge = (1.0 - step(0.01, a)) * step(0.01, n);
	float pulse = mix(min_alpha, max_alpha, 0.5 + 0.5 * sin(TIME * speed));
	COLOR = vec4(outline_color.rgb, edge * pulse);
}
"""
static var _outline_material: ShaderMaterial = null

static func _get_outline_material() -> ShaderMaterial:
	if _outline_material == null:
		var sh := Shader.new()
		sh.code = OUTLINE_SHADER_CODE
		_outline_material = ShaderMaterial.new()
		_outline_material.shader = sh
	return _outline_material

func _update_outlines(on: bool) -> void:
	for o in _outlines:
		o.queue_free()
	_outlines.clear()
	if not on:
		return
	for sp in _sprites:
		if sp.texture == null:
			continue
		var o := Sprite2D.new()
		o.texture = sp.texture
		o.centered = true
		o.scale = sp.scale
		o.position = sp.position
		o.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		o.material = _get_outline_material()
		add_child(o)
		move_child(o, 0)
		_outlines.append(o)

static func _texture(piece: String, st: String, on_light: bool, dir: String = DIR) -> Texture2D:
	var key = "%s|%s/%s/%s" % [dir, st, "casa_clara" if on_light else "casa_escura", piece]
	if not _tex_cache.has(key):
		var path = dir + st + "/" + ("casa_clara" if on_light else "casa_escura") + "/trilha_" + piece + ".png"
		_tex_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[key]

# Quando um bioma não tem arte própria para um estado, usa a peça "normal" da
# mesma cor de casa RECOLORIDA pela luminosidade: selecionado = dourado,
# percorrido = apagado e quente, bloqueado = coberto de areia (translúcido).
# [escuro, médio, claro, alfa]
const STATE_RAMPS: Dictionary = {
	"selecionado": [Color("2e2008"), Color("b07a22"), Color("ffe08a"), 1.0],
	"percorrido": [Color("1b1514"), Color("5a4d44"), Color("9a8b78"), 1.0],
	"bloqueado": [Color("3a3028"), Color("8a7a5e"), Color("c9b88c"), 0.55],
}
# Rampas próprias por bioma (sobrepõem STATE_RAMPS): no deserto o dourado do
# trecho selecionado é mais fosco/dessaturado, para não gritar sobre a areia.
const BIOME_STATE_RAMPS: Dictionary = {
	"deserto": {
		"selecionado": [Color("2a2316"), Color("8a6f3c"), Color("d9c48f"), 1.0],
	},
}
static var _recolor_cache: Dictionary = {}
# Biomas em que o trecho "selecionado" NÃO ganha o dourado: usa a arte "normal"
# (a cor original da trilha). O caminho disponível já é indicado pelos anéis dos
# nós; o dourado da floresta destoava do mapa. Tire o bioma daqui para voltar.
const SELECTED_KEEPS_ORIGINAL: Array[String] = ["floresta", "deserto", "mina"]
# Biomas sem o contorno pulsante no trecho selecionado (nos trilhos diagonais da
# mina ele vira uma escadinha de quadrados).
# Biomas cuja arte de trilha vem com a cor invertida (pasta casa_clara = trilho
# escuro): aqui a trilha clara vai na casa clara e a escura na casa escura.
const SWAP_TILE_COLOR: Array[String] = []
const NO_SELECT_OUTLINE: Array[String] = ["mina"]

static func _recolored(tex: Texture2D, st: String, key: String, biome_id: String = "") -> Texture2D:
	if not STATE_RAMPS.has(st):
		return tex
	var ck := key + "|" + st + "|" + biome_id
	if _recolor_cache.has(ck):
		return _recolor_cache[ck]
	var ramp: Array = STATE_RAMPS[st]
	if BIOME_STATE_RAMPS.has(biome_id) and BIOME_STATE_RAMPS[biome_id].has(st):
		ramp = BIOME_STATE_RAMPS[biome_id][st]
	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p: Color = img.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			var l: float = clampf(p.get_luminance() * 1.25, 0.0, 1.0)
			var c: Color = (ramp[0] as Color).lerp(ramp[1], l * 2.0) if l < 0.5 else (ramp[1] as Color).lerp(ramp[2], (l - 0.5) * 2.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, p.a * float(ramp[3])))
	var out := ImageTexture.create_from_image(img)
	_recolor_cache[ck] = out
	return out

# Direção (como nome) de um passo em coordenadas de casa (y cresce pra baixo).
static func _dir_name(step: Vector2i) -> String:
	match step:
		Vector2i(0, -1): return "N"
		Vector2i(1, -1): return "NE"
		Vector2i(1, 1): return "SE"
		Vector2i(0, 1): return "S"
		Vector2i(-1, 1): return "SW"
		Vector2i(-1, -1): return "NW"
	return ""

static func _piece_name(dirs: Array) -> String:
	var parts: Array[String] = []
	for d in DIR_ORDER:
		if dirs.has(d):
			parts.append(d)
	return "_".join(parts)

# Passos de from_g até to_g: retos nas pontas, diagonais no meio. Só sobe.
static func build_steps(from_g: Vector2i, to_g: Vector2i) -> Array[Vector2i]:
	var steps: Array[Vector2i] = []
	var rows = from_g.y - to_g.y
	var dx = to_g.x - from_g.x
	var n_d = mini(absi(dx), rows)
	var n_v = rows - n_d
	var diag = Vector2i(1 if dx > 0 else -1, -1)
	@warning_ignore("integer_division")
	for i in range(n_v / 2):
		steps.append(Vector2i(0, -1))
	for i in range(n_d):
		steps.append(diag)
	@warning_ignore("integer_division")
	for i in range(n_v - n_v / 2):
		steps.append(Vector2i(0, -1))
	return steps

# from_pos / to_pos: centro (mundo) dos nós; tile_px: lado da casa em px.
func setup(from_pos: Vector2, to_pos: Vector2, sprite_scale: int) -> void:
	var tile_px = NATIVE_TILE * float(sprite_scale)
	var from_g = Vector2i((from_pos / tile_px).round())
	var to_g = Vector2i((to_pos / tile_px).round())
	var steps = build_steps(from_g, to_g)
	var g = from_g
	for k in range(steps.size() + 1):
		var dirs: Array = []
		if k > 0:
			dirs.append(_dir_name(-steps[k - 1]))
		if k < steps.size():
			dirs.append(_dir_name(steps[k]))
		_add_piece(g, _piece_name(dirs), tile_px, float(sprite_scale))
		if k < steps.size():
			g += steps[k]
	set_state("normal")

func _add_piece(g: Vector2i, piece: String, tile_px: float, s: float) -> void:
	var sp = Sprite2D.new()
	sp.centered = true
	sp.scale = Vector2(s, s)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = Vector2(g.x * tile_px, g.y * tile_px)
	add_child(sp)
	_sprites.append(sp)
	_names.append(piece)
	_light.append(((g.x + g.y) % 2 + 2) % 2 == 0)

# state: "normal" | "selecionado" | "percorrido" | "bloqueado"
func set_state(new_state: String) -> void:
	state = new_state
	var dir: String = String(ForestBackground.THEMES[biome]["trail_dir"])
	var swap: bool = SWAP_TILE_COLOR.has(biome)
	for i in range(_sprites.size()):
		var lt: bool = (not _light[i]) if swap else _light[i]
		var art_state: String = state
		if state == "selecionado" and SELECTED_KEEPS_ORIGINAL.has(biome):
			art_state = "normal"
		var tex: Texture2D = _texture(_names[i], art_state, lt, dir)
		var tint := Color.WHITE
		if tex == null:
			var base: Texture2D = _texture(_names[i], "normal", lt, dir)
			if base != null:
				tex = _recolored(base, state, "%s|%s|%s" % [dir, lt, _names[i]], biome)
		_sprites[i].texture = tex
		_sprites[i].modulate = tint
	_update_outlines(state == "selecionado" and not NO_SELECT_OUTLINE.has(biome))
