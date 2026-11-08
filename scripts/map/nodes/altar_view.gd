class_name AltarView
extends Control

# Nó "Altar de Leis" do mapa: o altar mostra 3 Leis ainda desconhecidas e o
# jogador ratifica UMA (grátis) ou segue viagem sem nada. Sem menu: ao entrar
# as 3 Leis já estão na mesa.
# Mesmo esqueleto visual do EventView/BetView: fundo de bioma, HUD lateral,
# inventário, tooltips, e o modal de revogar quando as Leis estão lotadas.

const MAP_SCENE_PATH: String = "res://scenes/map_view.tscn"
const OFFER_COUNT: int = 3
const OFFER_SCALE: float = 1.0
const CHOICE_W: float = 450.0
# Área do corpo (3 Leis lado a lado, depois a Lei ganha).
const BODY_SIZE: Vector2 = Vector2(1366, 405)
const MAX_TEXT_H: float = 190.0
const MIN_TEXT_FONT: int = 22

const C_GOLD := Color("#d9a441")
const C_CREAM := Color("#efe6cf")

enum Stage { OFFERS, DONE }

var hud_bar: HUDBar
var inventory_ui: InventoryUI
var rule_tooltip: RuleCardTooltip
var discard_modal: RuleDiscardModal

var title_label: Label
var text_label: Label
var body: Control            # área que muda a cada etapa
var leave_btn: Button

var stage: int = Stage.OFFERS
var used: bool = false

func _ready() -> void:
	_setup_ui()
	_show_offers()

# ==========================================
# UI base
# ==========================================
func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "AltarUILayer"
	canvas.layer = 70
	add_child(canvas)

	add_child(BiomeBackground.new())

	hud_bar = HUDBar.new()
	canvas.add_child(hud_bar)
	hud_bar.open_laws_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.LAWS))
	hud_bar.open_cards_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.CARDS))

	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.setup()

	discard_modal = RuleDiscardModal.new()
	discard_modal.rule_replaced.connect(_on_offer_replaced)
	discard_modal.replacement_canceled.connect(func(): _set_text("Você recusou a Lei oferecida. Escolha outra ou siga viagem."))
	add_child(discard_modal)

	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 470)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.1, 0.14, 0.97), Color(0.55, 0.4, 0.8), 18))
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(BODY_SIZE.x, 0)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	title_label = Label.new()
	title_label.text = "ALTAR DAS LEIS"
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_label.add_theme_constant_override("outline_size", 8)
	head.add_child(title_label)

	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.custom_minimum_size = Vector2(BODY_SIZE.x - 40, 0)
	text_label.add_theme_font_size_override("font_size", 40)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(text_label)

	# Corpo: as 3 Leis (depois, a Lei ratificada).
	body = VBoxContainer.new()
	body.custom_minimum_size = Vector2(BODY_SIZE.x, BODY_SIZE.y)
	box.add_child(body)

	leave_btn = Button.new()
	leave_btn.text = "DEIXAR O ALTAR"
	leave_btn.custom_minimum_size = Vector2(CHOICE_W, 72)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.add_theme_font_size_override("font_size", 32)
	PixelUI.skin_button(leave_btn, Color(0.4, 0.7, 0.9), "", "icone_mapa")
	leave_btn.pressed.connect(func(): SceneTransition.go(MAP_SCENE_PATH))
	box.add_child(leave_btn)

# Texto com quebra manual + fonte que encolhe se for longo (mesma regra do EventView).
func _set_text(text: String) -> void:
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var width := text_label.custom_minimum_size.x
	var font: Font = text_label.get_theme_font("font")
	var font_size := 40
	var wrapped := _wrap(font, text, width, font_size)
	while font_size > MIN_TEXT_FONT and font.get_multiline_string_size(wrapped, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).y > MAX_TEXT_H:
		font_size -= 2
		wrapped = _wrap(font, text, width, font_size)
	text_label.add_theme_font_size_override("font_size", font_size)
	text_label.text = wrapped

func _wrap(font: Font, text: String, width: float, font_size: int) -> String:
	var out: Array[String] = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)

func _clear_body() -> void:
	for c in body.get_children():
		c.queue_free()

func _small_button(text: String, accent: Color, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 56)
	b.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(b, accent)
	return b

# ==========================================
# Etapas
# ==========================================
# Leis que o altar pode oferecer: liberadas na meta e que o jogador ainda não tem.
func _offer_pool() -> Array[RuleCard]:
	var owned: Array[String] = []
	for r in RunManager.active_rules:
		owned.append(r.id)
	var pool: Array[RuleCard] = []
	for r in LootTables.get_player_rules():
		if not owned.has(r.id):
			pool.append(r)
	return pool

# Etapa única: 3 Leis na mesa, o jogador escolhe uma (ou deixa o altar).
func _show_offers() -> void:
	stage = Stage.OFFERS
	_clear_body()
	var offers: Array[RuleCard] = LootTables.pick_weighted_rules(_offer_pool(), OFFER_COUNT)
	if offers.is_empty():
		_set_text("O altar não tem nenhuma Lei nova para oferecer. Você já conhece todas.")
		return
	_set_text("Escolha uma Lei para ratificar.")
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)
	for i in range(offers.size()):
		var rule: RuleCard = offers[i]
		var holder := VBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.add_theme_constant_override("separation", 10)
		var vis := RuleCardVisual.new(rule, rule_tooltip, false, OFFER_SCALE)
		holder.add_child(vis)
		var pick := _small_button("RATIFICAR", Color(0.3, 0.9, 0.4), RuleCardVisual.CARD_SIZE * OFFER_SCALE)
		pick.pressed.connect(_on_offer_picked.bind(rule))
		holder.add_child(pick)
		row.add_child(holder)
		vis.play_flip_reveal(0.12 + i * 0.14)

func _on_offer_picked(rule: RuleCard) -> void:
	if RunManager.add_rule(rule):
		_finish("O altar ratifica a Lei:", rule)
	else:
		# Leis lotadas: o jogador escolhe qual revogar.
		discard_modal.prompt_replace(rule)

func _on_offer_replaced(_old: RuleCard, new_rule: RuleCard) -> void:
	_finish("A Lei antiga é revogada. O altar ratifica:", new_rule)

# Etapa final: mostra a Lei ganha e libera a saída (uma ação por visita).
func _finish(message: String, rule: RuleCard) -> void:
	stage = Stage.DONE
	used = true
	_clear_body()
	_set_text(message)
	leave_btn.text = "SEGUIR VIAGEM"
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var vis := RuleCardVisual.new(rule, rule_tooltip, false, OFFER_SCALE)
	center.add_child(vis)
	vis.play_flip_reveal(0.1)
	# Juice: fagulhas e pulso quando a Lei é ratificada (depois do flip).
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(vis) and vis.is_inside_tree():
		Juice.sparkle(self, vis.global_position + vis.size * 0.5, 28)
		Juice.pulse(vis, 1.08, 0.3)
