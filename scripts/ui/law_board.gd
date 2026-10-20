class_name LawBoard
extends Control

# Quadro de Leis (2 colunas x 3 linhas) usado pela HUD do jogador e pela do
# inimigo. Desenha o sprite law_board.png (386x543, com 8 px transparentes
# ao redor — o controle ocupa só o CORPO de 370x527) e expõe 6 slots
# quadrados posicionados nas 6 células do quadro.

const TEXTURE_PATH := "res://assets/sprites/ui/law_board.png"
const _ART_SIZE := Vector2(386, 543)
const _BODY := Rect2(0, 0, 386, 543)
const _SLOT_ART_SIZE: float = 160.0
# Cantos superiores esquerdos dos 6 slots (px da arte), em ordem de leitura —
# centralizados nos 6 encaixes do sprite (157x157 em x=22/208, y=19/193/367).
const _SLOT_ORIGINS: Array[Vector2] = [
	Vector2(20.5, 17.5), Vector2(206.5, 17.5),
	Vector2(20.5, 191.5), Vector2(206.5, 191.5),
	Vector2(20.5, 365.5), Vector2(206.5, 365.5),
]

var slots: Array[Control] = []
var slot_size: float = 0.0

# board_height = altura final do corpo do quadro em px; a largura sai da
# proporção do sprite. tint permite diferenciar o quadro do inimigo.
func _init(board_height: float, tint: Color = Color.WHITE) -> void:
	var k = board_height / _BODY.size.y
	custom_minimum_size = _BODY.size * k
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_size = _SLOT_ART_SIZE * k

	if ResourceLoader.exists(TEXTURE_PATH):
		var bg = TextureRect.new()
		# expand_mode ANTES do size: senão o TextureRect trava no tamanho nativo
		# da textura e o quadro não consegue ficar MENOR que a arte (k < 1),
		# desalinhando os slots em relação ao desenho.
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.texture = load(TEXTURE_PATH)
		bg.position = -_BODY.position * k
		bg.size = _ART_SIZE * k
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.modulate = tint
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	else:
		var bg = Panel.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.add_theme_stylebox_override("panel", PixelUI.make_wood_panel())
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	for origin in _SLOT_ORIGINS:
		var slot = Control.new()
		slot.position = (origin - _BODY.position) * k
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		slot.size = Vector2(slot_size, slot_size)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(slot)
		slots.append(slot)

# Game juice: o slot da Lei que acabou de agir treme, pulsa e solta um anel
# de brilho na cor da categoria da Lei.
func flash_slot(index: int, color: Color = Color(1.0, 0.85, 0.3)) -> void:
	if index < 0 or index >= slots.size():
		return
	var slot: Control = slots[index]
	if not is_instance_valid(slot) or not slot.is_inside_tree():
		return
	for key in ["fx_tween", "fx_shake"]:
		var old: Tween = slot.get_meta(key) if slot.has_meta(key) else null
		if old != null and old.is_valid():
			old.kill()
	var old_ring = slot.get_node_or_null("FxRing")
	if old_ring != null:
		old_ring.queue_free()

	var base_pos: Vector2 = slot.get_meta("fx_base_pos") if slot.has_meta("fx_base_pos") else slot.position
	slot.set_meta("fx_base_pos", base_pos)
	slot.position = base_pos
	slot.pivot_offset = slot.size / 2.0
	slot.z_index = 20

	# Anel de brilho (borda que cresce e some).
	var ring := Panel.new()
	ring.name = "FxRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.28)
	sb.border_color = color
	sb.set_border_width_all(4)
	ring.add_theme_stylebox_override("panel", sb)
	slot.add_child(ring)
	ring.pivot_offset = slot.size / 2.0

	var tw := slot.create_tween()
	slot.set_meta("fx_tween", tw)
	tw.set_parallel(true)
	# Fase 1: estoura (escala sobe e a carta clareia).
	tw.tween_property(slot, "scale", Vector2(1.14, 1.14), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot, "modulate", Color(1.7, 1.6, 1.3), 0.09)
	# Fase 2: assenta e o anel de brilho se expande e some.
	tw.chain().tween_property(slot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(slot, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ring, "scale", Vector2(1.3, 1.3), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD)
	# Tremor (some se os efeitos de tela fortes estiverem desligados).
	if Juice.screen_fx:
		var sh := slot.create_tween()
		slot.set_meta("fx_shake", sh)
		var amp: float = maxf(2.0, slot_size * 0.035)
		for i in range(6):
			var dir: float = -1.0 if i % 2 == 0 else 1.0
			sh.tween_property(slot, "position", base_pos + Vector2(dir * amp * (1.0 - i / 7.0), 0.0), 0.03)
		sh.tween_property(slot, "position", base_pos, 0.03)
	tw.chain().tween_callback(func():
		if is_instance_valid(slot):
			slot.z_index = 0
			slot.position = base_pos
		if is_instance_valid(ring):
			ring.queue_free())
