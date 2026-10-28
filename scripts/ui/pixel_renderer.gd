class_name PixelRenderer
extends RefCounted

static var texture_cache: Dictionary = {}

static func get_piece_texture(piece_obj: BoardPiece) -> Texture2D:
	if piece_obj == null:
		return null

	var path = piece_obj.get_texture()
	if path != "" and ResourceLoader.exists(path):
		if not texture_cache.has(path):
			texture_cache[path] = load(path) as Texture2D
		return texture_cache[path]

	return null

# Desenha Cantoneiras Pixeladas
static func draw_pixel_corners(canvas: CanvasItem, rect: Rect2, color: Color, size_px: float = 8.0, thickness: float = 2.0) -> void:
	var l = rect.position.x + 2
	var r = rect.position.x + rect.size.x - 2
	var t = rect.position.y + 2
	var b = rect.position.y + rect.size.y - 2

	# Top-Left
	canvas.draw_line(Vector2(l, t), Vector2(l + size_px, t), color, thickness)
	canvas.draw_line(Vector2(l, t), Vector2(l, t + size_px), color, thickness)

	# Top-Right
	canvas.draw_line(Vector2(r, t), Vector2(r - size_px, t), color, thickness)
	canvas.draw_line(Vector2(r, t), Vector2(r, t + size_px), color, thickness)

	# Bottom-Left
	canvas.draw_line(Vector2(l, b), Vector2(l + size_px, b), color, thickness)
	canvas.draw_line(Vector2(l, b), Vector2(l, b - size_px), color, thickness)

	# Bottom-Right
	canvas.draw_line(Vector2(r, b), Vector2(r - size_px, b), color, thickness)
	canvas.draw_line(Vector2(r, b), Vector2(r, b - size_px), color, thickness)

# 1. VISUAL DA CASA SELECIONADA
static func draw_pixel_selected_tile(canvas: CanvasItem, tile_rect: Rect2, pulse: float) -> void:
	var pad = 2.0
	var inner_rect = Rect2(tile_rect.position.x + pad, tile_rect.position.y + pad, tile_rect.size.x - pad * 2, tile_rect.size.y - pad * 2)

	canvas.draw_rect(inner_rect, Color(0.15, 0.95, 0.45, 0.22))
	var border_col = Color(0.2, 1.0, 0.5, 0.9)
	canvas.draw_rect(inner_rect, border_col, false, 2.0)

	var corner_len = clamp(10.0 * pulse, 8.0, 14.0)
	draw_pixel_corners(canvas, inner_rect, Color(0.8, 1.0, 0.85, 1.0), corner_len, 3.0)

# 2. VISUAL DOS PONTOS INDICADORES DE MOVIMENTO E CAPTURA
# Arte própria: folhas de 4 quadros 26x26 (fx/mover_sheet.png e fx/captura_sheet.png),
# em loop. Se o arquivo faltar, vale o desenho em código logo abaixo.
const _MARKER_MOVE: String = "res://assets/sprites/fx/mover_sheet.png"
const _MARKER_CAPTURE: String = "res://assets/sprites/fx/captura_sheet.png"
# Só o quadrado (sem losango/X): é o que aparece em toda casa válida; o símbolo
# (folhas acima) só entra quando o mouse está sobre a casa.
const _MARKER_MOVE_BASE: String = "res://assets/sprites/fx/mover_base_sheet.png"
const _MARKER_CAPTURE_BASE: String = "res://assets/sprites/fx/captura_base_sheet.png"
const _MARKER_FRAME_PX: int = 26
const _MARKER_FPS: float = 5.0
const _MARKER_MARGIN_PX: int = 4
static var _marker_cache: Dictionary = {}

static func _marker_tex(path: String) -> Texture2D:
	if not _marker_cache.has(path):
		_marker_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _marker_cache[path]

static func _draw_move_marker_sprite(canvas: CanvasItem, dest_rect: Rect2, is_capture: bool, hovered: bool = false) -> bool:
	var full: Texture2D = _marker_tex(_MARKER_CAPTURE if is_capture else _MARKER_MOVE)
	var tex: Texture2D = full
	if not hovered:
		var base: Texture2D = _marker_tex(_MARKER_CAPTURE_BASE if is_capture else _MARKER_MOVE_BASE)
		if base != null:
			tex = base
	if tex == null:
		return false
	var frames: int = maxi(1, int(tex.get_width() / _MARKER_FRAME_PX))
	var f: int = int(Time.get_ticks_msec() / 1000.0 * _MARKER_FPS) % frames
	# A arte tem ~3 px de margem transparente por lado: corta a margem pra o
	# marcador cobrir a casa inteira (o pulso entre os quadros continua).
	var m: int = _MARKER_MARGIN_PX
	canvas.draw_texture_rect_region(tex, dest_rect, Rect2(f * _MARKER_FRAME_PX + m, m, _MARKER_FRAME_PX - m * 2, _MARKER_FRAME_PX - m * 2))
	return true

static func draw_pixel_move_target(canvas: CanvasItem, dest_rect: Rect2, is_capture: bool, pulse: float, hovered: bool = false) -> void:
	if _draw_move_marker_sprite(canvas, dest_rect, is_capture, hovered):
		return
	var center = dest_rect.position + (dest_rect.size / 2.0)
	var pad = 4.0
	var inner_tile = Rect2(dest_rect.position.x + pad, dest_rect.position.y + pad, dest_rect.size.x - pad * 2, dest_rect.size.y - pad * 2)

	if is_capture:
		var floor_alpha = clamp(0.18 + (pulse - 1.0) * 0.35, 0.15, 0.35)
		canvas.draw_rect(inner_tile, Color(1.0, 0.15, 0.22, floor_alpha))
		
		var corner_size = clamp(7.0 * pulse, 6.0, 10.0)
		draw_pixel_corners(canvas, inner_tile, Color(1.0, 0.35, 0.4, 0.95), corner_size, 2.0)

		var arm = 8.5 * pulse
		var red_light = Color(1.0, 0.3, 0.35)
		var red_dark = Color(0.65, 0.08, 0.12)
		var gold_core = Color(1.0, 0.9, 0.3)

		canvas.draw_line(center + Vector2(-arm + 1, -arm + 2), center + Vector2(arm + 1, arm + 2), Color(0, 0, 0, 0.5), 3.0)
		canvas.draw_line(center + Vector2(-arm + 1, arm + 2), center + Vector2(arm + 1, -arm + 2), Color(0, 0, 0, 0.5), 3.0)

		canvas.draw_line(center - Vector2(arm, arm), center + Vector2(arm, arm), red_dark, 3.5)
		canvas.draw_line(center - Vector2(arm, -arm), center + Vector2(arm, -arm), red_dark, 3.5)
		canvas.draw_line(center - Vector2(arm - 1, arm - 1), center + Vector2(arm - 1, arm - 1), red_light, 1.5)
		canvas.draw_line(center - Vector2(arm - 1, -arm + 1), center + Vector2(arm - 1, -arm + 1), red_light, 1.5)

		canvas.draw_rect(Rect2(center.x - 2, center.y - 2, 4, 4), Color(0.2, 0.02, 0.02))
		canvas.draw_rect(Rect2(center.x - 1, center.y - 1, 2, 2), gold_core)
	else:
		var glow_alpha = clamp(0.12 + (pulse - 1.0) * 0.25, 0.10, 0.25)
		canvas.draw_rect(inner_tile, Color(0.2, 0.85, 0.65, glow_alpha))

		var sz = 6.0 * pulse
		var shadow_offset = Vector2(0, 2.5)

		var top_pt = center + Vector2(0, -sz)
		var right_pt = center + Vector2(sz, 0)
		var bottom_pt = center + Vector2(0, sz)
		var left_pt = center + Vector2(-sz, 0)

		var shadow_poly = PackedVector2Array([
			top_pt + shadow_offset,
			right_pt + shadow_offset,
			bottom_pt + shadow_offset,
			left_pt + shadow_offset
		])
		canvas.draw_colored_polygon(shadow_poly, Color(0.02, 0.05, 0.04, 0.45))

		var top_facet = PackedVector2Array([left_pt, top_pt, right_pt, center])
		canvas.draw_colored_polygon(top_facet, Color(0.45, 1.0, 0.82, 0.95))

		var bottom_facet = PackedVector2Array([left_pt, center, right_pt, bottom_pt])
		canvas.draw_colored_polygon(bottom_facet, Color(0.12, 0.68, 0.48, 0.95))

		var outline_pts = PackedVector2Array([top_pt, right_pt, bottom_pt, left_pt, top_pt])
		canvas.draw_polyline(outline_pts, Color(0.04, 0.18, 0.12, 0.95), 1.5)

		canvas.draw_line(left_pt, right_pt, Color(0.75, 1.0, 0.92, 0.9), 1.0)
		canvas.draw_rect(Rect2(center.x - 1, center.y - 1, 2, 2), Color.WHITE)

# 3. RENDERIZAÇÃO DA PEÇA
static func draw_piece(canvas: CanvasItem, piece_obj: BoardPiece, center: Vector2, cell_size: float, scale_factor: float) -> void:
	if piece_obj == null:
		return

	if piece_obj.is_cactus:
		if not _draw_boss_sprite(canvas, _CACTUS_SPRITES, piece_obj, center, cell_size, scale_factor):
			_draw_cactus(canvas, center, cell_size, scale_factor)
		return

	if piece_obj.is_sarcophagus:
		if not _draw_boss_sprite(canvas, _SARCOPHAGUS_SPRITES, piece_obj, center, cell_size, scale_factor):
			_draw_sarcophagus(canvas, center, cell_size, scale_factor)
		return

	if piece_obj.is_tree:
		var ttex: Texture2D = _get_tree_tex(piece_obj.get_instance_id())
		if ttex != null:
			# Altura ~110% da casa (a arte tem folga transparente), proporção da arte; escala inteira de pixel quando dá.
			var k: float = cell_size * scale_factor * 1.1 / float(ttex.get_height())
			if k >= 2.0:
				k = floorf(k)
			var dsz: Vector2 = ttex.get_size() * k
			canvas.draw_texture_rect(ttex, Rect2((center - dsz / 2.0 + Vector2(0, cell_size * scale_factor * 0.02)).round(), dsz), false)
		else:
			_draw_tree(canvas, center, cell_size, scale_factor)
		return

	var is_white = (piece_obj.owner_team == Board.WHITE)
	var tex = get_piece_texture(piece_obj)

	if tex != null:
		var dest_size = Vector2(cell_size * 0.82, cell_size * 0.82) * scale_factor
		var dest_rect = Rect2(center - (dest_size / 2.0), dest_size)
		var shadow_rect = Rect2(dest_rect.position + Vector2(2, 3), dest_size)
		canvas.draw_texture_rect(tex, shadow_rect, false, Color(0, 0, 0, 0.35))
		canvas.draw_texture_rect(tex, dest_rect, false, Color.WHITE)
	else:
		var base_radius = (cell_size * 0.36) * scale_factor
		var bg_color = Color(0.92, 0.92, 0.95) if is_white else Color(0.18, 0.2, 0.25)
		if piece_obj.color_override != Color.TRANSPARENT:
			bg_color = piece_obj.color_override

		canvas.draw_circle(center + Vector2(2, 4), base_radius, Color(0, 0, 0, 0.35))
		canvas.draw_circle(center, base_radius, bg_color)

		var border_color = Color(0.15, 0.15, 0.18) if is_white else Color(0.06, 0.06, 0.08)
		canvas.draw_arc(center, base_radius, 0, TAU, 24, border_color, 2.0)
		canvas.draw_arc(center, base_radius * 0.65, 0, TAU, 16, border_color, 1.5)

		if piece_obj.is_king:
			var crown_col = Color(1.0, 0.84, 0.2) if is_white else Color(0.85, 0.2, 0.25)
			canvas.draw_circle(center, base_radius * 0.35, crown_col)
			canvas.draw_arc(center, base_radius * 0.35, 0, TAU, 12, Color(0.1, 0.1, 0.1, 0.8), 1.5)


# Árvore neutra do chefe da floresta: usa as copas em pixel art do cenário
# (variantes de chão escuro, cuja sombra serve em qualquer casa). A variante é
# fixa por árvore (id do objeto), então ela não "troca de cara" ao redesenhar.
const _TREE_SPRITES: Array[String] = [
	"res://assets/sprites/map/forest/tabuleiro/arvores/arvore_copa_2_chao_escuro.png",
	"res://assets/sprites/map/forest/tabuleiro/arvores/arvore_copa_4_chao_escuro.png",
	"res://assets/sprites/map/forest/tabuleiro/arvores/arvore_copa_5_chao_escuro.png",
]
static var _tree_tex: Array = []

static func _get_tree_tex(variant: int) -> Texture2D:
	if _tree_tex.is_empty():
		for path in _TREE_SPRITES:
			_tree_tex.append(load(path) if ResourceLoader.exists(path) else null)
	return _tree_tex[variant % _tree_tex.size()]

# Sprites 26x30 dos neutros do chefe do deserto (variante fixa por peça). Escala
# inteira de pixel, base apoiada no pé da casa. Devolve false se faltar arte.
const _BOSS_SPRITE_DIR := "res://assets/sprites/board/deserto_boss/"
const _CACTUS_SPRITES: Array[String] = ["cacto/cacto_dois_bracos", "cacto/cacto_um_braco", "cacto/cacto_barril"]
const _SARCOPHAGUS_SPRITES: Array[String] = ["sarcofago/sarcofago_intacto", "sarcofago/sarcofago_tampa_rachada", "sarcofago/sarcofago_inclinado"]
static var _boss_sprite_cache: Dictionary = {}

static func _draw_boss_sprite(canvas: CanvasItem, names: Array[String], piece_obj: BoardPiece, center: Vector2, cell_size: float, scale_factor: float) -> bool:
	var name: String = names[piece_obj.get_instance_id() % names.size()]
	if not _boss_sprite_cache.has(name):
		var p: String = _BOSS_SPRITE_DIR + name + ".png"
		_boss_sprite_cache[name] = load(p) if ResourceLoader.exists(p) else null
	var tex: Texture2D = _boss_sprite_cache[name]
	if tex == null:
		return false
	var k: float = maxf(1.0, floorf(cell_size * scale_factor / 26.0 + 0.35))
	var dsz: Vector2 = tex.get_size() * k
	var foot: Vector2 = center + Vector2(0.0, cell_size * scale_factor * 0.46)
	canvas.draw_texture_rect(tex, Rect2((foot - Vector2(dsz.x / 2.0, dsz.y)).round(), dsz), false)
	return true

# Cacto neutro do chefe do deserto (saguaro com espinhos), desenhado em código.
static func _draw_cactus(canvas: CanvasItem, center: Vector2, cell_size: float, scale_factor: float) -> void:
	var u: float = cell_size * scale_factor / 100.0
	var green := Color(0.28, 0.58, 0.30)
	var green_dark := Color(0.17, 0.40, 0.21)
	var green_light := Color(0.45, 0.76, 0.40)
	var line := Color(0.08, 0.22, 0.10)
	canvas.draw_circle(center + Vector2(2, 34) * u, 22.0 * u, Color(0, 0, 0, 0.25))
	# Braços (atrás do tronco), tronco e topo arredondado.
	canvas.draw_rect(Rect2(center + Vector2(-30, -6) * u, Vector2(18, 9) * u), green_dark)
	canvas.draw_rect(Rect2(center + Vector2(-30, -26) * u, Vector2(9, 28) * u), green_dark)
	canvas.draw_rect(Rect2(center + Vector2(12, 4) * u, Vector2(18, 9) * u), green_dark)
	canvas.draw_rect(Rect2(center + Vector2(21, -16) * u, Vector2(9, 28) * u), green_dark)
	canvas.draw_rect(Rect2(center + Vector2(-12, -34) * u, Vector2(24, 70) * u), green)
	canvas.draw_circle(center + Vector2(0, -34) * u, 12.0 * u, green)
	canvas.draw_rect(Rect2(center + Vector2(-12, -34) * u, Vector2(6, 70) * u), green_light)
	canvas.draw_rect(Rect2(center + Vector2(4, -34) * u, Vector2(3, 70) * u), green_dark)
	for sp in [Vector2(-8, -20), Vector2(8, -8), Vector2(-8, 8), Vector2(8, 22), Vector2(-26, -20), Vector2(26, -10), Vector2(0, -42)]:
		canvas.draw_rect(Rect2(center + sp * u, Vector2(3, 3) * u), Color(0.98, 0.95, 0.75))
	canvas.draw_rect(Rect2(center + Vector2(-12, -34) * u, Vector2(24, 70) * u), line, false, maxf(2.0, 2.0 * u))

# Sarcófago neutro do chefe do deserto, desenhado em código (arenito + máscara
# dourada + faixas de lápis-lazúli).
static func _draw_sarcophagus(canvas: CanvasItem, center: Vector2, cell_size: float, scale_factor: float) -> void:
	var u: float = cell_size * scale_factor / 100.0
	var sand := Color(0.80, 0.68, 0.44)
	var sand_dark := Color(0.60, 0.48, 0.28)
	var gold := Color(0.96, 0.78, 0.26)
	var lapis := Color(0.20, 0.36, 0.62)
	var line := Color(0.22, 0.15, 0.08)
	canvas.draw_circle(center + Vector2(2, 34) * u, 24.0 * u, Color(0, 0, 0, 0.25))
	var body := PackedVector2Array([
		center + Vector2(-12, -40) * u, center + Vector2(12, -40) * u,
		center + Vector2(21, -22) * u, center + Vector2(18, 34) * u,
		center + Vector2(-18, 34) * u, center + Vector2(-21, -22) * u])
	canvas.draw_colored_polygon(body, sand)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(4, -40) * u, center + Vector2(12, -40) * u, center + Vector2(21, -22) * u,
		center + Vector2(18, 34) * u, center + Vector2(8, 34) * u]), sand_dark)
	canvas.draw_rect(Rect2(center + Vector2(-19, -2) * u, Vector2(38, 6) * u), lapis)
	canvas.draw_rect(Rect2(center + Vector2(-19, 12) * u, Vector2(38, 6) * u), gold)
	canvas.draw_rect(Rect2(center + Vector2(-19, 24) * u, Vector2(38, 5) * u), lapis)
	canvas.draw_circle(center + Vector2(0, -22) * u, 10.0 * u, gold)
	canvas.draw_rect(Rect2(center + Vector2(-5, -25) * u, Vector2(3, 3) * u), line)
	canvas.draw_rect(Rect2(center + Vector2(2, -25) * u, Vector2(3, 3) * u), line)
	canvas.draw_rect(Rect2(center + Vector2(-2, -18) * u, Vector2(4, 2) * u), line)
	canvas.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[0]]), line, maxf(2.0, 2.0 * u))

# Reserva (sem sprite): árvore desenhada em código.
static func _draw_tree(canvas: CanvasItem, center: Vector2, cell_size: float, scale_factor: float) -> void:
	var u = cell_size * scale_factor / 100.0
	canvas.draw_rect(Rect2(center + Vector2(-7, 6) * u, Vector2(14, 28) * u), Color(0.36, 0.22, 0.12))
	canvas.draw_rect(Rect2(center + Vector2(-7, 6) * u, Vector2(5, 28) * u), Color(0.25, 0.15, 0.08))
	var tiers = [[-6.0, 34.0, Color(0.10, 0.36, 0.16)], [-20.0, 28.0, Color(0.14, 0.46, 0.20)], [-32.0, 20.0, Color(0.20, 0.58, 0.26)]]
	var base_y = [18.0, 4.0, -10.0]
	for i in range(3):
		var w = tiers[i][1]
		var by = base_y[i]
		var tip = center + Vector2(0, by - 30.0) * u
		var pts = PackedVector2Array([tip, center + Vector2(w, by) * u, center + Vector2(-w, by) * u])
		canvas.draw_colored_polygon(pts, tiers[i][2])
		canvas.draw_polyline(PackedVector2Array([pts[2], pts[0], pts[1], pts[2]]), Color(0.04, 0.16, 0.07), 2.0)
