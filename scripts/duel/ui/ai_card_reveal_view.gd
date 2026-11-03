class_name AICardRevealView
extends CanvasLayer

# Mostra a carta que a IA acabou de jogar com uma animação de verdade: ela
# "sai" da mão inimiga (topo da tela), cresce e vai pro centro (onde dá pra
# ler com calma), e depois encolhe e "pousa" na pilha de descarte da IA —
# em vez de só um texto aparecendo e sumindo. Clicar em qualquer lugar
# durante a animação ACELERA bastante o resto dela, em vez de esperar o
# tempo normal (mas sem cortar de vez — ainda dá pra ver a carta chegando
# na pilha de descarte, só que rápido).

const HOLD_SECONDS: float = 2.0
const FLY_IN_SECONDS: float = 0.45
const FLY_OUT_SECONDS: float = 0.45
const SMALL_SCALE: float = 0.55

var root_ctrl: Control
var active_tween: Tween
var is_showing: bool = false

# Emitido quando a sequência termina — seja naturalmente ou por ter sido
# Emitido quando a sequência termina — seja no tempo normal ou mais rápido
# por ter sido acelerada com um clique. Quem chama show_card() deve
# esperar por esse sinal em vez de um tempo fixo, senão acelerar no
# clique não adiantaria nada (o resto do turno continuaria esperando a
# duração completa de qualquer jeito).
signal sequence_finished

func _init() -> void:
	layer = 200
	root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.gui_input.connect(_on_gui_input)
	add_child(root_ctrl)

# from_pos: de onde a carta "sai" (posição aproximada da mão inimiga).
# to_pos: pra onde ela "pousa" no final (pilha de descarte da IA).
func show_card(card: ActionCard, from_pos: Vector2, to_pos: Vector2) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	for child in root_ctrl.get_children():
		child.queue_free()

	is_showing = true
	# STOP enquanto mostra — não pra bloquear o clique, mas pra GARANTIR
	# que o clique seja capturado aqui (e trate como "acelerar"), em vez de
	# vazar pro tabuleiro por baixo e mexer em outra coisa sem querer.
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_half = Vector2(ActionCardVisual.CARD_WIDTH, ActionCardVisual.CARD_HEIGHT) / 2.0
	var viewport_center = get_viewport().get_visible_rect().size / 2.0

	var visual = ActionCardVisual.new(card, true)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.pivot_offset = card_half
	visual.global_position = from_pos - card_half * SMALL_SCALE
	visual.scale = Vector2(SMALL_SCALE, SMALL_SCALE)
	visual.modulate.a = 0.0
	root_ctrl.add_child(visual)

	var label = Label.new()
	label.text = "O INIMIGO JOGOU UMA CARTA"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	label.add_theme_constant_override("outline_size", 8)
	label.modulate.a = 0.0
	label.custom_minimum_size = Vector2(600, 40)
	label.position = Vector2(viewport_center.x - 300.0, viewport_center.y - card_half.y - 60.0)
	root_ctrl.add_child(label)

	active_tween = create_tween()

	# 1. Sai da mão inimiga, cresce e voa pro centro da tela
	active_tween.tween_property(visual, "modulate:a", 1.0, 0.15)
	active_tween.parallel().tween_property(label, "modulate:a", 1.0, 0.15)
	active_tween.parallel().tween_property(visual, "global_position", viewport_center - card_half, FLY_IN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(visual, "scale", Vector2.ONE, FLY_IN_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Fica parada no centro tempo suficiente pra ler
	active_tween.tween_interval(HOLD_SECONDS)

	# 3. Encolhe e voa pra pilha de descarte da IA
	active_tween.tween_property(label, "modulate:a", 0.0, 0.2)
	active_tween.parallel().tween_property(visual, "global_position", to_pos - card_half * SMALL_SCALE, FLY_OUT_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(visual, "scale", Vector2(SMALL_SCALE, SMALL_SCALE), FLY_OUT_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.tween_property(visual, "modulate:a", 0.0, 0.15)

	active_tween.tween_callback(_finish_sequence)

func _on_gui_input(event: InputEvent) -> void:
	if not is_showing:
		return
	if event is InputEventMouseButton and event.pressed:
		skip()
		get_viewport().set_input_as_handled()

# Acelera bastante a animação em andamento (em vez de matar e pular
# direto pro final) — assim ainda dá pra ver a carta voando até a pilha de
# descarte, só que rápido, em vez de perder essa parte por completo.
func skip() -> void:
	if not is_showing:
		return
	if active_tween and active_tween.is_valid():
		active_tween.set_speed_scale(7.0)

func _finish_sequence() -> void:
	for child in root_ctrl.get_children():
		child.queue_free()
	is_showing = false
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sequence_finished.emit()
