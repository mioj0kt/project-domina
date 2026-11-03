class_name CardSeal
extends Control

# Medalhão circular usado no canto da "frente em texto" das cartas e leis.
# Tenta um ícone específico do item; se não existir, tenta um ícone genérico
# do tipo (carta ou lei); se nenhum existir, desenha uma marca geométrica
# fechada no centro — losango para Cartas de Ação, hexágono para Leis, para
# que as duas famílias de carta tenham uma identidade visual distinta mesmo
# sem arte própria.

var color: Color
var shape: String
var icon_texture: Texture2D = null

func _init(custom_icon_path: String, generic_icon_path: String, p_color: Color, p_shape: String = "diamond") -> void:
	color = p_color
	shape = p_shape
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if custom_icon_path != "" and ResourceLoader.exists(custom_icon_path):
		icon_texture = load(custom_icon_path)
	elif generic_icon_path != "" and ResourceLoader.exists(generic_icon_path):
		icon_texture = load(generic_icon_path)

func _draw() -> void:
	var c = size / 2.0
	var r = minf(size.x, size.y) * 0.44

	# 1. Base do Selo: Círculo escuro com contorno
	draw_circle(c, r, Color(0.04, 0.05, 0.08, 0.95))
	draw_arc(c, r, 0, TAU, 32, Color(color.r, color.g, color.b, 0.7), 1.8)

	# 2. Ícone, ou marca geométrica fechada conforme o formato
	if icon_texture != null:
		var icon_size = Vector2(r * 1.3, r * 1.3)
		var dest_rect = Rect2(c - icon_size / 2.0, icon_size)
		draw_texture_rect(icon_texture, dest_rect, false)
	elif shape == "hexagon":
		_draw_hexagon_mark(c, r)
	else:
		_draw_diamond_mark(c, r)

func _draw_diamond_mark(c: Vector2, r: float) -> void:
	# Losango com 5 vértices (retornando ao ponto inicial) para fechar todos os 4 lados
	var p_top = c + Vector2(0, -r * 0.58)
	var p_right = c + Vector2(r * 0.52, 0)
	var p_bottom = c + Vector2(0, r * 0.58)
	var p_left = c + Vector2(-r * 0.52, 0)

	var diamond_poly = PackedVector2Array([p_top, p_right, p_bottom, p_left])
	var diamond_closed_outline = PackedVector2Array([p_top, p_right, p_bottom, p_left, p_top])

	draw_colored_polygon(diamond_poly, Color(color.r, color.g, color.b, 0.3))
	draw_polyline(diamond_closed_outline, color, 1.8)
	draw_circle(c, r * 0.16, color)

func _draw_hexagon_mark(c: Vector2, r: float) -> void:
	var hex_points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i - 90)
		hex_points.append(c + Vector2(cos(angle), sin(angle)) * r * 0.58)

	var hex_closed_outline = hex_points.duplicate()
	hex_closed_outline.append(hex_points[0])

	draw_colored_polygon(hex_points, Color(color.r, color.g, color.b, 0.3))
	draw_polyline(hex_closed_outline, color, 1.8)
	draw_circle(c, r * 0.14, color)
