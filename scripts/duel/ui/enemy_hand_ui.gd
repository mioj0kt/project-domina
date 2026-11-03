class_name EnemyHandUI
extends CanvasLayer

# Mão do inimigo — reflete a quantidade real de cartas na mão da IA
# (ai_deck_mgr, ver duel_turn_controller.gd), usando o mesmo verso real
# (sprite se existir, senão o mesmo fallback procedural) que a mão do
# jogador usa. O conteúdo de cada carta não é revelado (mostradas de
# costas), só a raridade pela cor da borda. Ancorada no TOPO da tela,
# espelhando a mão do jogador (CardHandUI), que fica embaixo.

const CARD_SCALE: float = 0.5
const TOP_MARGIN: float = 6.0
# Altura (a partir do topo da tela) ocupada pela mão — o tabuleiro começa abaixo.
const RESERVED_HEIGHT: float = TOP_MARGIN + ActionCardVisual.CARD_HEIGHT * CARD_SCALE + 6.0

var cards_hbox: HBoxContainer
var _hand_ref: Array[ActionCard] = []

func _init() -> void:
	layer = 85
	_build_ui()

func _build_ui() -> void:
	var root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	cards_hbox = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", -40)
	cards_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cards_hbox.anchor_top = 0.0
	cards_hbox.anchor_bottom = 0.0
	cards_hbox.anchor_left = 0.0
	cards_hbox.anchor_right = 1.0
	cards_hbox.offset_top = TOP_MARGIN
	cards_hbox.offset_bottom = TOP_MARGIN + (ActionCardVisual.CARD_HEIGHT * CARD_SCALE)
	root_ctrl.add_child(cards_hbox)

# hand: a mão real da IA (ai_deck_mgr.hand) — só usamos pra saber a
# raridade de cada uma (verso real), nunca mostramos a frente.
func refresh(hand: Array[ActionCard]) -> void:
	_hand_ref = hand

	for child in cards_hbox.get_children():
		child.queue_free()

	for card in hand:
		var visual = ActionCardVisual.new(card, false)
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(ActionCardVisual.CARD_WIDTH, ActionCardVisual.CARD_HEIGHT) * CARD_SCALE
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.scale = Vector2(CARD_SCALE, CARD_SCALE)
		wrapper.add_child(visual)
		cards_hbox.add_child(wrapper)
