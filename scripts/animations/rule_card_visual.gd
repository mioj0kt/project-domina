class_name RuleCardVisual
extends CardVisualBase

# Usa CardVisualBase pra reaproveitar card_root/flip (_setup_card_root,
# _play_flip_reveal) e, principalmente, o scroll automático de descrição
# (_maybe_start_description_scroll / _start_description_scroll_tween) — a
# MESMA lógica que ActionCardVisual usa em _build_text_face.
#
# Diferente das Cartas de Ação, a frente da Lei continua sendo o SPRITE de
# nota que o usuário desenhou (front_<categoria>.png, ou front_<id>.png se
# existir arte própria) — não o "papel" procedural genérico. O nome e a
# descrição são escritos por cima do sprite, reaproveitando só a função de
# scroll da base, não o _build_text_face inteiro (que desenharia seu próprio
# fundo de pergaminho por cima do sprite, escondendo-o).

# Formato Quadrado: CARD_SIZE é o tamanho do CORPO visível da carta. Os PNGs
# (160x160) ocupam a arte inteira (só os cantos chanfrados são transparentes),
# então o corpo é a arte toda (escala 2x com CARD_SIZE 320).
const CARD_SIZE: float = 320.0

const _ART_SIZE := Vector2(160, 160)
const _BODY := Rect2(0, 0, 160, 160)
# Regiões (px nativos, relativos ao canto do corpo).
# Frente nova: medalhão da categoria no canto sup. esquerdo; o nome fica numa
# faixa creme à direita dele.
const _TITLE_RECT := Rect2(38, 14, 110, 11)   # banner do nome (creme), ao lado do medalhão
const _DESC_RECT := Rect2(14, 34, 133, 90)    # janela ameixa: descrição (texto creme)
const _CAT_RECT := Rect2(12, 131, 137, 17)    # faixa creme de baixo: categoria + raridade
# Categoria no rodapé creme: maior que antes (9).
const _CAT_FONT_NATIVE: float = 13.0
const _DESC_PAD := Vector2(6, 4)
# Tamanho da fonte da descrição, em px nativos (multiplicado pela escala).
const _DESC_FONT_NATIVE: float = 16.0
# Nas Leis ATIVAS (miniaturas do HUD) o texto é bem maior; o que não couber
# rola sozinho (scroll automático de CardVisualBase).
const DESC_FONT_ACTIVE: float = 22.0
const _TITLE_INK := Color(0.14, 0.10, 0.17)
const _DESC_INK := Color(0.94, 0.90, 0.81)
const _BACK_PATH := "res://assets/sprites/rules/back.png"

var rule: RuleCard
var tooltip_ref: RuleCardTooltip
var _display_scale: float = 1.0
var _desc_font_native: float = _DESC_FONT_NATIVE

func _init(p_rule: RuleCard, p_tooltip: RuleCardTooltip = null, start_face_up: bool = false, display_scale: float = 1.0, desc_font_native: float = _DESC_FONT_NATIVE) -> void:
	_desc_font_native = desc_font_native
	rule = p_rule
	tooltip_ref = p_tooltip
	is_face_up = start_face_up
	_display_scale = display_scale
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_card_root(Vector2(CARD_SIZE, CARD_SIZE) * display_scale)
	_build_card()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _art_scale() -> float:
	return (CARD_SIZE * _display_scale) / _BODY.size.x

func _scaled_rect(r: Rect2) -> Rect2:
	var k = _art_scale()
	return Rect2(r.position * k, r.size * k)

# Fonte em px de tela: múltiplo inteiro de 7 (grade do m5x7) quando a escala
# permite, senão proporcional.
func _pixel_font_size(native_px: float) -> int:
	var k = _art_scale()
	if k >= 2.0:
		return int(floor(k)) * int(native_px)
	return maxi(6, int(round(native_px * k)))

# Monta uma Control do tamanho da carta com o PNG inteiro deslocado pra que o
# corpo visível caia exatamente em (0,0)-(card_size).
func _make_face_holder(tex_path: String) -> Control:
	var holder = Control.new()
	holder.custom_minimum_size = _card_size
	holder.size = _card_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k = _art_scale()
	holder.add_child(_make_art_rect(load(tex_path), Rect2(-_BODY.position * k, _ART_SIZE * k)))
	holder.position = -_card_size / 2.0
	card_root.add_child(holder)
	return holder

func _build_card() -> void:
	var cat_color_name = RuleCard.get_category_slug(rule.category if rule != null else 0)
	var cat_color = RuleCard.get_category_color(rule.category if rule != null else 0)
	var scaled_size = Vector2(CARD_SIZE, CARD_SIZE) * _display_scale

	# 1. VERSO — um único verso (back.png) para todas as categorias; cai pro
	# antigo back_{cor}.png e depois pro painel procedural.
	var legacy_back = "res://assets/sprites/rules/back_%s.png" % cat_color_name
	if ResourceLoader.exists(legacy_back):
		back_view = _make_face_holder(legacy_back)   # verso da categoria
	elif ResourceLoader.exists(_BACK_PATH):
		back_view = _make_face_holder(_BACK_PATH)
	else:
		back_view = _load_texture_or_fallback(legacy_back, func(): return _build_flat_panel(cat_color.darkened(0.5), cat_color, scaled_size))

	# 2. FRENTE — arte própria da lei (já com texto), senão a nota por
	# categoria com nome/descrição sobrepostos (scroll automático).
	var rule_id = rule.id if rule != null else ""
	var front_tex_path = "res://assets/sprites/rules/front_%s.png" % rule_id
	var front_cat_tex_path = "res://assets/sprites/rules/front_%s.png" % cat_color_name

	if ResourceLoader.exists(front_tex_path):
		front_view = _load_texture_or_fallback(front_tex_path, func(): return _build_flat_panel(Color(0.08, 0.1, 0.14, 0.98), cat_color, scaled_size))
	elif ResourceLoader.exists(front_cat_tex_path):
		front_view = _make_face_holder(front_cat_tex_path)
		_add_front_text(front_view, rule)
	else:
		front_view = _build_flat_panel(Color(0.08, 0.1, 0.14, 0.98), cat_color, scaled_size)
		front_view.position = -_card_size / 2.0
		card_root.add_child(front_view)
		_add_front_text(front_view, rule)

	back_view.visible = not is_face_up
	front_view.visible = is_face_up

	if rule != null and rule.boss_law:
		var fx := BossLawFx.new(scaled_size)
		fx.position = -_card_size / 2.0
		card_root.add_child(fx)

func _build_flat_panel(bg_color: Color, border_color: Color, panel_size: Vector2) -> Control:
	var p = PanelContainer.new()
	p.custom_minimum_size = panel_size
	p.size = panel_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(bg_color, border_color, 16))
	return p

# Nome no banner e descrição no pergaminho do sprite; a descrição usa o scroll
# automático de CardVisualBase quando não cabe.
func _add_front_text(parent_view: Control, rule_ref: RuleCard) -> void:
	if rule_ref == null:
		return
	var font: Font = load(_DESC_FONT_PATH)
	var k = _art_scale()

	# --- Nome (uma linha; encolhe até caber no banner) ---
	var title_r = _scaled_rect(_TITLE_RECT)
	var title_clip = Control.new()
	title_clip.position = title_r.position
	title_clip.size = title_r.size
	title_clip.clip_contents = true
	title_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_view.add_child(title_clip)

	var name_label = Label.new()
	name_label.text = rule_ref.name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_color_override("font_color", _TITLE_INK)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsize = maxi(8, int(round(14.0 * k)))
	while tsize > 6 and font != null and (
			font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x > title_r.size.x - 4.0 * k
			or tsize * 5.0 / 7.0 > title_r.size.y - 2.0 * k):
		tsize -= 1
	name_label.add_theme_font_size_override("font_size", tsize)
	var th = font.get_height(tsize) if font != null else title_r.size.y
	# Centralização manual (largura medida): o alinhamento do Label saiu
	# deslocado nos nomes longos.
	var tw = font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x if font != null else title_r.size.x
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size = Vector2(tw, th)
	name_label.position = Vector2(floor((title_r.size.x - tw) * 0.5), _caps_center_y(font, tsize, title_r.size.y))
	# Destaque: tinta mais escura, "negrito" (cópia deslocada) e sombra dourada.
	name_label.add_theme_color_override("font_color", Color(0.08, 0.05, 0.11))
	var off: float = maxf(1.0, round(k * 0.5))
	var bold = name_label.duplicate()
	bold.position = name_label.position + Vector2(off, 0)
	var shade = name_label.duplicate()
	shade.add_theme_color_override("font_color", Color(0.85, 0.64, 0.25, 0.9))
	shade.position = name_label.position + Vector2(off, maxf(1.0, round(k * 0.6)))
	title_clip.add_child(shade)
	title_clip.add_child(bold)
	title_clip.add_child(name_label)

	# --- Rodapé: categoria (esquerda) + raridade em losangos (direita) ---
	var cat_r = _scaled_rect(_CAT_RECT)
	var cat_col = RuleCard.get_category_color(rule_ref.category).darkened(0.45)
	var cat_label = Label.new()
	cat_label.text = RuleCard.get_category_name(rule_ref.category)
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cat_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	cat_label.add_theme_font_override("font", font)
	cat_label.add_theme_font_size_override("font_size", maxi(8, int(round(_CAT_FONT_NATIVE * k))))
	cat_label.add_theme_color_override("font_color", cat_col)
	cat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cat_fs = maxi(8, int(round(_CAT_FONT_NATIVE * k)))
	var cat_h = font.get_height(cat_fs) if font != null else cat_r.size.y
	# Categoria (ex.: TABULEIRO) centralizada na faixa creme de baixo.
	var cat_w = font.get_string_size(cat_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, cat_fs).x if font != null else cat_r.size.x
	cat_label.position = cat_r.position + Vector2(floor((cat_r.size.x - cat_w) * 0.5), _caps_center_y(font, cat_fs, cat_r.size.y))
	cat_label.size = Vector2(cat_w + 2.0, cat_h)
	parent_view.add_child(cat_label)

	# Losangos de raridade (1 a 4), à direita: quadradinhos girados 45 graus.
	var n_pips: int = int(rule_ref.rarity) + 1
	var pip_side: float = 3.6 * k
	var pip_gap: float = 6.0 * k
	for i in range(n_pips):
		var pip = ColorRect.new()
		pip.color = cat_col
		pip.size = Vector2(pip_side, pip_side)
		pip.pivot_offset = pip.size * 0.5
		pip.rotation = PI / 4.0
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cx = cat_r.position.x + cat_r.size.x - 9.0 * k - float(n_pips - 1 - i) * pip_gap
		pip.position = Vector2(cx - pip_side * 0.5, cat_r.position.y + (cat_r.size.y - pip_side) * 0.5)
		parent_view.add_child(pip)

	# --- Descrição ---
	var desc_r = _scaled_rect(_DESC_RECT)
	var clip = Control.new()
	clip.position = desc_r.position
	clip.size = desc_r.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_view.add_child(clip)

	var pad = _DESC_PAD * k
	var available_width = desc_r.size.x - 2.0 * pad.x
	var available_height = desc_r.size.y - 2.0 * pad.y
	var desc_label = Label.new()
	desc_label.text = rule_ref.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", font)
	desc_label.add_theme_font_size_override("font_size", maxi(8, int(round(_desc_font_native * k))))
	desc_label.add_theme_color_override("font_color", _DESC_INK)
	desc_label.add_theme_constant_override("line_spacing", 0)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.position = pad
	desc_label.size = Vector2(available_width, available_height)
	# Cabendo na janela, centraliza também na vertical; senão fica no topo e
	# rola sozinho (scroll automático).
	if font != null:
		var dfs: int = maxi(8, int(round(_desc_font_native * k)))
		var content_h: float = font.get_multiline_string_size(rule_ref.description, HORIZONTAL_ALIGNMENT_CENTER, available_width, dfs).y
		if content_h < available_height:
			desc_label.position.y = pad.y + floor((available_height - content_h) * 0.5)
			desc_label.size.y = content_h
	clip.add_child(desc_label)
	call_deferred("_maybe_start_description_scroll", desc_label, available_width, available_height)

func play_flip_reveal(delay: float = 0.0) -> void:
	_play_flip_reveal(delay, 0.18, 0.22)

func _on_mouse_entered() -> void:
	if not is_face_up or tooltip_ref == null or rule == null:
		return
	# "size" já inclui o display_scale (CardVisualBase monta o card_root no
	# tamanho final, em vez de aplicar Control.scale por cima), então não
	# multiplicamos por _display_scale aqui de novo.
	var screen_pos = global_position + Vector2(size.x + 16.0, 0.0)
	tooltip_ref.show_tooltip(rule, screen_pos)

func _on_mouse_exited() -> void:
	if tooltip_ref != null:
		tooltip_ref.hide_tooltip()
