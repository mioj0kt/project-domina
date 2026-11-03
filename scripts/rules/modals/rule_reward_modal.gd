class_name RuleRewardModal
extends CanvasLayer

signal reward_completed()

# RuleCardVisual.CARD_SIZE cresceu bastante (320); aqui aparecem 3 opções
# lado a lado, então em tamanho cheio ficam gigantes. Essa escala traz de
# volta um tamanho de exibição razoável só pro modal de recompensa.
const REWARD_SCALE: float = 0.8
# Sem nenhuma Lei nova para sortear (jogador já tem todas as desbloqueadas):
# a recompensa vira ouro, em vez de um sorteio vazio.
const NO_LAW_GOLD: int = 40
const SUBTITLE_DRAFT: String = "Escolha 1 nova Lei Permanente para o seu Grimório (Passe o mouse para ler)"
const SUBTITLE_NO_LAW: String = "Você já tem todas as Leis que conhece! Desbloqueie mais no Grimório. Em troca, receba ouro."

var container: HBoxContainer
var tooltip: RuleCardTooltip
var root_ctrl: Control
var discard_modal: RuleDiscardModal
var _subtitle_label: Label
var _skip_btn: Button

func _init() -> void:
	layer = 120
	visible = false
	_build_ui()

func _build_ui() -> void:
	root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_ctrl)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.08, 0.90)
	root_ctrl.add_child(bg)

	tooltip = RuleCardTooltip.new()
	add_child(tooltip)

	var center_vbox = VBoxContainer.new()
	center_vbox.set_anchors_preset(Control.PRESET_CENTER)
	center_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 32)
	root_ctrl.add_child(center_vbox)

	var header_vbox = VBoxContainer.new()
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_theme_constant_override("separation", 6)
	center_vbox.add_child(header_vbox)

	var title = Label.new()
	title.text = "VITÓRIA NO DUELO DIFÍCIL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title.add_theme_constant_override("outline_size", 10)
	header_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = SUBTITLE_DRAFT
	_subtitle_label = subtitle
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	header_vbox.add_child(subtitle)

	container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 36)
	center_vbox.add_child(container)

	var skip_btn = Button.new()
	skip_btn.text = "IGNORAR LEI"
	skip_btn.custom_minimum_size = Vector2(260, 52)
	skip_btn.add_theme_font_size_override("font_size", 20)
	PixelUI.skin_button(skip_btn, Color(0.35, 0.4, 0.5), "", "icone_fechar")
	skip_btn.pressed.connect(func():
		visible = false
		reward_completed.emit()
	)
	center_vbox.add_child(skip_btn)
	_skip_btn = skip_btn

	# Limite de Leis atingido (ou incompatibilidade): o jogador escolhe qual
	# Lei revogar. Cancelar volta pro draft, sem perder a escolha.
	discard_modal = RuleDiscardModal.new()
	discard_modal.rule_replaced.connect(func(_old: RuleCard, _new: RuleCard):
		visible = false
		reward_completed.emit()
	)
	add_child(discard_modal)

func open_reward_draft() -> void:
	for child in container.get_children():
		child.queue_free()

	var owned_ids: Array[String] = []
	if RunManager != null:
		for r in RunManager.active_rules:
			owned_ids.append(r.id)

	var selected_rules = LootTables.get_random_rules(3, owned_ids)

	visible = true
	_subtitle_label.text = SUBTITLE_DRAFT if not selected_rules.is_empty() else SUBTITLE_NO_LAW
	_skip_btn.visible = not selected_rules.is_empty()

	if selected_rules.is_empty():
		var gold_btn = Button.new()
		gold_btn.text = "RECEBER %d OURO" % NO_LAW_GOLD
		gold_btn.custom_minimum_size = Vector2(340, 60)
		gold_btn.add_theme_font_size_override("font_size", 24)
		PixelUI.skin_button(gold_btn, Color(0.85, 0.64, 0.25), "", "icone_confirmar")
		gold_btn.pressed.connect(func():
			if RunManager != null:
				RunManager.add_gold(NO_LAW_GOLD)
			visible = false
			reward_completed.emit()
		)
		container.add_child(gold_btn)
		return

	for i in range(selected_rules.size()):
		var rule = selected_rules[i]
		var wrapper = VBoxContainer.new()
		wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
		wrapper.add_theme_constant_override("separation", 14)
		container.add_child(wrapper)

		var card_visual = RuleCardVisual.new(rule, tooltip, false, REWARD_SCALE)
		wrapper.add_child(card_visual)

		var pick_btn = Button.new()
		pick_btn.text = "RATIFICAR"
		pick_btn.custom_minimum_size = Vector2(RuleCardVisual.CARD_SIZE * REWARD_SCALE, 44)
		pick_btn.add_theme_font_size_override("font_size", 18)
		PixelUI.skin_button(pick_btn, Color(0.3, 0.9, 0.4), "", "icone_confirmar")
		pick_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		pick_btn.pressed.connect(func():
			if RunManager == null or RunManager.add_rule(rule):
				visible = false
				reward_completed.emit()
			else:
				discard_modal.prompt_replace(rule)
		)
		wrapper.add_child(pick_btn)

		card_visual.play_flip_reveal(0.12 + (i * 0.14))
