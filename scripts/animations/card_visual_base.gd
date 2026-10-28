class_name CardVisualBase
extends Control

# Base compartilhada entre ActionCardVisual e RuleCardVisual. As duas classes
# tinham o mesmo esqueleto implementado quase idêntico duas vezes: um card_root
# centralizado (pivot no meio, pra girar no flip), o padrão "carrega textura se
# existir, senão monta um fallback procedural" repetido pra frente e verso, e a
# mesma animação de flip (só a duração de cada metade do giro variava um pouco).
#
# Cada subclasse ainda é responsável pelo que é genuinamente diferente entre
# elas: tamanho da carta, paleta de cor (raridade vs. categoria), o desenho do
# fallback procedural em si, e qualquer comportamento extra (tooltip, selo).

signal flipped_face_up()

var is_face_up: bool = false
var card_root: Control
var back_view: Control
var front_view: Control
var flip_tween: Tween

var _card_size: Vector2 = Vector2.ZERO
var _desc_scroll_tween: Tween

# Monta o card_root centralizado. Chame isso no _init() da subclasse antes de
# montar frente/verso.
func _setup_card_root(card_size: Vector2) -> void:
	_card_size = card_size
	custom_minimum_size = card_size
	size = card_size

	card_root = Control.new()
	card_root.custom_minimum_size = card_size
	card_root.size = card_size
	card_root.position = card_size / 2.0
	# O conteúdo é desenhado em [-metade, +metade] ao redor da origem do card_root,
	# então o centro visual da carta é o pivô (0,0). Antes o pivô ficava em
	# +metade (canto inferior direito), e a rotação/flip giravam em torno dele.
	card_root.pivot_offset = Vector2.ZERO
	card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_root)
	set_process(idle_float)
	mouse_entered.connect(tilt_begin)
	mouse_exited.connect(tilt_end)
	gui_input.connect(_tilt_on_gui_input)

# ---------------------------------------------------------------------
# Hover "afundando": a carta inclina como se o mouse estivesse apertando a
# região onde está — o lado do mouse afunda (fica menor/mais escuro) e o lado
# oposto levanta (maior/mais claro), em perspectiva.
# Como funciona: enquanto o mouse está em cima, o card_root é movido para dentro
# de um CanvasGroup (renderiza a carta num buffer) com um shader que remapeia
# o buffer em perspectiva. Ao terminar de assentar, tudo volta ao normal (zero
# custo em repouso). Funciona sozinho em cartas que recebem mouse; cartas cujo
# pai trata o mouse podem chamar tilt_begin() / tilt_update() / tilt_end().
const _TILT_SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 center_uv = vec2(0.5);
uniform vec2 size_uv = vec2(0.1);
uniform vec2 tilt = vec2(0.0);
uniform float depth = 0.055;
uniform float zoom = 1.03;
uniform float shade = 0.10;
void fragment() {
	vec2 q = (SCREEN_UV - center_uv) / size_uv;
	float side = clamp(dot(tilt, q) * 2.0, -1.0, 1.0);
	float w = max(1.0 - depth * dot(tilt, q) * 2.0, 0.4);
	vec2 p = q / (w * zoom);
	vec4 c = texture(screen_texture, center_uv + p * size_uv);
	c.rgb *= 1.0 - shade * side * step(0.001, c.a);
	COLOR = c;
}
"""
static var _tilt_shader: Shader = null

var _tilt_group: CanvasGroup = null
var _tilt_mat: ShaderMaterial = null
var _tilt_hover: bool = false
var _tilt_target: Vector2 = Vector2.ZERO    # -1..1 : posição do mouse relativa ao centro
var _tilt_cur: Vector2 = Vector2.ZERO
var _tilt_amp: float = 0.0

# Para cartas cujo mouse é tratado pelo pai (mão, botões de escolha): faz o `host`
# dirigir o hover "afundando" da carta.
static func bind_tilt(host: Control, visual: CardVisualBase) -> void:
	host.mouse_entered.connect(func():
		if is_instance_valid(visual): visual.tilt_begin())
	host.mouse_exited.connect(func():
		if is_instance_valid(visual): visual.tilt_end())
	host.gui_input.connect(func(ev):
		if ev is InputEventMouseMotion and is_instance_valid(visual):
			visual.tilt_update(visual.get_global_transform_with_canvas().affine_inverse() * host.get_global_transform_with_canvas() * host.get_local_mouse_position()))

func tilt_begin() -> void:
	if card_root == null or not is_face_up:
		return
	_tilt_hover = true
	if _tilt_group == null:
		if _tilt_shader == null:
			_tilt_shader = Shader.new()
			_tilt_shader.code = _TILT_SHADER_CODE
		_tilt_mat = ShaderMaterial.new()
		_tilt_mat.shader = _tilt_shader
		_tilt_group = CanvasGroup.new()
		_tilt_group.fit_margin = maxf(_card_size.x, _card_size.y) * 0.3
		_tilt_group.material = _tilt_mat
		add_child(_tilt_group)
		card_root.reparent(_tilt_group, false)
	set_process(true)

# local_pos: posição do mouse em coordenadas locais da carta (0..size).
func tilt_update(local_pos: Vector2) -> void:
	if not _tilt_hover:
		return
	var n: Vector2 = local_pos / Vector2(maxf(_card_size.x, 1.0), maxf(_card_size.y, 1.0)) - Vector2(0.5, 0.5)
	_tilt_target = (n * 2.0).clamp(Vector2(-1, -1), Vector2(1, 1))

func tilt_end() -> void:
	_tilt_hover = false
	_tilt_target = Vector2.ZERO

func _tilt_on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		tilt_update(get_local_mouse_position())

# Flutuação idle (estilo Balatro): a carta balança de leve, cada uma com a sua
# fase. Só em cartas grandes e viradas para cima; calma um pouco no hover.
var idle_float: bool = true
var _idle_phase: float = randf() * TAU

func _idle_active() -> bool:
	return idle_float and is_face_up and card_root != null and _card_size.x >= 140.0 \
		and not (flip_tween != null and flip_tween.is_valid() and flip_tween.is_running())

func _apply_idle() -> void:
	# Só TRANSLAÇÃO em pixels inteiros: girar pixel art deixa os pixels
	# serrilhados/quebrados, então nada de rotação na flutuação.
	var k: float = _card_size.x / 150.0
	var calm: float = 1.0 - 0.6 * _tilt_amp
	var t: float = Time.get_ticks_msec() / 1000.0
	var bob: float = sin(t * 1.7 + _idle_phase) * 3.5 * k * calm
	var sway: float = sin(t * 1.1 + _idle_phase * 1.7) * 2.0 * k * calm
	card_root.position = (_card_size * 0.5 + Vector2(round(sway), round(bob))).round()
	card_root.rotation = 0.0

func _process(delta: float) -> void:
	if _idle_active():
		_apply_idle()
	elif card_root != null and idle_float and _tilt_group == null and not (flip_tween != null and flip_tween.is_valid() and flip_tween.is_running()):
		card_root.position = _card_size * 0.5
		card_root.rotation = 0.0
	if _tilt_group == null:
		if not idle_float:
			set_process(false)
		return
	var k: float = 1.0 - exp(-delta * 14.0)
	_tilt_amp = lerpf(_tilt_amp, 1.0 if (_tilt_hover and is_face_up) else 0.0, k)
	_tilt_cur = _tilt_cur.lerp(_tilt_target, k)
	var vsize: Vector2 = get_viewport().get_visible_rect().size
	var ct: Transform2D = get_global_transform_with_canvas()
	var c: Vector2 = ct * (_card_size * 0.5)
	var sz: Vector2 = ct.basis_xform(_card_size)
	_tilt_mat.set_shader_parameter("center_uv", c / vsize)
	_tilt_mat.set_shader_parameter("size_uv", sz / vsize)
	_tilt_mat.set_shader_parameter("tilt", _tilt_cur * _tilt_amp)
	_tilt_mat.set_shader_parameter("zoom", 1.0 + 0.012 * _tilt_amp)
	var glow: float = 1.0 + 0.05 * _tilt_amp
	card_root.modulate = Color(glow, glow, glow, 1.0)
	if not _tilt_hover and _tilt_amp < 0.01:
		card_root.reparent(self, false)
		card_root.modulate = Color.WHITE
		_tilt_group.queue_free()
		_tilt_group = null
		_tilt_mat = null
		_tilt_amp = 0.0
		_tilt_cur = Vector2.ZERO
		if not idle_float:
			set_process(false)

# Carrega a textura em tex_path se ela existir no projeto; caso contrário,
# chama fallback_builder() (Callable sem argumentos) para montar um Control
# procedural. Em ambos os casos, posiciona o resultado centralizado dentro do
# card_root, adiciona como filho e devolve o Control criado.
func _load_texture_or_fallback(tex_path: String, fallback_builder: Callable) -> Control:
	var view: Control
	if ResourceLoader.exists(tex_path):
		var rect = TextureRect.new()
		rect.texture = load(tex_path)
		rect.custom_minimum_size = _card_size
		rect.size = _card_size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view = rect
	else:
		view = fallback_builder.call()

	view.position = -_card_size / 2.0
	card_root.add_child(view)
	return view

# TextureRect pixel-art (filtro nearest) posicionado/dimensionado em px.
func _make_art_rect(tex: Texture2D, r: Rect2) -> TextureRect:
	var rect = TextureRect.new()
	# expand_mode ANTES de texture/size: senão o TextureRect trava no tamanho
	# nativo da textura e não consegue ficar menor (cartas pequenas nos slots
	# saíam com a arte maior que o layout do texto).
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = tex
	rect.position = r.position
	rect.size = r.size
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# Animação de flip compartilhada: encolhe no eixo X até 0 (revelando o verso
# escondido / frente escondida no meio do caminho), depois volta a 1. Cada
# subclasse expõe seu próprio play_flip_reveal(delay) público chamando isto
# com as durações que já usava.
func _play_flip_reveal(delay: float, flip_out_duration: float, flip_in_duration: float) -> void:
	if flip_tween and flip_tween.is_valid():
		flip_tween.kill()

	is_face_up = false
	back_view.visible = true
	front_view.visible = false
	card_root.scale.x = 1.0

	flip_tween = create_tween()
	if delay > 0.0:
		flip_tween.tween_interval(delay)

	flip_tween.tween_property(card_root, "scale:x", 0.0, flip_out_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	flip_tween.tween_callback(func():
		back_view.visible = false
		front_view.visible = true
		is_face_up = true
	)

	flip_tween.tween_property(card_root, "scale:x", 1.0, flip_in_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	flip_tween.tween_callback(func(): flipped_face_up.emit())

# Monta uma "frente de carta" 100% procedural em texto: selo no canto,
# título ao lado, divisória, e uma caixa de descrição preenchendo o resto.
# É a ÚNICA forma como ActionCardVisual e RuleCardVisual desenham a frente —
# nenhuma das duas carrega mais imagem de frente, só o verso ainda pode usar
# sprite genérico por raridade/categoria.
# Estes números espelham exatamente os valores fixos usados para montar o
# layout abaixo (margem do painel raiz, altura do cabeçalho, separações do
# VBoxContainer, margem do desc_box, offsets do Label de descrição). Usá-los
# aqui para calcular a área disponível de forma determinística evita depender
# de sinais de resize/timing de entrada na árvore de cena, que se mostraram
# pouco confiáveis (a carta pode ser medida antes de entrar na árvore, ou
# enquanto está com visible=false esperando o flip, e o Godot pode nunca
# calcular o layout real nesses casos).
const _TEXT_FACE_OUTER_MARGIN: float = 8.0
const _TEXT_FACE_HEADER_HEIGHT: float = 38.0
const _TEXT_FACE_DIVIDER_HEIGHT: float = 2.0
const _TEXT_FACE_VBOX_SEPARATION: float = 8.0
const _TEXT_FACE_DESC_BOX_MARGIN: float = 6.0
const _TEXT_FACE_DESC_INSET_H: float = 8.0
const _TEXT_FACE_DESC_INSET_V: float = 10.0
const _DESC_FONT_PATH: String = "res://assets/m5x7.ttf"
const _FRONT_TEXTURE_PATH: String = "res://assets/sprites/ui/front_parchment.png"
const _PAPER_INSET: float = 8.0

static var _front_texture_cache: Texture2D = null

# Textura de pergaminho compartilhada por TODAS as cartas/leis. Cai de volta
# pro panel_style original (cor sólida) se a textura não existir, então
# nunca quebra mesmo sem o arquivo. Sempre neutra — a cor de categoria/
# raridade vem da CAMADA DE BORDA separada (ver _build_border_overlay).
func _get_front_stylebox(fallback_style: StyleBoxFlat, _scale_factor: float) -> StyleBox:
	if _front_texture_cache == null:
		if ResourceLoader.exists(_FRONT_TEXTURE_PATH):
			_front_texture_cache = load(_FRONT_TEXTURE_PATH)

	if _front_texture_cache == null:
		return fallback_style

	# Sem margem de 9-slice: o papel não tem decoração de canto, só textura
	# uniforme — estica por inteiro. O recuo em relação à borda vem de
	# "root" ser posicionado/dimensionado menor (ver _build_text_face),
	# não de esticar a textura por baixo da faixa da borda inteira.
	var sb = StyleBoxTexture.new()
	sb.texture = _front_texture_cache
	return sb

# Camada de borda: uma imagem ÚNICA, já pronta, com moldura + cantos +
# bolinhas todos desenhados juntos na MESMA imagem — gerada previamente
# pro tamanho EXATO de cada combinação carta/escala que o jogo realmente
# usa (180x180 e 252x252 pras Leis; 160x224 e 224x313 pras Cartas).
#
# Isso substitui três tentativas anteriores (9-slice, cantos+linha reta
# código, cantos+linha ColorRect+bolinha) que tentavam montar a moldura em
# TEMPO DE EXECUÇÃO a partir de peças separadas — e cada uma delas sofria
# de pequenos desalinhamentos de pixel entre as peças (a espessura de uma
# linha não batia exatamente com a de outra peça, etc.) que eu não
# conseguia verificar sem rodar o Godot de verdade. Com a imagem inteira
# pronta de antemão, todo o alinhamento é garantido no momento em que a
# imagem foi desenhada — o Godot só precisa mostrá-la, sem matemática de
# posicionamento nenhuma.
static var _frame_texture_cache: Dictionary = {}

func _build_border_overlay(border_slug: String, card_size: Vector2, _scale_factor: float) -> Control:
	if border_slug == "":
		return null

	var w = int(round(card_size.x))
	var h = int(round(card_size.y))
	var path = "res://assets/sprites/ui/frames/frame_%s_%dx%d.png" % [border_slug, w, h]

	if not _frame_texture_cache.has(path):
		_frame_texture_cache[path] = load(path) if ResourceLoader.exists(path) else null

	var tex: Texture2D = _frame_texture_cache[path]
	if tex == null:
		return null

	var rect = TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = card_size
	rect.size = card_size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _build_text_face(card_size: Vector2, title_text: String, description_text: String, accent_color: Color, _custom_icon_path: String, _generic_icon_path: String, panel_style: StyleBoxFlat, _seal_shape: String = "diamond", title_color: Color = Color(1.0, 0.94, 0.55), scale_factor: float = 1.0, border_slug: String = "") -> Control:
	var front_stylebox = _get_front_stylebox(panel_style, scale_factor)

	# Quando a textura de papel está ativa, "root" fica RECUADO pra dentro
	# (menor que a carta inteira) — assim o papel nunca precisa esticar por
	# baixo da faixa onde a borda-sprite desenha, eliminando qualquer vão
	# entre as duas camadas. No fallback (sem textura), root ocupa a carta
	# inteira como antes, já que o próprio panel_style desenha sua borda.
	var using_paper_texture = front_stylebox is StyleBoxTexture
	var paper_inset = (_PAPER_INSET * scale_factor) if using_paper_texture else 0.0
	var root_size = card_size - Vector2(paper_inset, paper_inset) * 2.0

	var root = PanelContainer.new()
	root.position = Vector2(paper_inset, paper_inset)
	root.custom_minimum_size = root_size
	root.size = root_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = true
	root.add_theme_stylebox_override("panel", front_stylebox)

	# Wrapper simples (Control puro, NÃO um Container) por fora do
	# PanelContainer: um Container reposicionaria qualquer filho seu pra
	# dentro da área de conteúdo (inset pela margem do panel_style), o que
	# faria a camada de borda ficar encolhida pra dentro do texto em vez de
	# cobrir a carta inteira até a borda de verdade.
	var wrapper = Control.new()
	wrapper.custom_minimum_size = card_size
	wrapper.size = card_size
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(root)

	var outer_margin = _TEXT_FACE_OUTER_MARGIN * scale_factor

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", outer_margin)
	margin.add_theme_constant_override("margin_right", outer_margin)
	margin.add_theme_constant_override("margin_top", outer_margin)
	margin.add_theme_constant_override("margin_bottom", outer_margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(_TEXT_FACE_VBOX_SEPARATION * scale_factor))
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)

	# --- 1. TÍTULO: Label comum direto no VBoxContainer (mesmo padrão simples
	# já usado em outros títulos do projeto, ex: rule_discard_modal.gd) — sem
	# nenhum posicionamento manual por anchors, que se mostrou frágil aqui.
	var title = Label.new()
	title.text = title_text.to_upper()
	title.custom_minimum_size = Vector2(0, _TEXT_FACE_HEADER_HEIGHT * scale_factor)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", int(22 * scale_factor))
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1.0))
	title.add_theme_constant_override("outline_size", maxi(1, int(6 * scale_factor)))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)

	# Linha divisória fina sob o cabeçalho
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, _TEXT_FACE_DIVIDER_HEIGHT)
	div.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.6)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(div)

	# --- 2. PERGAMINHO PRINCIPAL EXPANDIDO (Ocupa o restante da carta) ---
	var desc_box = PanelContainer.new()
	desc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_box.clip_contents = true
	desc_box.add_theme_stylebox_override("panel", PixelUI.make_bevel_card(Color(0.06, 0.07, 0.10, 0.95), Color(0.20, 0.24, 0.32, 0.5)))
	vb.add_child(desc_box)

	# Control simples (não Container) com clip: um Label com quebra de linha
	# automática dentro de um MarginContainer/PanelContainer propaga seu
	# tamanho mínimo pros pais quando o texto é longo, esticando a carta
	# inteira verticalmente. Um Control puro não repassa o tamanho mínimo dos
	# filhos — então a carta permanece no tamanho fixo (quadrado nas Leis,
	# retangular fixo nas Cartas) mesmo com descrições longas; o texto que não
	# couber fica clipado em vez de deformar o card.
	var desc_clip = Control.new()
	desc_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_clip.clip_contents = true
	desc_box.add_child(desc_clip)

	var desc_box_margin = _TEXT_FACE_DESC_BOX_MARGIN * scale_factor
	var desc_inset_h = _TEXT_FACE_DESC_INSET_H * scale_factor
	var desc_inset_v = _TEXT_FACE_DESC_INSET_V * scale_factor
	var header_height = _TEXT_FACE_HEADER_HEIGHT * scale_factor
	var divider_height = _TEXT_FACE_DIVIDER_HEIGHT * scale_factor
	var vbox_sep = _TEXT_FACE_VBOX_SEPARATION * scale_factor

	# Área disponível calculada de forma determinística (ver constantes no
	# topo do arquivo) — não depende da carta já estar na árvore de cena.
	var panel_margin = front_stylebox.get_margin(SIDE_LEFT)
	var available_width = root_size.x - 2.0 * panel_margin - 2.0 * outer_margin - 2.0 * desc_box_margin - 2.0 * desc_inset_h
	var desc_box_height = root_size.y - 2.0 * panel_margin - 2.0 * outer_margin - header_height - divider_height - 2.0 * vbox_sep
	var available_height = desc_box_height - 2.0 * desc_box_margin - 2.0 * desc_inset_v

	var desc = Label.new()
	desc.text = description_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.add_theme_font_size_override("font_size", int(19 * scale_factor))
	desc.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	desc.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1.0))
	desc.add_theme_constant_override("outline_size", maxi(1, int(4 * scale_factor)))
	desc.add_theme_constant_override("line_spacing", int(4 * scale_factor))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# position/size vêm por ÚLTIMO, de propósito: o Godot nunca deixa um
	# Control ficar menor que seu próprio tamanho mínimo, e esse mínimo é
	# calculado a partir das propriedades ATUAIS no momento da atribuição —
	# se size fosse setado antes do autowrap, o mínimo seria calculado como
	# uma única linha gigante (sem quebra), e o motor "corrigiria" nosso
	# tamanho pequeno de volta pra esse valor enorme, ANTES do autowrap
	# sequer existir. Com tudo configurado antes, o mínimo já considera a
	# quebra de linha corretamente.
	desc.position = Vector2(desc_inset_h, desc_inset_v)
	desc.size = Vector2(available_width, available_height)
	desc_clip.add_child(desc)

	# call_deferred: a checagem de scroll roda desacoplada da construção da
	# carta (depois que esta função já retornou "root" e o chamador já
	# anexou front_view na árvore). Assim, qualquer problema na checagem de
	# scroll fica isolado — no pior caso o scroll não ativa, mas o texto já
	# está garantidamente montado e visível independente disso.
	call_deferred("_maybe_start_description_scroll", desc, available_width, available_height)

	# Camada de borda colorida (sprite por categoria/raridade) — irmã de
	# "root" dentro do wrapper, não filha dele, então cobre a carta inteira
	# até a borda de verdade em vez de ficar restrita à área de conteúdo.
	var border_overlay = _build_border_overlay(border_slug, card_size, scale_factor)
	if border_overlay != null:
		wrapper.add_child(border_overlay)

	return wrapper

# Y do topo do Label para que as MAIÚSCULAS (altura ~5/7 do corpo na m5x7)
# fiquem centradas verticalmente numa faixa de altura h. Centralizar pelo
# get_height() deixava o texto alto demais (o espaço dos descendentes fica
# embaixo da linha).
func _caps_center_y(font: Font, fs: int, h: float) -> float:
	var cap_h: float = fs * 5.0 / 7.0
	return floor(h * 0.5 - font.get_ascent(fs) + cap_h * 0.5)

func _maybe_start_description_scroll(desc: Label, available_width: float, available_height: float) -> void:
	if desc == null or available_width <= 0.0 or available_height <= 0.0:
		return

	if _desc_scroll_tween != null and _desc_scroll_tween.is_valid():
		_desc_scroll_tween.kill()

	# get_theme_font() pode retornar nulo se a carta ainda não estiver na
	# árvore de cena (não consegue herdar a fonte do tema do projeto nesse
	# caso) — como calculamos isso ANTES da carta ser adicionada em qualquer
	# lugar, caímos de volta pra fonte carregada direto do arquivo.
	var font: Font = desc.get_theme_font("font")
	if font == null:
		font = load(_DESC_FONT_PATH)
	if font == null:
		return

	var font_size: int = desc.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 15

	var content_height = font.get_multiline_string_size(desc.text, HORIZONTAL_ALIGNMENT_CENTER, available_width, font_size).y
	var scroll_distance = content_height - available_height

	if scroll_distance <= 2.0:
		return

	const SCROLL_SPEED_PX_PER_SEC = 14.0
	var scroll_duration = scroll_distance / SCROLL_SPEED_PX_PER_SEC
	var base_top = desc.position.y

	# create_tween() exige que o nó já esteja na árvore de cena, mas esta
	# função roda durante a construção da carta (antes de qualquer add_child
	# externo). Adiamos só a criação do tween pro momento em que o nó
	# realmente entrar na árvore — a decisão acima já é toda determinística.
	if desc.is_inside_tree():
		_start_description_scroll_tween(desc, base_top, scroll_distance, scroll_duration)
	else:
		desc.ready.connect(
			func(): _start_description_scroll_tween(desc, base_top, scroll_distance, scroll_duration),
			CONNECT_ONE_SHOT
		)

func _start_description_scroll_tween(desc: Label, base_top: float, scroll_distance: float, scroll_duration: float) -> void:
	if _desc_scroll_tween != null and _desc_scroll_tween.is_valid():
		_desc_scroll_tween.kill()

	_desc_scroll_tween = desc.create_tween().set_loops()
	_desc_scroll_tween.tween_interval(3.0)
	_desc_scroll_tween.tween_property(desc, "position:y", base_top - scroll_distance, scroll_duration)\
		.set_trans(Tween.TRANS_LINEAR)
	_desc_scroll_tween.tween_interval(3.0)
	_desc_scroll_tween.tween_property(desc, "position:y", base_top, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
