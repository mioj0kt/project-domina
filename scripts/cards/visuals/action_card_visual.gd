class_name ActionCardVisual
extends CardVisualBase

const CARD_WIDTH: float = 150.0
const CARD_HEIGHT: float = 214.0

var card: ActionCard
var _display_scale: float = 1.0

func _init(p_card: ActionCard, start_face_up: bool = true, display_scale: float = 1.0) -> void:
	card = p_card
	is_face_up = start_face_up
	_display_scale = display_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_card_root(Vector2(CARD_WIDTH, CARD_HEIGHT) * display_scale)
	_build_card()

# Layout da arte (front_*.png, 112x160, sem margem transparente). O corpo é a arte
# inteira (_BODY); o PNG é desenhado
# deslocado por -_BODY.position, então enfeites de épica/lendária que passam do
# corpo (coroa, brilhos) continuam aparecendo, só que fora da caixa da carta.
# Coordenadas abaixo em px nativos relativos ao canto do corpo, multiplicadas
# pela escala (largura da carta / 112).
const _ART_SIZE := Vector2(112, 160)
const _BODY := Rect2(0, 0, 112, 160)
const _TITLE_RECT := Rect2(11, 11, 90, 9)     # banner superior
const _ICON_RECT := Rect2(24, 30, 64, 64)     # ícone 64x64 centrado na janela ameixa
const _DESC_RECT := Rect2(11, 110, 90, 39)    # caixa creme da descrição
const _BACK_RECT := Rect2(0, 0, 112, 160)
const _FACES_DIR := "res://assets/sprites/cards/faces/"
const _TITLE_INK := Color(0.14, 0.10, 0.17)
const _DESC_INK := Color(0.14, 0.10, 0.17)
# Descrição da carta de ação (px nativos): bem maior que antes (7); o que não
# couber rola sozinho (scroll automático de CardVisualBase).
const _DESC_FONT_NATIVE: float = 11.0

func _build_card() -> void:
	var rar_color: Color = get_rarity_color(card.rarity if card != null else 0)
	var rarity_slug = _get_rarity_slug(card.rarity if card != null else 0)

	back_view = _build_back_view(rar_color, rarity_slug)
	front_view = _build_front_view(rarity_slug, rar_color)
	front_view.position = -_card_size / 2.0
	card_root.add_child(front_view)

	back_view.visible = not is_face_up
	front_view.visible = is_face_up

func _art_scale() -> float:
	return (CARD_WIDTH * _display_scale) / _BODY.size.x

func _scaled_rect(r: Rect2) -> Rect2:
	var k = _art_scale()
	return Rect2(r.position * k, r.size * k)

func _build_back_view(rar_color: Color, rarity_slug: String = "") -> Control:
	# Verso por raridade (back_<raridade>.png); cai no verso único antigo.
	var back_path = "res://assets/sprites/cards/faces/back_%s.png" % rarity_slug
	if not ResourceLoader.exists(back_path):
		back_path = _FACES_DIR + "back.png"
	if not ResourceLoader.exists(back_path):
		return _load_texture_or_fallback("", func(): return _build_back_frame(rar_color))
	var holder = Control.new()
	holder.custom_minimum_size = _card_size
	holder.size = _card_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_make_art_rect(load(back_path), _scaled_rect(_BACK_RECT)))
	holder.position = -_card_size / 2.0
	card_root.add_child(holder)
	return holder

# Frente: base por raridade + título no banner + ícone no quadro central +
# descrição no pergaminho (com scroll automático quando não cabe).
func _build_front_view(rarity_slug: String, rar_color: Color) -> Control:
	var holder = Control.new()
	holder.custom_minimum_size = _card_size
	holder.size = _card_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_path = _FACES_DIR + "front_%s.png" % rarity_slug
	if ResourceLoader.exists(base_path):
		holder.add_child(_make_art_rect(load(base_path), Rect2(-_BODY.position * _art_scale(), _ART_SIZE * _art_scale())))
	else:
		var bg = Panel.new()
		bg.size = _card_size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_theme_stylebox_override("panel", PixelUI.make_bevel_card(Color(0.09, 0.10, 0.14, 1.0), rar_color))
		holder.add_child(bg)

	var font: Font = load(_DESC_FONT_PATH)
	var k = _art_scale()

	# --- Ícone ---
	var icon_r = _scaled_rect(_ICON_RECT)
	var icon_tex: Texture2D = null
	var ipath = card.icon_path if card != null else ""
	if ipath != "" and ResourceLoader.exists(ipath):
		icon_tex = load(ipath)
	if icon_tex != null:
		holder.add_child(_make_art_rect(icon_tex, icon_r))
	else:
		var q = Label.new()
		q.text = "?"
		q.position = icon_r.position
		q.size = icon_r.size
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_override("font", font)
		q.add_theme_font_size_override("font_size", int(40 * k))
		q.add_theme_color_override("font_color", rar_color)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(q)

	# --- Título (uma linha; encolhe a fonte até caber no banner) ---
	var title_r = _scaled_rect(_TITLE_RECT)
	var title_clip = Control.new()
	title_clip.position = title_r.position
	title_clip.size = title_r.size
	title_clip.clip_contents = true
	title_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(title_clip)

	var title = Label.new()
	title.text = (card.name if card != null else "").to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.add_theme_font_override("font", font)
	title.add_theme_color_override("font_color", _TITLE_INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Encolhe a fonte até caber em largura e altura do banner.
	var tsize = maxi(7, int(round(13.0 * k)))
	while tsize > 6 and font != null and (
			font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x > title_r.size.x - 3.0 * k
			or tsize * 5.0 / 7.0 > title_r.size.y - 0.6 * k):
		tsize -= 1
	title.add_theme_font_size_override("font_size", tsize)
	var th = font.get_height(tsize) if font != null else title_r.size.y
	# Centralização manual (largura medida): o alinhamento do Label saía
	# deslocado nos nomes longos.
	var tw = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x if font != null else title_r.size.x
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size = Vector2(tw, th)
	var tx: float = floor((title_r.size.x - tw) * 0.5)
	var ty: float = _caps_center_y(font, tsize, title_r.size.y)
	title.position = Vector2(tx, ty)
	# Destaque: tinta mais escura, "negrito" (cópia deslocada 1 px) e leve
	# sombra dourada embaixo.
	title.add_theme_color_override("font_color", Color(0.08, 0.05, 0.11))
	var bold = title.duplicate()
	bold.position = title.position + Vector2(maxf(1.0, round(k * 0.5)), 0)
	var shade = title.duplicate()
	shade.add_theme_color_override("font_color", Color(0.85, 0.64, 0.25, 0.9))
	shade.position = title.position + Vector2(maxf(1.0, round(k * 0.5)), maxf(1.0, round(k * 0.6)))
	title_clip.add_child(shade)
	title_clip.add_child(bold)
	title_clip.add_child(title)

	# --- Descrição (clip no pergaminho + scroll automático da base) ---
	var desc_r = _scaled_rect(_DESC_RECT)
	var clip = Control.new()
	clip.position = desc_r.position
	clip.size = desc_r.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(clip)

	var pad_h = 2.0 * k
	var pad_v = 1.0 * k
	var avail_w = desc_r.size.x - 2.0 * pad_h
	var avail_h = desc_r.size.y - 2.0 * pad_v
	var desc = Label.new()
	desc.text = card.description if card != null else ""
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.add_theme_font_override("font", font)
	desc.add_theme_font_size_override("font_size", maxi(7, int(round(_DESC_FONT_NATIVE * k))))
	desc.add_theme_color_override("font_color", _DESC_INK)
	desc.add_theme_constant_override("line_spacing", 0)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.position = Vector2(pad_h, pad_v)
	desc.size = Vector2(avail_w, avail_h)
	clip.add_child(desc)
	call_deferred("_maybe_start_description_scroll", desc, avail_w, avail_h)

	return holder

func _build_back_frame(rar_color: Color) -> Control:
	var scaled_size = Vector2(CARD_WIDTH, CARD_HEIGHT) * _display_scale

	var root = PanelContainer.new()
	root.custom_minimum_size = scaled_size
	root.size = root.custom_minimum_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_stylebox_override("panel", PixelUI.make_bevel_card(Color(0.06, 0.07, 0.10, 1.0), rar_color))

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var seal = CardSeal.new("", "res://assets/sprites/cards/icons/icon_action.png", rar_color)
	seal.custom_minimum_size = Vector2(70, 70) * _display_scale
	center.add_child(seal)

	return root

static func get_rarity_color(rar: int) -> Color:
	match rar:
		ActionCard.Rarity.COMMON:    return Color(0.72, 0.76, 0.82)
		ActionCard.Rarity.RARE:      return Color(0.25, 0.65, 1.00)
		ActionCard.Rarity.EPIC:      return Color(0.75, 0.32, 0.95)
		ActionCard.Rarity.LEGENDARY: return Color(1.00, 0.84, 0.20)
	return Color(0.72, 0.76, 0.82)

func _get_rarity_slug(rar: int) -> String:
	match rar:
		ActionCard.Rarity.COMMON:    return "common"
		ActionCard.Rarity.RARE:      return "rare"
		ActionCard.Rarity.EPIC:      return "epic"
		ActionCard.Rarity.LEGENDARY: return "legendary"
	return "common"

func play_flip_reveal(delay: float = 0.0) -> void:
	_play_flip_reveal(delay, 0.16, 0.20)
