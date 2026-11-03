class_name BoardTileTooltip
extends CanvasLayer

# Mesmo tamanho/estilo visual do RuleCardTooltip (largura, fontes, reposição
# anti-overflow), mas mostra 1+ "blocos de efeito" empilhados — cada casa
# especial pode ter mais de um efeito ativo ao mesmo tempo (ex: Zona Sagrada
# e Casas de Poder nas mesmas 4 casas centrais).

const TOOLTIP_WIDTH: float = 420.0

var panel: PanelContainer
var effects_container: VBoxContainer

func _ready() -> void:
	layer = 160
	visible = false
	_build_ui()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", PixelUI.make_tooltip_panel())
	add_child(panel)

	effects_container = VBoxContainer.new()
	effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_container.add_theme_constant_override("separation", 14)
	panel.add_child(effects_container)

# effects: Array de {"title": String, "desc": String, "affects": "player"/"enemy"/"both", "title_color": Color}
func show_effects(effects: Array, screen_pos: Vector2, human_team: int, ai_team: int) -> void:
	# remove_child ANTES do queue_free: senão os blocos antigos ainda contam no
	# layout deste frame e o painel fica do tamanho do tooltip anterior (cresce e
	# nunca encolhe).
	for child in effects_container.get_children():
		effects_container.remove_child(child)
		child.queue_free()

	if effects.is_empty():
		hide_tooltip()
		return

	for i in range(effects.size()):
		var eff = effects[i]

		if i > 0:
			var divider = ColorRect.new()
			divider.custom_minimum_size = Vector2(0, 2)
			divider.color = Color(0.3, 0.34, 0.42, 0.8)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			effects_container.add_child(divider)

		var block = VBoxContainer.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_theme_constant_override("separation", 8)
		effects_container.add_child(block)

		var title_lbl = Label.new()
		title_lbl.text = eff.get("title", "")
		title_lbl.add_theme_font_size_override("font_size", 26)
		title_lbl.add_theme_color_override("font_color", eff.get("title_color", Color(1.0, 0.9, 0.35)))
		title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
		title_lbl.add_theme_constant_override("outline_size", 6)
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(title_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = eff.get("desc", "")
		desc_lbl.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 36.0, 0)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 20)
		desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98))
		desc_lbl.add_theme_constant_override("line_spacing", 4)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(desc_lbl)

		var affects_row = HBoxContainer.new()
		affects_row.add_theme_constant_override("separation", 8)
		affects_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(affects_row)

		var affects_lbl = Label.new()
		affects_lbl.text = "Afeta:"
		affects_lbl.add_theme_font_size_override("font_size", 20)
		affects_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		affects_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		affects_row.add_child(affects_lbl)

		var affects: String = eff.get("affects", "both")
		if affects == "player" or affects == "both":
			affects_row.add_child(_build_piece_icon(human_team == Board.WHITE))
		if affects == "enemy" or affects == "both":
			affects_row.add_child(_build_piece_icon(ai_team == Board.WHITE))

		var affects_word = Label.new()
		affects_word.text = {"player": "Jogador", "enemy": "Inimigo", "both": "Os dois lados"}.get(affects, "?")
		affects_word.add_theme_font_size_override("font_size", 20)
		affects_word.add_theme_color_override("font_color", Color(0.9, 0.93, 0.98))
		affects_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		affects_row.add_child(affects_word)

	panel.modulate = Color.TRANSPARENT
	visible = true
	panel.size = Vector2(TOOLTIP_WIDTH, 0)
	panel.reset_size()
	_reposition.call_deferred(screen_pos)

func _reposition(screen_pos: Vector2) -> void:
	if not visible:
		return

	var vp_size = panel.get_viewport_rect().size
	var box_w = panel.size.x
	var box_h = panel.size.y
	var margin = 18.0

	var target_x = screen_pos.x + 20.0
	var target_y = screen_pos.y + 20.0

	if target_x + box_w > vp_size.x - margin:
		target_x = screen_pos.x - box_w - 20.0
	if target_y + box_h > vp_size.y - margin:
		target_y = screen_pos.y - box_h - 10.0

	target_x = clampf(target_x, margin, max(margin, vp_size.x - box_w - margin))
	target_y = clampf(target_y, margin, max(margin, vp_size.y - box_h - margin))

	panel.position = Vector2(target_x, target_y)
	panel.modulate = Color.WHITE

func _build_piece_icon(is_white: bool) -> Control:
	var icon = _PieceIcon.new()
	icon.piece_team = Board.WHITE if is_white else Board.BLACK
	icon.custom_minimum_size = Vector2(26, 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func hide_tooltip() -> void:
	visible = false
	panel.modulate = Color.TRANSPARENT

class _PieceIcon:
	extends Control

	var piece_team: int = Board.WHITE

	func _draw() -> void:
		var is_white = (piece_team == Board.WHITE)
		var dummy_piece = BoardPiece.new(piece_team, false)
		var tex = PixelRenderer.get_piece_texture(dummy_piece)

		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			return

		var center = size / 2.0
		var radius = minf(size.x, size.y) / 2.0 - 2.0
		var bg_color = Color(0.92, 0.92, 0.95) if is_white else Color(0.16, 0.18, 0.23)
		var ring_color = Color(0.55, 0.55, 0.6) if is_white else Color(0.05, 0.05, 0.08)

		draw_circle(center + Vector2(1, 2), radius, Color(0, 0, 0, 0.35))
		draw_circle(center, radius, bg_color)
		draw_arc(center, radius, 0, TAU, 24, ring_color, 2.0)
