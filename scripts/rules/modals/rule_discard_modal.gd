class_name RuleDiscardModal
extends CanvasLayer

signal rule_replaced(discarded_rule: RuleCard, new_rule: RuleCard)
signal replacement_canceled()

# Todas as medidas de layout derivam destas constantes (em vez de números
# "no olho" espalhados), pra moldura, botão e cartão nunca ficarem com
# larguras/alturas incompatíveis entre si de novo.
const MINI_VISUAL_SIZE: float = 160.0
const FRAME_PADDING: float = 8.0
const FRAME_SIZE: float = MINI_VISUAL_SIZE + FRAME_PADDING * 2.0

const CARD_OUTER_PADDING: float = 12.0  # bate com o content_margin (6px cada lado) do make_bevel_card
const CARD_VBOX_SEPARATION: float = 14.0
const REVOKE_BTN_HEIGHT: float = 46.0

const DISCARD_CARD_SIZE: Vector2 = Vector2(
	FRAME_SIZE + CARD_OUTER_PADDING,
	FRAME_SIZE + CARD_VBOX_SEPARATION + REVOKE_BTN_HEIGHT + CARD_OUTER_PADDING
)
const PREVIEW_CARD_SIZE: Vector2 = Vector2(FRAME_SIZE + CARD_OUTER_PADDING, FRAME_SIZE + CARD_OUTER_PADDING)

var panel: PanelContainer
var current_rules_grid: GridContainer
var incoming_card_container: CenterContainer
var cancel_btn: Button
var tooltip_ref: RuleCardTooltip

var pending_new_rule: RuleCard = null

func _ready() -> void:
	layer = 125
	visible = false
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.05, 0.92)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(3 * DISCARD_CARD_SIZE.x + 2 * 16 + 64, 0)
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.08, 0.06, 0.08, 0.98), Color(0.9, 0.35, 0.35), 24))
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "LIMITE DE LEIS ATINGIDO (6/6)"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "Escolha uma Lei existente para REVOGAR e abrir espaco para a nova Lei:"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 20)
	sub_lbl.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86))
	vbox.add_child(sub_lbl)

	var grid_center = CenterContainer.new()
	vbox.add_child(grid_center)

	current_rules_grid = GridContainer.new()
	current_rules_grid.columns = 3
	current_rules_grid.add_theme_constant_override("h_separation", 22)
	current_rules_grid.add_theme_constant_override("v_separation", 22)
	grid_center.add_child(current_rules_grid)

	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = Color(0.35, 0.4, 0.5, 0.8)
	vbox.add_child(div)

	var incoming_lbl = Label.new()
	incoming_lbl.text = "NOVA LEI PROPOSTA"
	incoming_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	incoming_lbl.add_theme_font_size_override("font_size", 19)
	incoming_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(incoming_lbl)

	incoming_card_container = CenterContainer.new()
	vbox.add_child(incoming_card_container)

	cancel_btn = Button.new()
	cancel_btn.text = "CANCELAR E MANTER LEIS ATUAIS"
	cancel_btn.custom_minimum_size = Vector2(380, 58)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.add_theme_font_size_override("font_size", 22)
	PixelUI.skin_button(cancel_btn, Color(0.7, 0.35, 0.4), "", "icone_voltar")
	cancel_btn.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_btn)

	tooltip_ref = RuleCardTooltip.new()
	add_child(tooltip_ref)

func prompt_replace(new_rule: RuleCard) -> void:
	pending_new_rule = new_rule
	for child in current_rules_grid.get_children():
		child.queue_free()
	for child in incoming_card_container.get_children():
		child.queue_free()

	# Mostra as 6 Leis atuais como cartões de descarte, numa grade 3x2
	if RunManager != null:
		for rule in RunManager.active_rules:
			current_rules_grid.add_child(_build_discard_card(rule))

	# Mostra a nova regra proposta abaixo
	incoming_card_container.add_child(_build_preview_card(new_rule))

	visible = true

# Miniatura da Lei com moldura própria (painel + borda na cor da categoria),
# de tamanho fixo e idêntico em todo lugar que a usa — é isso que garante
# que ela sempre alinhe certinho com o botão/cartão ao redor.
func _build_mini_visual_framed(rule: RuleCard) -> Control:
	var cat_color = RuleCard.get_category_color(rule.category if rule != null else 0)

	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(FRAME_SIZE, FRAME_SIZE)
	frame.size = frame.custom_minimum_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.03, 0.04, 0.06, 0.9), cat_color, int(FRAME_PADDING)))

	var inner = Control.new()
	inner.custom_minimum_size = Vector2(MINI_VISUAL_SIZE, MINI_VISUAL_SIZE)
	inner.size = Vector2(MINI_VISUAL_SIZE, MINI_VISUAL_SIZE)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner)

	var mini_visual = RuleCardVisual.new(rule, tooltip_ref, true)
	var s = MINI_VISUAL_SIZE / RuleCardVisual.CARD_SIZE
	mini_visual.scale = Vector2(s, s)
	inner.add_child(mini_visual)

	return frame

func _build_discard_card(rule: RuleCard) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = DISCARD_CARD_SIZE
	card.add_theme_stylebox_override("panel", PixelUI.make_bevel_card(Color(0.14, 0.10, 0.11, 0.98), Color(0.85, 0.3, 0.35)))

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	@warning_ignore("narrowing_conversion")
	vbox.add_theme_constant_override("separation", CARD_VBOX_SEPARATION)
	card.add_child(vbox)

	var visual_center = CenterContainer.new()
	visual_center.add_child(_build_mini_visual_framed(rule))
	vbox.add_child(visual_center)

	var rev_btn = Button.new()
	rev_btn.text = "REVOGAR"
	rev_btn.custom_minimum_size = Vector2(FRAME_SIZE, REVOKE_BTN_HEIGHT)
	rev_btn.add_theme_font_size_override("font_size", 18)
	PixelUI.skin_button(rev_btn, Color(1.0, 0.3, 0.35), "", "icone_descarte")
	rev_btn.pressed.connect(func(): _confirm_replacement(rule))
	vbox.add_child(rev_btn)

	return card

func _build_preview_card(rule: RuleCard) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = PREVIEW_CARD_SIZE
	card.add_theme_stylebox_override("panel", PixelUI.make_bevel_card(Color(0.10, 0.14, 0.20), Color(0.3, 0.8, 1.0)))

	var center = CenterContainer.new()
	center.add_child(_build_mini_visual_framed(rule))
	card.add_child(center)

	return card

func _confirm_replacement(discarded: RuleCard) -> void:
	if RunManager != null:
		RunManager.remove_rule(discarded.id)
		if not RunManager.add_rule(pending_new_rule):
			# Falha ao adicionar a nova Lei (ex.: incompatibilidade) — desfaz a
			# revogação para não deixar o jogador com uma Lei a menos à toa.
			RunManager.add_rule(discarded)
			visible = false
			tooltip_ref.hide_tooltip()
			replacement_canceled.emit()
			return

	visible = false
	tooltip_ref.hide_tooltip()
	rule_replaced.emit(discarded, pending_new_rule)

func _on_cancel_pressed() -> void:
	visible = false
	tooltip_ref.hide_tooltip()
	replacement_canceled.emit()
