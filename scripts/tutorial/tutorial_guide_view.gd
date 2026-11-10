class_name TutorialGuideView
extends CanvasLayer

# O Guia: caixa de diálogo com texto "digitado", holofote que escurece a tela e
# aponta uma parte da interface, quadro de OBJETIVO, dicas pontuais e cartão
# de título de lição. Usado pelo duelo, pela loja, pela aposta e pelo mapa do
# tutorial.
#
# Cada cena que toca falas com "spot" define `spot_resolver`: uma Callable
# (id: String) -> Rect2 que devolve o retângulo (coordenadas de viewport) da
# parte da interface com aquele id. Rect2() vazio = id desconhecido.

signal sequence_finished()

const TYPE_SPEED: float = 95.0          # caracteres por segundo
const DIM_DIALOGUE: float = 0.62        # escurecimento durante a fala
const DIM_OBJECTIVE: float = 0.38       # escurecimento enquanto o objetivo está ativo
# Folga entre a caixa de diálogo e o pé da tela (antes ficava colada embaixo).
const DIALOGUE_BOTTOM_MARGIN: int = 110
# Cores tiradas dos retratos: o Guia é carmesim suave (#943236/#b44a44); o Irmão
# tem o mesmo corpo, mas olhos em brasa (#ff3a2a), então a caixa dele é mais
# escura e incandescente.
const GUIDE_TINT: Color = Color(1.0, 0.66, 0.62)
const EVIL_TINT: Color = Color(1.0, 0.36, 0.28)

static func _char_panel(tint: Color, padding: int) -> StyleBox:
	var st: StyleBox = PixelUI.make_pixel_panel(PixelUI.FUNDO_QUADRO, Color.WHITE, padding)
	if st is StyleBoxTexture:
		(st as StyleBoxTexture).modulate_color = tint
	return st
const IDLE_HINT_SECONDS: float = 12.0   # parado sem cumprir o objetivo -> dica extra

var spot_resolver: Callable = Callable()

var dialogue_panel: PanelContainer
var _dock_vbox: VBoxContainer
var portrait: GuideFaceControl
var name_label: Label
var text_label: Label
var continue_btn: Button
var skip_btn: Button
var lines: Array = []
var current_line_index: int = -1
var is_showing_sequence: bool = false
var _typing: bool = false
var _type_pos: float = 0.0
var _talk_phase: float = 0.0
var _flipping: bool = false
var _speaker: String = "guide"

# --- Efeitos dramáticos (a virada do Guia): ver _draw_fx / _run_flip_line ---
var _fx: Control
var _fx_top: Control   # acima da caixa de diálogo: rosto gigante, onda de choque, clarão
var _evil_amt: float = 0.0        # intensidade ambiente vermelha (0..1)
var _flash: float = 0.0           # clarão branco (relâmpago/virada)
var _shake: float = 0.0           # tremor da tela (px), decai sozinho
var _line_shake: float = 0.0      # tremor contínuo enquanto a fala é digitada
var _ring_t: float = -1.0         # onda de choque (0..1), -1 = inativa
var _embers: Array = []
var _vignette_tex: GradientTexture2D = null
var _guide_style: StyleBox = null
# Rosto gigante da virada (desenhado na camada de efeitos, não no retrato).
var _crown_t: float = -1.0        # tempo da "coroação" do Guia (0..1); a coroa NÃO é mais desenhada, só o clarão/tremor; -1 = inativo
var _big_on: bool = false
var _big_pos: Vector2 = Vector2.ZERO
var _big_size: float = 150.0
var _big_flip_x: float = 1.0      # achatamento horizontal (moeda girando)
var _big_toss: float = 1.0        # escala da moeda no ar (sobe e desce)
var _big_who: String = "guide"

const SPEAKER_NAMES := {"guide": "O GUIA", "evil": "O IRMÃO"}
const SPEAKER_COLORS := {"guide": Color("#e8857a"), "evil": Color("#ff4a36")}

var tip_panel: PanelContainer
var tip_label: Label
var _tip_gen: int = 0

var objective_panel: PanelContainer
var objective_title: Label
var objective_label: Label
var objective_check: Label
var objective_pips: HBoxContainer

# Holofote
var _overlay: Control
var _blocker: Control
var _line_spot_id: String = ""
var _line_spot_caption: String = ""
var _obj_spot_id: String = ""
var _obj_spot_caption: String = ""
var _obj_spot_dim: float = DIM_OBJECTIVE
var _obj_idle_tip: String = ""
var _obj_idle_spot: String = ""
var _obj_idle_t: float = 0.0
var _pulse_rect: Rect2 = Rect2()
var _pulse_until: float = 0.0
var _pulse_spot_id: String = ""   # se definido, a moldura segue o trecho (cresce junto)
var _t: float = 0.0

var _title_card: PanelContainer = null

func _ready() -> void:
	layer = 130
	_build_ui()
	# A caixa de diálogo é o último filho: desenha por cima do quadro de
	# objetivo, da dica e dos efeitos (ordem de filhos = ordem de desenho).
	move_child(_dock_vbox.get_parent(), -1)
	TutorialManager.objective_changed.connect(_on_objective_changed)
	TutorialManager.objective_started.connect(_on_objective_started)
	TutorialManager.objective_done.connect(_on_objective_done)

func _build_ui() -> void:
	# --- Holofote (por baixo de tudo do Guia, não bloqueia input) ---
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	# Bloqueio de cliques: enquanto o Guia fala (ou o cartão de lição aparece) o
	# jogador não pode mexer na cena por baixo (botões da Loja/Apostas, sair da
	# cena...). Fica abaixo da caixa de diálogo, que continua clicável.
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = false
	add_child(_blocker)

	# Camada de efeitos (vinheta vermelha, brasas, clarões): acima do holofote,
	# abaixo da caixa de diálogo.
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)

	# --- Caixa de diálogo principal (sequência de falas, bloqueia até
	# o jogador clicar "continuar") ---
	dialogue_panel = PanelContainer.new()
	dialogue_panel.add_theme_stylebox_override("panel", _char_panel(GUIDE_TINT, 22))
	dialogue_panel.visible = false
	dialogue_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Moldura que encaixa a caixa no alto ou no pé da tela (ver _dock_dialogue).
	var dock_margin = MarginContainer.new()
	dock_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_margin.add_theme_constant_override("margin_top", 30)
	dock_margin.add_theme_constant_override("margin_bottom", DIALOGUE_BOTTOM_MARGIN)
	add_child(dock_margin)

	_fx_top = Control.new()
	_fx_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_top.draw.connect(_draw_fx_top)
	add_child(_fx_top)
	_dock_vbox = VBoxContainer.new()
	_dock_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock_margin.add_child(_dock_vbox)
	_dock_vbox.add_child(dialogue_panel)
	_dock_dialogue(false)
	_guide_style = dialogue_panel.get_theme_stylebox("panel")

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	dialogue_panel.add_child(hbox)

	portrait = GuideFaceControl.new()
	portrait.setup(136.0)
	hbox.add_child(portrait)

	var text_vbox = VBoxContainer.new()
	text_vbox.custom_minimum_size = Vector2(1180, 0)
	text_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(text_vbox)

	name_label = Label.new()
	name_label.text = "O GUIA"
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color("#e8857a"))
	text_vbox.add_child(name_label)

	text_label = Label.new()
	text_label.text = ""
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.custom_minimum_size = Vector2(1180, 112)
	text_label.add_theme_font_size_override("font_size", 36)
	text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	text_vbox.add_child(text_label)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	text_vbox.add_child(btn_row)

	continue_btn = Button.new()
	continue_btn.text = "CONTINUAR"
	continue_btn.custom_minimum_size = Vector2(260, 56)
	continue_btn.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(continue_btn, Color(0.4, 0.85, 0.45), "", "icone_confirmar")
	continue_btn.pressed.connect(_on_continue_pressed)
	btn_row.add_child(continue_btn)

	skip_btn = Button.new()
	skip_btn.text = "PULAR"
	skip_btn.custom_minimum_size = Vector2(190, 56)
	skip_btn.add_theme_font_size_override("font_size", 26)
	PixelUI.skin_button(skip_btn, Color(0.6, 0.6, 0.65))
	skip_btn.pressed.connect(_on_skip_pressed)
	btn_row.add_child(skip_btn)

	# --- Dica pontual (menor, some sozinha, não bloqueia input) ---
	tip_panel = PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel", _char_panel(GUIDE_TINT, 14))
	tip_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tip_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tip_panel.offset_top = 24.0
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.visible = false
	add_child(tip_panel)

	var tip_hbox = HBoxContainer.new()
	tip_hbox.add_theme_constant_override("separation", 14)
	tip_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_child(tip_hbox)

	var tip_portrait = GuideFaceControl.new()
	tip_portrait.setup(72.0)
	tip_hbox.add_child(tip_portrait)

	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.custom_minimum_size = Vector2(900, 0)
	tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_size_override("font_size", 30)
	tip_label.add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))
	tip_hbox.add_child(tip_label)

	# --- Quadro de objetivo (não bloqueia input) ---
	objective_panel = PanelContainer.new()
	objective_panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(PixelUI.FUNDO_QUADRO, PixelUI.AZUL_QUADRO, 12))
	objective_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	objective_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	objective_panel.offset_left = 40.0
	objective_panel.offset_bottom = -60.0
	objective_panel.custom_minimum_size = Vector2(420, 0)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.visible = false
	add_child(objective_panel)

	var obj_v = VBoxContainer.new()
	obj_v.add_theme_constant_override("separation", 6)
	obj_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_child(obj_v)

	var obj_head = HBoxContainer.new()
	obj_head.add_theme_constant_override("separation", 12)
	obj_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_v.add_child(obj_head)

	objective_title = Label.new()
	objective_title.text = "OBJETIVO"
	objective_title.add_theme_font_size_override("font_size", 18)
	objective_title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	obj_head.add_child(objective_title)

	objective_pips = HBoxContainer.new()
	objective_pips.add_theme_constant_override("separation", 4)
	objective_pips.alignment = BoxContainer.ALIGNMENT_END
	objective_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_head.add_child(objective_pips)

	var obj_h = HBoxContainer.new()
	obj_h.add_theme_constant_override("separation", 10)
	obj_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_v.add_child(obj_h)

	objective_check = Label.new()
	objective_check.text = "[ ]"
	objective_check.add_theme_font_size_override("font_size", 24)
	obj_h.add_child(objective_check)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	objective_label.custom_minimum_size = Vector2(320, 0)
	objective_label.add_theme_font_size_override("font_size", 24)
	objective_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	obj_h.add_child(objective_label)

# Encaixa a caixa de diálogo embaixo (padrão) ou em cima da tela — em cima
# quando o holofote aponta algo na metade de baixo, pra não esconder o alvo.
func _dock_dialogue(at_top: bool) -> void:
	_dock_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN if at_top else BoxContainer.ALIGNMENT_END

# ---------------------------------------------------------------------
# Falas
# ---------------------------------------------------------------------

# Toca uma sequência de falas, uma de cada vez, esperando o jogador clicar
# "continuar" em cada uma. Aguardável — quem chama espera até a última
# fala ser fechada. Itens: String ou {"t", "spot", "caption"}.
func play_sequence(new_lines: Array, allow_skip: bool = true) -> void:
	if new_lines.is_empty():
		return
	# allow_skip = false: esconde o PULAR (o final do tutorial, com a cutscene
	# do Guia virando o Irmão, não pode ser pulado).
	skip_btn.visible = allow_skip
	lines = new_lines
	current_line_index = -1
	is_showing_sequence = true
	dialogue_panel.visible = true
	_advance_line()
	await sequence_finished

func _advance_line() -> void:
	current_line_index += 1
	if current_line_index >= lines.size():
		dialogue_panel.visible = false
		is_showing_sequence = false
		_set_speaker("guide")
		_crown_t = -1.0
		_line_spot_id = ""
		_line_spot_caption = ""
		sequence_finished.emit()
		return
	var line = lines[current_line_index]
	var text: String = ""
	# {"who": "evil"} troca quem fala; {"flip": "evil"} gira o rosto do Guia
	# (como uma peça virada) e só então mostra a fala com o novo rosto.
	if line is Dictionary and line.has("flip"):
		_run_flip_line(line)
		return
	# {"crown": true}: o Guia se coroa (coroa cai sobre o retrato) e depois fala.
	if line is Dictionary and line.get("crown", false):
		_run_crown_line(line)
		return
	if line is Dictionary and line.has("who"):
		_set_speaker(str(line["who"]))
	_line_shake = float(line.get("shake", 0.0)) if line is Dictionary else 0.0
	if line is Dictionary:
		text = str(line.get("t", ""))
		_line_spot_id = str(line.get("spot", ""))
		_line_spot_caption = str(line.get("caption", ""))
	else:
		text = str(line)
		_line_spot_id = ""
		_line_spot_caption = ""
	text_label.text = text
	text_label.visible_characters = 0
	_type_pos = 0.0
	_typing = true
	continue_btn.text = "CONTINUAR" if current_line_index < lines.size() - 1 else "ENTENDIDO"
	# Se o holofote aponta algo embaixo, sobe a caixa de diálogo.
	var r = _resolve(_line_spot_id)
	var vp = get_viewport().get_visible_rect().size
	_dock_dialogue(r.size != Vector2.ZERO and r.get_center().y > vp.y * 0.5)

func _set_speaker(who: String) -> void:
	_speaker = who
	portrait.set_who(who)
	name_label.text = SPEAKER_NAMES.get(who, "O GUIA")
	name_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(who, Color("#e8857a")))
	if who == "evil":
		dialogue_panel.add_theme_stylebox_override("panel", _char_panel(EVIL_TINT, 22))
	elif _guide_style != null:
		dialogue_panel.add_theme_stylebox_override("panel", _guide_style)

# A virada dramática: o Guia treme, a tela escurece e racha em relâmpagos, o
# rosto gira como uma peça sendo virada, cresce e SE CHOCA de volta já como o
# Irmão — com onda de choque, clarão, brasas e letreiro gigante. Depois a
# fala é digitada com a tela tremendo (ver _process).
func _run_flip_line(line: Dictionary) -> void:
	_flipping = true
	_typing = false
	_line_shake = 0.0
	text_label.text = ""
	continue_btn.disabled = true
	_dock_dialogue(false)
	portrait.pivot_offset = portrait.size / 2.0
	portrait.talking = false

	# 1) Pressentimento: o Guia treme, relâmpagos, tudo escurece em vermelho.
	Sfx.play("irmao_pressentimento")
	var tw1 = create_tween().set_parallel(true)
	tw1.tween_property(self, "_evil_amt", 0.55, 0.9)
	tw1.tween_property(self, "_shake", 7.0, 0.9)
	for k in range(7):
		tw1.tween_property(portrait, "rotation", 0.12 if k % 2 == 0 else -0.12, 0.12).set_delay(k * 0.12)
	tw1.tween_callback(func(): _flash = 0.9).set_delay(0.25)
	tw1.tween_callback(func(): _flash = 1.0).set_delay(0.6)
	await tw1.finished
	if not is_showing_sequence:
		return

	# 2) Cara ou coroa: o rosto sai do retrato, vai pro centro e é jogado pro ar
	# girando como a moeda da aposta (achata na horizontal, troca de lado, volta).
	# O "outro lado" do Guia é o Irmão: 9 viradas (ímpar) pousam nele.
	_shake = 10.0
	var vp = get_viewport().get_visible_rect().size
	_crown_t = -1.0
	_big_who = "guide"
	_big_pos = portrait.get_global_rect().get_center()
	_big_size = portrait.size.x
	_big_flip_x = 1.0
	_big_toss = 1.0
	_big_on = true
	portrait.modulate.a = 0.0
	portrait.rotation = 0.0
	var tw_move = create_tween().set_parallel(true)
	tw_move.tween_property(self, "_big_pos", vp / 2.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_move.tween_property(self, "_big_size", 380.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_move.finished
	if not is_showing_sequence:
		_big_on = false
		portrait.modulate.a = 1.0
		return
	Sfx.play("moeda_girar_longa")
	var coin = create_tween().set_parallel(true)
	coin.tween_property(self, "_big_toss", 1.9, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	coin.tween_property(self, "_big_toss", 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.8)
	coin.tween_property(self, "_evil_amt", 0.85, 1.6)
	var delay := 0.0
	for k in range(9):
		coin.tween_method(func(v): _big_flip_x = v, 1.0, 0.0, 0.08).set_delay(delay)
		coin.tween_callback(func(): _big_who = "evil" if _big_who == "guide" else "guide").set_delay(delay + 0.08)
		coin.tween_method(func(v): _big_flip_x = v, 0.0, 1.0, 0.08).set_delay(delay + 0.08)
		delay += 0.16 + k * 0.012
	await coin.finished
	if not is_showing_sequence:
		_big_on = false
		portrait.modulate.a = 1.0
		return

	# 3) IMPACTO: vira o Irmão, clarão, onda de choque, brasas, 
	Sfx.play("irmao_impacto")
	_big_who = str(line["flip"])
	_set_speaker(_big_who)
	_flash = 1.0
	_shake = 34.0
	_ring_t = 0.0
	for k in range(90):
		_spawn_ember(true)
	var tw3 = create_tween().set_parallel(true)
	tw3.tween_property(self, "_big_size", 720.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw3.tween_property(self, "_ring_t", 1.0, 0.8)
	tw3.tween_property(self, "_evil_amt", 1.0, 0.8)
	await tw3.finished
	# O rosto malvado "encolhe" de volta ao retrato, com tranco.
	Sfx.play("boss_encolhe")
	var back = create_tween().set_parallel(true)
	var slot = portrait.get_global_rect().get_center()
	back.tween_property(self, "_big_pos", slot, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	back.tween_property(self, "_big_size", portrait.size.x, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await back.finished
	_big_on = false
	portrait.modulate.a = 1.0
	_shake = 18.0
	await get_tree().create_timer(0.2).timeout
	_flipping = false
	_ring_t = -1.0
	if not is_showing_sequence:
		return
	continue_btn.disabled = false
	_line_spot_id = ""
	_line_spot_caption = ""
	_line_shake = float(line.get("shake", 0.0))
	text_label.text = str(line.get("t", ""))
	text_label.visible_characters = 0
	_type_pos = 0.0
	_typing = true
	continue_btn.text = "CONTINUAR" if current_line_index < lines.size() - 1 else "ENTENDIDO"

# Coroação do Guia: clarão dourado e tremor (sem desenhar coroa no retrato);
# só depois a fala é digitada.
func _run_crown_line(line: Dictionary) -> void:
	_flipping = true
	_typing = false
	_line_shake = 0.0
	text_label.text = ""
	continue_btn.disabled = true
	_dock_dialogue(false)
	portrait.talking = false
	_crown_t = 0.0
	var tw = create_tween()
	tw.tween_property(self, "_crown_t", 0.55, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _flash = 0.55; _shake = 8.0)
	tw.tween_property(self, "_crown_t", 1.0, 0.6)
	await tw.finished
	await get_tree().create_timer(0.35).timeout
	_flipping = false
	if not is_showing_sequence:
		_crown_t = -1.0
		return
	continue_btn.disabled = false
	_line_spot_id = ""
	_line_spot_caption = ""
	text_label.text = str(line.get("t", ""))
	text_label.visible_characters = 0
	_type_pos = 0.0
	_typing = true
	continue_btn.text = "CONTINUAR" if current_line_index < lines.size() - 1 else "ENTENDIDO"

func _spawn_ember(burst: bool = false) -> void:
	var vp = get_viewport().get_visible_rect().size
	var e := {"life": randf_range(1.2, 2.8), "max": 0.0, "size": randf_range(2.0, 6.0)}
	e["max"] = e["life"]
	if burst:
		e["pos"] = vp / 2.0 + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		e["vel"] = Vector2.from_angle(randf() * TAU) * randf_range(200.0, 900.0)
	else:
		e["pos"] = Vector2(randf() * vp.x, vp.y + 10.0)
		e["vel"] = Vector2(randf_range(-30.0, 30.0), -randf_range(80.0, 260.0))
	_embers.append(e)

func _get_vignette() -> GradientTexture2D:
	if _vignette_tex == null:
		var gr = Gradient.new()
		gr.colors = PackedColorArray([Color(0.6, 0, 0, 0), Color(0.6, 0, 0, 0.0), Color(0.7, 0.02, 0.05, 0.75)])
		gr.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		_vignette_tex = GradientTexture2D.new()
		_vignette_tex.gradient = gr
		_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
		_vignette_tex.fill_from = Vector2(0.5, 0.5)
		_vignette_tex.fill_to = Vector2(1.0, 0.5)
		_vignette_tex.width = 256
		_vignette_tex.height = 256
	return _vignette_tex

func _draw_fx() -> void:
	var vp = _fx.size
	if _evil_amt > 0.01:
		var pulse = 0.8 + 0.2 * sin(_t * 5.0)
		_fx.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.25, 0.0, 0.02, 0.22 * _evil_amt))
		_fx.draw_texture_rect(_get_vignette(), Rect2(Vector2.ZERO, vp), false, Color(1, 1, 1, _evil_amt * pulse * 0.9))
	for e in _embers:
		var a = clampf(e["life"] / e["max"], 0.0, 1.0)
		_fx.draw_rect(Rect2(e["pos"], Vector2.ONE * e["size"]), Color(1.0, 0.35 + 0.4 * a, 0.1, a))

func _draw_fx_top() -> void:
	var vp = _fx_top.size
	if _big_on:
		var tex: Texture2D = portrait.texture_for(_big_who, 0)
		var d = _big_size * _big_toss
		var w = maxf(d * absf(_big_flip_x), 2.0)
		var h_air = clampf((_big_toss - 1.0) / 0.9, 0.0, 1.0)
		var shadow_off = Vector2(4.0 + h_air * 14.0, 6.0 + h_air * 26.0)
		_fx_top.draw_texture_rect(tex, Rect2(_big_pos - Vector2(w, d) / 2.0 + shadow_off, Vector2(w, d)), false, Color(0, 0, 0, 0.45 - h_air * 0.2))
		_fx_top.draw_texture_rect(tex, Rect2(_big_pos - Vector2(w, d) / 2.0, Vector2(w, d)), false)
	if _ring_t >= 0.0:
		var c = vp / 2.0
		var rad = _ring_t * vp.length() * 0.6
		_fx_top.draw_arc(c, rad, 0, TAU, 96, Color(1.0, 0.25, 0.15, 1.0 - _ring_t), 22.0 * (1.0 - _ring_t) + 2.0)
		_fx_top.draw_arc(c, rad * 0.7, 0, TAU, 96, Color(1.0, 0.8, 0.5, (1.0 - _ring_t) * 0.7), 8.0)
	if _flash > 0.01:
		_fx_top.draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, _flash))

func _on_continue_pressed() -> void:
	if _flipping:
		return
	if _typing:
		# Primeiro clique completa o texto; o segundo avança.
		_typing = false
		text_label.visible_characters = -1
		return
	_advance_line()

# Pula o resto da sequência atual (quem já conhece o jogo não precisa ler tudo).
func _on_skip_pressed() -> void:
	if not skip_btn.visible:
		return
	_typing = false
	current_line_index = lines.size() - 1
	_advance_line()

func _input(event: InputEvent) -> void:
	if not dialogue_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_continue_pressed()
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------
# Objetivos
# ---------------------------------------------------------------------

func _rebuild_pips() -> void:
	for c in objective_pips.get_children():
		c.queue_free()
	var total: int = TutorialManager.get_objectives(TutorialManager.current_step).size()
	var cur: int = TutorialManager.get_objective_number()
	for i in range(total):
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < cur - 1:
			pip.color = Color(0.4, 0.9, 0.45)
		elif i == cur - 1:
			pip.color = Color(0.9, 0.75, 0.3)
		else:
			pip.color = Color(0.3, 0.32, 0.4)
		objective_pips.add_child(pip)

func _on_objective_changed(text: String, done: bool) -> void:
	if text == "":
		objective_panel.visible = false
		return
	objective_panel.visible = true
	objective_label.text = text
	var total: int = TutorialManager.get_objectives(TutorialManager.current_step).size()
	objective_title.text = "OBJETIVO %d/%d" % [TutorialManager.get_objective_number(), total]
	_rebuild_pips()
	if done:
		objective_check.text = "[X]"
		objective_check.add_theme_color_override("font_color", Color(0.4, 0.9, 0.45))
		objective_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
		# Brilho rápido para marcar a conquista.
		objective_panel.modulate = Color(1.7, 1.7, 1.4)
		create_tween().tween_property(objective_panel, "modulate", Color.WHITE, 0.6)
		var done_tip = TutorialManager.consume_done_tip()
		if done_tip != "":
			show_tip(done_tip)
		# Quando ainda existe um próximo objetivo, ele chega logo depois (outro
		# emit) e substitui este; se foi o último, o check fica visível um tempo.
		if TutorialManager.all_objectives_done():
			await get_tree().create_timer(3.5).timeout
			if TutorialManager.all_objectives_done():
				objective_panel.visible = false
	else:
		objective_check.text = "[ ]"
		objective_check.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		objective_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))

func _on_objective_started(obj: Dictionary) -> void:
	_obj_spot_id = str(obj.get("spot", ""))
	_obj_spot_caption = str(obj.get("caption", ""))
	_obj_spot_dim = float(obj.get("dim", DIM_OBJECTIVE))
	_obj_idle_tip = str(obj.get("idle_tip", ""))
	_obj_idle_spot = str(obj.get("idle_spot", ""))
	_obj_idle_t = 0.0

func _on_objective_done(_event_id: String) -> void:
	_obj_spot_id = ""
	_obj_spot_caption = ""
	_obj_idle_tip = ""

# ---------------------------------------------------------------------
# Dicas e destaques
# ---------------------------------------------------------------------

# Dica pontual, mostrada por cima do jogo (ex: durante um duelo),
# desaparecendo sozinha depois de alguns segundos — não bloqueia o
# jogador, só chama atenção pro que está acontecendo.
func show_tip(text: String, duration: float = 6.0) -> void:
	_tip_gen += 1
	var my_gen = _tip_gen
	tip_label.text = text
	tip_panel.visible = true
	await get_tree().create_timer(duration).timeout
	# Uma dica mais nova pode ter trocado o texto: só esconde se ainda é a minha.
	if my_gen == _tip_gen:
		tip_panel.visible = false

# Destaca um retângulo da tela (coordenadas de viewport) com uma moldura
# pulsante durante alguns segundos (sem escurecer o resto).
func pulse_rect(rect: Rect2, duration: float = 4.5) -> void:
	_pulse_spot_id = ""
	_pulse_rect = rect.grow(8.0)
	_pulse_until = _t + duration

# Igual a pulse_rect, mas a moldura acompanha o trecho da interface a cada
# quadro — pra mão de cartas, que cresce quando o mouse chega perto.
func pulse_spot(spot_id: String, duration: float = 4.5) -> void:
	_pulse_spot_id = spot_id
	_pulse_until = _t + duration

func _resolve(spot_id: String) -> Rect2:
	if spot_id == "" or not spot_resolver.is_valid():
		return Rect2()
	var r = spot_resolver.call(spot_id)
	return r if r is Rect2 else Rect2()

# Cartão de título de lição ("LIÇÃO 2 · A LOJA"): aparece, fica um instante
# e some. Aguardável.
func play_title_card(kicker: String, title: String, subtitle: String = "") -> void:
	if _title_card != null and is_instance_valid(_title_card):
		_title_card.queue_free()
	_title_card = PanelContainer.new()
	_title_card.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(PixelUI.FUNDO_QUADRO, PixelUI.AZUL_QUADRO, 28))
	_title_card.set_anchors_preset(Control.PRESET_CENTER)
	_title_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.modulate = Color(1, 1, 1, 0)
	add_child(_title_card)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.add_child(v)

	var k = Label.new()
	k.text = kicker
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_theme_font_size_override("font_size", 28)
	k.add_theme_color_override("font_color", Color(0.6, 0.78, 1.0))
	k.custom_minimum_size = Vector2(760, 0)
	v.add_child(k)

	var t = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	t.add_theme_constant_override("outline_size", 8)
	v.add_child(t)

	if subtitle != "":
		var s = Label.new()
		s.text = subtitle
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_size_override("font_size", 26)
		s.add_theme_color_override("font_color", Color(0.8, 0.84, 0.9))
		v.add_child(s)

	var card = _title_card
	var tw = create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.45)
	await tw.finished
	if is_instance_valid(card):
		card.queue_free()

# ---------------------------------------------------------------------
# Desenho (holofote)
# ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _blocker != null:
		_blocker.visible = is_showing_sequence or (_title_card != null and is_instance_valid(_title_card))
	if objective_panel != null:
		objective_panel.modulate.a = 0.0 if is_showing_sequence else 1.0
	# Dica avulsa nunca aparece por cima de uma fala do Guia.
	if tip_panel != null:
		tip_panel.modulate.a = 0.0 if (is_showing_sequence or (_title_card != null and is_instance_valid(_title_card))) else 1.0
	_t += delta
	_update_idle_hint(delta)
	_update_fx(delta)
	# Portrait "fala" enquanto o texto está sendo digitado.
	if dialogue_panel.visible and portrait != null:
		portrait.talking = _typing
		if not _flipping:
			_talk_phase += delta
			portrait.pivot_offset = portrait.size / 2.0
			var s := 1.0 + 0.012 * sin(_talk_phase * 3.0)
			portrait.scale = Vector2(s, s)
	if _typing:
		var prev_chars: int = int(_type_pos)
		_type_pos += delta * TYPE_SPEED
		var total: int = text_label.text.length()
		_blip_for_new_chars(prev_chars, mini(int(_type_pos), total))
		if _type_pos >= total:
			_typing = false
			text_label.visible_characters = -1
		else:
			text_label.visible_characters = int(_type_pos)
	_overlay.queue_redraw()

# "Blip" de voz por letra revelada (estilo Undertale); pula espaços/pontuação.
func _blip_for_new_chars(from_i: int, to_i: int) -> void:
	var txt: String = text_label.text
	for i in range(from_i, to_i):
		if i >= 0 and i < txt.length() and not " .,;:!?…-—\n".contains(txt[i]):
			Sfx.play("voz_irmao" if _speaker == "evil" else "voz_guia")
			return

# Jogador parado há um tempo sem cumprir o objetivo (ex.: não percebeu que é pra
# mover uma peça): mostra a dica do objetivo e pulsa o trecho indicado, uma vez.
func _update_idle_hint(delta: float) -> void:
	if _obj_idle_tip == "" or is_showing_sequence:
		return
	_obj_idle_t += delta
	if _obj_idle_t < IDLE_HINT_SECONDS:
		return
	var tip := _obj_idle_tip
	_obj_idle_tip = ""
	show_tip(tip, 9.0)
	if _obj_idle_spot != "" and _resolve(_obj_idle_spot).size != Vector2.ZERO:
		pulse_spot(_obj_idle_spot, 6.0)

# Qual destaque está valendo agora: fala > objetivo > pulso avulso.
func _active_spot() -> Dictionary:
	if is_showing_sequence and _line_spot_id != "":
		var r = _resolve(_line_spot_id)
		if r.size != Vector2.ZERO:
			return {"rect": r, "caption": _line_spot_caption, "dim": DIM_DIALOGUE}
	# Dica por inatividade (objetivo sem escurecimento): a moldura da dica vem
	# na frente da moldura do objetivo, senão ela nunca apareceria.
	if not is_showing_sequence and _obj_spot_dim <= 0.0 and _t < _pulse_until and _pulse_spot_id != "":
		var ri = _resolve(_pulse_spot_id)
		if ri.size != Vector2.ZERO:
			return {"rect": ri.grow(8.0), "caption": "", "dim": 0.0}
	if not is_showing_sequence and _obj_spot_id != "":
		var r2 = _resolve(_obj_spot_id)
		if r2.size != Vector2.ZERO:
			return {"rect": r2, "caption": _obj_spot_caption, "dim": _obj_spot_dim}
	if _t < _pulse_until:
		if _pulse_spot_id != "":
			var rp = _resolve(_pulse_spot_id)
			if rp.size != Vector2.ZERO:
				return {"rect": rp.grow(8.0), "caption": "", "dim": 0.0}
		elif _pulse_rect.size != Vector2.ZERO:
			return {"rect": _pulse_rect, "caption": "", "dim": 0.0}
	return {}

func _update_fx(delta: float) -> void:
	# Ambiente vermelho enquanto o Irmão fala (some quando o Guia volta).
	if not _flipping:
		var target := 1.0 if _speaker == "evil" else 0.0
		_evil_amt = move_toward(_evil_amt, target, delta * 1.2)
	_flash = maxf(0.0, _flash - delta * 2.2)
	# Tremor: pontual (decai) + contínuo enquanto a fala forte é digitada.
	_shake = maxf(0.0, _shake - delta * 28.0)
	var s := _shake
	if _typing and _line_shake > 0.0:
		s = maxf(s, 2.0 + 4.0 * _line_shake)
	offset = Vector2(randf_range(-s, s), randf_range(-s, s)) if s > 0.05 else Vector2.ZERO
	if _evil_amt > 0.3 and randf() < delta * 40.0 * _evil_amt:
		_spawn_ember()
	var alive: Array = []
	for e in _embers:
		e["life"] -= delta
		e["pos"] += e["vel"] * delta
		e["vel"] = e["vel"] * (1.0 - minf(delta * 1.5, 1.0))
		if e["life"] > 0.0:
			alive.append(e)
	_embers = alive
	if _crown_t >= 0.0 or _big_on or _ring_t >= 0.0 or _evil_amt > 0.01 or _flash > 0.01 or not _embers.is_empty():
		_fx.queue_redraw()
		_fx_top.queue_redraw()

func _draw_overlay() -> void:
	var spot: Dictionary = _active_spot()
	if spot.is_empty():
		return
	var vp = get_viewport().get_visible_rect().size
	var rect: Rect2 = (spot["rect"] as Rect2).grow(8.0)
	var dim: float = spot["dim"]
	var caption: String = spot["caption"]

	if dim > 0.0:
		var c = Color(0.0, 0.0, 0.03, dim)
		_overlay.draw_rect(Rect2(0, 0, vp.x, maxf(0.0, rect.position.y)), c)
		_overlay.draw_rect(Rect2(0, rect.end.y, vp.x, maxf(0.0, vp.y - rect.end.y)), c)
		_overlay.draw_rect(Rect2(0, rect.position.y, maxf(0.0, rect.position.x), rect.size.y), c)
		_overlay.draw_rect(Rect2(rect.end.x, rect.position.y, maxf(0.0, vp.x - rect.end.x), rect.size.y), c)

	var pulse = 0.5 + 0.5 * sin(_t * 6.0)
	var col = Color(1.0, 0.85, 0.3, 0.6 + 0.4 * pulse)
	_overlay.draw_rect(rect.grow(pulse * 3.0), col, false, 4.0)
	_overlay.draw_rect(rect, Color(1.0, 0.85, 0.3, 0.05 + 0.05 * pulse), true)
	# Cantinhos "pixel" reforçando a moldura.
	var cs = 14.0
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var sx = -1.0 if corner.x >= rect.end.x - 0.5 else 1.0
		var sy = -1.0 if corner.y >= rect.end.y - 0.5 else 1.0
		_overlay.draw_rect(Rect2(corner + Vector2(0.0 if sx > 0 else -cs, 0.0 if sy > 0 else -cs), Vector2(cs, cs)), Color(1.0, 0.95, 0.6, 0.9), false, 3.0)

	# Seta com legenda (só para alvos pequenos o bastante).
	var big: bool = rect.size.x * rect.size.y > vp.x * vp.y * 0.28
	# Alvo grande (ex.: o tabuleiro): sem seta; a legenda vai numa plaquinha no topo do destaque.
	if caption != "" and big:
		var bfont = ThemeDB.fallback_font
		var bfs = 24
		var btw = bfont.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		var bbob = sin(_t * 6.0) * 4.0
		var bbox = Rect2(rect.get_center().x - btw * 0.5 - 16.0, rect.position.y + 10.0 + bbob, btw + 32.0, 42.0)
		_overlay.draw_rect(bbox, Color(0.08, 0.09, 0.13, 0.96))
		_overlay.draw_rect(bbox, Color(1.0, 0.85, 0.3), false, 3.0)
		_overlay.draw_string(bfont, Vector2(bbox.position.x + 16.0, bbox.position.y + 30.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(1.0, 0.92, 0.6))
	if caption != "" and not big:
		var font = ThemeDB.fallback_font
		var fs = 22
		var tw = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bob = sin(_t * 6.0) * 6.0
		var below: bool = rect.get_center().y < vp.y * 0.6
		var cx = clampf(rect.get_center().x, tw * 0.5 + 24.0, vp.x - tw * 0.5 - 24.0)
		var tip_y: float
		var box_y: float
		if below:
			tip_y = rect.end.y + 6.0 + bob
			box_y = tip_y + 22.0
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(rect.get_center().x, tip_y), Vector2(rect.get_center().x - 14.0, tip_y + 22.0), Vector2(rect.get_center().x + 14.0, tip_y + 22.0)]), Color(1.0, 0.85, 0.3))
		else:
			tip_y = rect.position.y - 6.0 - bob
			box_y = tip_y - 22.0 - 38.0
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(rect.get_center().x, tip_y), Vector2(rect.get_center().x - 14.0, tip_y - 22.0), Vector2(rect.get_center().x + 14.0, tip_y - 22.0)]), Color(1.0, 0.85, 0.3))
		var box = Rect2(cx - tw * 0.5 - 14.0, box_y, tw + 28.0, 38.0)
		_overlay.draw_rect(box, Color(0.08, 0.09, 0.13, 0.96))
		_overlay.draw_rect(box, Color(1.0, 0.85, 0.3), false, 3.0)
		_overlay.draw_string(font, Vector2(box.position.x + 14.0, box.position.y + 27.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.6))
