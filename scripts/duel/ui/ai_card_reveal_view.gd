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
	# Abaixo do menu de pausa/configurações (180): com o jogo pausado a animação
	# congela, e a carta não pode ficar por cima do menu bloqueando os cliques.
	layer = 170
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

# Roubo: a carta sai VIRADA da mão de quem foi roubado, um fio de sombra a puxa
# até o centro, ela vira de frente (revelando o que foi levado) e voa para a mão
# de quem roubou. by_player = o jogador roubou (carta vai de cima para baixo).
func show_steal(card: ActionCard, from_pos: Vector2, to_pos: Vector2, by_player: bool) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	for child in root_ctrl.get_children():
		child.queue_free()
	is_showing = true
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_half = Vector2(ActionCardVisual.CARD_WIDTH, ActionCardVisual.CARD_HEIGHT) / 2.0
	var vc = get_viewport().get_visible_rect().size / 2.0

	var hook := _StealHook.new()
	hook.from = from_pos
	hook.to = from_pos
	root_ctrl.add_child(hook)

	var visual = ActionCardVisual.new(card, false)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.pivot_offset = card_half
	visual.global_position = from_pos - card_half * SMALL_SCALE
	visual.scale = Vector2(SMALL_SCALE, SMALL_SCALE)
	visual.modulate.a = 0.0
	root_ctrl.add_child(visual)

	var label = Label.new()
	label.text = "VOCÊ ROUBOU UMA CARTA!" if by_player else "O INIMIGO ROUBOU SUA CARTA!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.75, 0.6, 1.0) if by_player else Color(1.0, 0.45, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	label.add_theme_constant_override("outline_size", 8)
	label.modulate.a = 0.0
	label.custom_minimum_size = Vector2(700, 40)
	label.position = Vector2(vc.x - 350.0, vc.y - card_half.y - 60.0)
	root_ctrl.add_child(label)

	Sfx.play("carta_pegar")
	active_tween = create_tween()
	# 1. o fio de sombra estica do lado de quem rouba até a carta
	hook.from = to_pos
	active_tween.tween_property(hook, "to", from_pos, 0.0)
	active_tween.tween_property(hook, "reach", 1.0, 0.35).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(visual, "modulate:a", 1.0, 0.2)
	# 2. tranco: a carta treme presa no gancho
	for i in range(3):
		active_tween.tween_property(visual, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.06)
	active_tween.tween_property(visual, "rotation", 0.0, 0.06)
	# 3. puxada até o centro (o gancho acompanha a carta)
	active_tween.tween_property(label, "modulate:a", 1.0, 0.15)
	active_tween.parallel().tween_property(visual, "global_position", vc - card_half, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(visual, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.parallel().tween_property(hook, "to", vc, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 4. vira de frente: dá pra ver o que foi roubado
	active_tween.tween_callback(func(): visual.play_flip_reveal(0.0))
	active_tween.parallel().tween_property(hook, "reach", 0.0, 0.25)
	active_tween.tween_interval(HOLD_SECONDS)
	# 5. vai para a mão de quem roubou
	active_tween.tween_property(label, "modulate:a", 0.0, 0.2)
	active_tween.parallel().tween_property(visual, "global_position", to_pos - card_half * SMALL_SCALE, FLY_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(visual, "scale", Vector2(SMALL_SCALE, SMALL_SCALE), FLY_OUT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.tween_property(visual, "modulate:a", 0.0, 0.15)
	active_tween.tween_callback(_finish_sequence)

# Fio de sombra com gancho (Roubo): sai de `from`, vai até `from.lerp(to, reach)`.
class _StealHook extends Control:
	var from: Vector2 = Vector2.ZERO:
		set(v):
			from = v
			queue_redraw()
	var to: Vector2 = Vector2.ZERO:
		set(v):
			to = v
			queue_redraw()
	var reach: float = 0.0:
		set(v):
			reach = v
			queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if reach <= 0.01:
			return
		var end: Vector2 = from.lerp(to, reach)
		var d: Vector2 = end - from
		var n: int = maxi(2, int(d.length() / 9.0))
		var side := Vector2(-d.y, d.x).normalized()
		var t: float = Time.get_ticks_msec() / 1000.0
		for i in range(n + 1):
			var f: float = float(i) / float(n)
			var p: Vector2 = from + d * f + side * sin(f * 9.0 + t * 8.0) * 7.0 * (1.0 - f)
			var sz: float = 6.0 if i % 2 == 0 else 4.0
			draw_rect(Rect2((p - Vector2(sz, sz) / 2.0).round(), Vector2(sz, sz)), Color(0.36, 0.26, 0.46, 0.9))
			if i % 3 == 0:
				draw_rect(Rect2((p + side * 6.0).round(), Vector2(3, 3)), Color(0.6, 0.45, 0.8, 0.6))
		# gancho na ponta
		var dirn: Vector2 = d.normalized()
		var hook_pts := [end, end + dirn * 10.0, end + dirn * 14.0 + side * 6.0, end + dirn * 10.0 + side * 12.0, end + side * 12.0]
		for q in hook_pts:
			draw_rect(Rect2((q - Vector2(4, 4)).round(), Vector2(8, 8)), Color(0.2, 0.14, 0.26))
			draw_rect(Rect2((q - Vector2(2, 2)).round(), Vector2(4, 4)), Color(0.72, 0.58, 0.95))

# Pausou (ESC no meio da animação): esconde a carta e solta o mouse até despausar.
func _notification(what: int) -> void:
	if root_ctrl == null:
		return
	if what == NOTIFICATION_PAUSED:
		root_ctrl.visible = false
	elif what == NOTIFICATION_UNPAUSED:
		root_ctrl.visible = true

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
