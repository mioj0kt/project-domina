class_name PixelUI
extends RefCounted

# Painel padrão do jogo (modais, tooltips, caixas): sprite de HUD 9-slice
# (painel_mensagens) tingido pela cor de destaque. Se o sprite não existir,
# cai no painel plano antigo (make_flat_panel). bg_color só vale no fallback.
# Fundo de tooltip: sprite tooltip_fundo.png (64x40, moldura creme em fundo escuro)
# esticado em 9 fatias, ampliado por inteiro. Todos os tooltips usam este.
static func make_tooltip_panel(factor: int = 3, pad: int = 8, line_color: Color = Color.WHITE) -> StyleBox:
	if not ResourceLoader.exists(HUD_DIR + "tooltip_fundo.png"):
		return make_pixel_panel(Color(0.06, 0.08, 0.12, 0.98), Color(0.4, 0.75, 1.0), 18)
	var style = StyleBoxTexture.new()
	style.texture = hud_texture("tooltip_fundo", factor)
	var m: int = 4 * factor   # borda escura + linha creme
	style.texture_margin_left = m
	style.texture_margin_right = m
	style.texture_margin_top = m
	style.texture_margin_bottom = m
	style.content_margin_left = m + pad
	style.content_margin_right = m + pad
	style.content_margin_top = m + pad
	style.content_margin_bottom = m + pad
	# A moldura creme do sprite recebe a cor (categoria da Lei / raridade da Carta);
	# o fundo escuro quase não muda com a multiplicação.
	style.modulate_color = line_color
	return style

static func make_pixel_panel(bg_color: Color = Color(0.08, 0.09, 0.12, 0.96), border_color: Color = Color(0.28, 0.65, 1.0), padding: int = 8) -> StyleBox:
	if not ResourceLoader.exists(HUD_DIR + "painel_mensagens.png"):
		return make_flat_panel(bg_color, border_color, padding)
	var factor = 2 if padding >= 20 else 1
	var style = StyleBoxTexture.new()
	style.texture = hud_texture("painel_mensagens", factor)
	style.texture_margin_left = 6 * factor
	style.texture_margin_right = 6 * factor
	style.texture_margin_top = 6 * factor
	style.texture_margin_bottom = 9 * factor
	style.content_margin_left = padding + 6 * factor
	style.content_margin_right = padding + 6 * factor
	style.content_margin_top = padding + 6 * factor
	style.content_margin_bottom = padding + 9 * factor
	style.modulate_color = tint_from_accent(border_color)
	return style

# Caixa de diálogo estilo "RPG clássico" (à la Undertale): fundo quase preto
# ameixa e moldura clara grossa, cantos retos, sem sombra. Usada nas falas do
# Guia e dicas do tutorial.
# Azul-noite do quadro do Oráculo/Arcano (o mesmo dos painéis de pixel com acento AZUL_QUADRO).
const AZUL_QUADRO := Color(0.35, 0.6, 0.85)
const FUNDO_QUADRO := Color(0.09, 0.1, 0.14, 0.97)

static func make_dialogue_panel(border_color: Color = Color("#efe6cf"), padding: int = 16, border_px: int = 4, bg: Color = Color("#0c080f")) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(0)
	style.set_border_width_all(border_px)
	style.border_color = border_color
	style.content_margin_left = padding + border_px
	style.content_margin_right = padding + border_px
	style.content_margin_top = padding + border_px
	style.content_margin_bottom = padding + border_px
	style.anti_aliasing = false
	return style

# Gera uma caixa de diálogo plana (visual antigo)
static func make_flat_panel(bg_color: Color = Color(0.08, 0.09, 0.12, 0.96), border_color: Color = Color(0.28, 0.65, 1.0), padding: int = 8) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	
	# Cantos estritamente retos
	style.set_corner_radius_all(0)
	
	# Borda principal espessa
	style.set_border_width_all(2)
	style.border_color = border_color
	
	# Padding interno
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding

	# Sombra dura (sem blur suave)
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.shadow_size = 4
	style.shadow_offset = Vector2(3, 3)

	return style

# Aplica o visual "tomo antigo" (identidade escolhida pro jogo) a um
# PanelContainer: pergaminho ladrilhado no fundo (mesma textura que as
# cartas já usam) + uma moldura de tinta nítida com selo de cera colorido
# em cada canto, por cima. Não mexe em make_pixel_panel nem em nenhum
# outro painel — só quem chamar isso explicitamente ganha o visual novo,
# então é fácil reverter (só parar de chamar essa função).
#
# border_texture_path: uma das molduras pré-geradas (uma por cor de
# destaque), ex: "res://assets/sprites/ui/border_gold.png".
static func apply_parchment_panel(panel: PanelContainer, border_texture_path: String, border_margin: int = 16) -> void:
	var parent = panel.get_parent()
	var index_in_parent = panel.get_index()

	# Um Control comum (não Container) que vira o "envelope": ele não
	# força o tamanho dos filhos como um Container faria, então dá pra
	# empilhar fundo + painel + moldura preenchendo o retângulo inteiro
	# cada um, sem brigar entre si.
	var wrapper = Control.new()
	wrapper.custom_minimum_size = panel.custom_minimum_size
	wrapper.size_flags_horizontal = panel.size_flags_horizontal
	wrapper.size_flags_vertical = panel.size_flags_vertical
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	if parent != null:
		parent.remove_child(panel)
		parent.add_child(wrapper)
		parent.move_child(wrapper, index_in_parent)

	# 1. Fundo de pergaminho ladrilhado de verdade — usar TextureRect
	# com STRETCH_TILE em vez do modo "tile" do StyleBoxTexture, que na
	# prática esticava a imagem em vez de repeti-la.
	var bg = TextureRect.new()
	if ResourceLoader.exists("res://assets/sprites/ui/front_parchment.png"):
		bg.texture = load("res://assets/sprites/ui/front_parchment.png")
		bg.stretch_mode = TextureRect.STRETCH_TILE
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(bg)

	# 2. O painel original entra por cima do fundo, com a cor sólida
	# dele apagada (mas o content_margin original preservado, senão o
	# conteúdo real perderia o respiro interno que já tinha).
	var current_style = panel.get_theme_stylebox("panel")
	if current_style is StyleBoxFlat:
		var transparent_style: StyleBoxFlat = current_style.duplicate()
		transparent_style.bg_color = Color(0, 0, 0, 0)
		transparent_style.border_color = Color(0, 0, 0, 0)
		transparent_style.shadow_color = Color(0, 0, 0, 0)
		panel.add_theme_stylebox_override("panel", transparent_style)
	wrapper.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	if not ResourceLoader.exists(border_texture_path):
		return

	# 3. Moldura de tinta por cima de tudo.
	var border = NinePatchRect.new()
	border.texture = load(border_texture_path)
	border.patch_margin_left = border_margin
	border.patch_margin_right = border_margin
	border.patch_margin_top = border_margin
	border.patch_margin_bottom = border_margin
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(border)

# Painel com textura de fundo (ex.: tábua de madeira) esticada pra preencher
# o controle inteiro, no lugar de uma cor sólida. Diferente de
# apply_parchment_panel, não envolve o painel num wrapper novo — é só um
# StyleBoxTexture direto, então serve bem quando a arte já vem pronta no
# tamanho exato do painel (sem precisar ladrilhar).
static func make_wood_panel(texture_path: String = "res://assets/sprites/ui/panel_wood.png") -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	if ResourceLoader.exists(texture_path):
		style.texture = load(texture_path)
	# 9-slice: moldura de 16 px nativos (ver slices.json da arte).
	style.texture_margin_left = 16
	style.texture_margin_right = 16
	style.texture_margin_top = 16
	style.texture_margin_bottom = 16
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

static func make_bevel_card(base_color: Color, border_color: Color, is_pressed_or_active: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(0)

	style.set_border_width_all(2)
	style.border_color = border_color

	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	if not is_pressed_or_active:
		# Luz no topo/esquerda e sombra embaixo/direita
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_bottom = 3
		style.border_width_right = 3
		style.shadow_size = 2
		style.shadow_offset = Vector2(2, 2)
		style.shadow_color = Color(0, 0, 0, 0.7)
	else:
		# Efeito de botão pressionado / ativado
		style.border_width_top = 3
		style.border_width_left = 3
		style.border_width_bottom = 1
		style.border_width_right = 1

	return style

# Moeda de ouro: usa o sprite do ícone de dinheiro da HUD (16x16), ampliado em
# escala inteira (nearest) para o tamanho pedido, centralizado num Control.
static func make_coin_icon(size_px: float = 32.0) -> Control:
	var k: int = maxi(1, int(round(size_px / 16.0)))
	var px: float = 16.0 * float(k)
	var coin_ctrl = Control.new()
	coin_ctrl.custom_minimum_size = Vector2(px, px)
	coin_ctrl.pivot_offset = Vector2(px, px) / 2.0
	var icon = TextureRect.new()
	icon.texture = hud_texture("icone_dinheiro", 1)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin_ctrl.add_child(icon)
	return coin_ctrl

# ---------------------------------------------------------------------------
# Skin de HUD (sprites em res://assets/sprites/hud/)
# ---------------------------------------------------------------------------
const HUD_DIR := "res://assets/sprites/hud/"

# Tamanhos nativos dos botões (px) e margem de 9-slice.
const _BTN_SPRITES := {
	"p": {"h": 18, "margin": Vector4(4, 4, 4, 6)},
	"m": {"h": 24, "margin": Vector4(5, 5, 5, 7)},
	"g": {"h": 30, "margin": Vector4(5, 5, 5, 8)},
}
const _BTN_STATES := {
	"normal": "normal", "hover": "hover", "pressed": "pressionado", "disabled": "desabilitado",
}

static var _tex_cache: Dictionary = {}

# Textura do HUD ampliada por inteiro (NEAREST) e cacheada; null se não existir.
static func hud_texture(file: String, factor: int = 1, dir: String = HUD_DIR) -> Texture2D:
	var key = "%s%s@%d" % [dir, file, factor]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path = dir + file + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var base: Texture2D = load(path)
		if factor <= 1:
			tex = base
		else:
			var img = base.get_image()
			img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
			tex = ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex

# Escolhe sprite (p/m/g) e fator inteiro (1-2) que mais se aproximam da altura.
static func _pick_button_sprite(height: float) -> Array:
	var best_size = "m"
	var best_factor = 1
	var best_err = INF
	for size_key in ["p", "m", "g"]:
		var sh: float = _BTN_SPRITES[size_key]["h"]
		for f in [1, 2]:
			var err = absf(height - sh * f) / maxf(height, 1.0)
			if err < best_err - 0.001:
				best_err = err
				best_size = size_key
				best_factor = f
	return [best_size, best_factor]

# Cor de tinta a partir da cor de destaque usada antes (borda) — suave, pra
# não escurecer demais o marrom do sprite.
static func tint_from_accent(accent: Color) -> Color:
	return Color(1, 1, 1, 1).lerp(accent, 0.45)

static func make_button_style(size_key: String, factor: int, state_file: String, tint: Color) -> StyleBoxTexture:
	var info = _BTN_SPRITES[size_key]
	var style = StyleBoxTexture.new()
	style.texture = hud_texture("botao_%s_%s" % [size_key, state_file], factor)
	var m: Vector4 = info["margin"]
	style.texture_margin_left = m.x * factor
	style.texture_margin_top = m.y * factor
	style.texture_margin_right = m.z * factor
	style.texture_margin_bottom = m.w * factor
	style.content_margin_left = (m.x + 3) * factor
	style.content_margin_right = (m.z + 3) * factor
	style.content_margin_top = (m.y + 1) * factor
	style.content_margin_bottom = (m.w - 1) * factor
	style.modulate_color = tint
	style.draw_center = true
	return style

# Aplica o skin de botão (4 estados) a um Button. accent tinge o sprite (ex.:
# verde = confirmar, vermelho = cancelar); Color.WHITE mantém o marrom puro.
static func skin_button(btn: Button, accent: Color = Color.WHITE, force_size: String = "", icon: String = "") -> void:
	var picked = _pick_button_sprite(btn.custom_minimum_size.y if btn.custom_minimum_size.y > 0.0 else 30.0)
	var size_key: String = force_size if force_size != "" else picked[0]
	var factor: int = picked[1]
	var tint = tint_from_accent(accent) if accent != Color.WHITE else Color.WHITE
	for state in _BTN_STATES:
		var st = make_button_style(size_key, factor, _BTN_STATES[state], tint if state != "disabled" else Color.WHITE)
		btn.add_theme_stylebox_override(state, st)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.96, 0.89, 0.72))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.65))
	if icon != "":
		set_button_icon(btn, icon)
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.75, 0.5))
	btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.47, 0.42))
	Juice.hover_pop(btn)   # game juice: cresce no hover, afunda no clique

# Ícone do HUD (icone_*.png / moeda_pequena) à esquerda do texto do botão,
# ampliado por inteiro (2x quando o botão tem altura >= 36) e sem filtro.
static func set_button_icon(btn: Button, file: String) -> void:
	var k := 2 if btn.custom_minimum_size.y >= 36.0 else 1
	var tex = hud_texture(file, k)
	if tex == null:
		return
	btn.icon = tex
	btn.expand_icon = false
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_constant_override("icon_max_width", 16 * k)
	btn.add_theme_constant_override("h_separation", 6 * k)
	btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# Painel de HUD 9-slice (painel_dinheiro / painel_cartas / painel_leis /
# painel_mensagens / painel_objetivos / painel_partida).
static func make_hud_panel(file: String, margin: int = 6, factor: int = 1) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = hud_texture(file, factor)
	style.texture_margin_left = margin * factor
	style.texture_margin_right = margin * factor
	style.texture_margin_top = margin * factor
	style.texture_margin_bottom = (margin + 3) * factor
	style.content_margin_left = (margin + 2) * factor
	style.content_margin_right = (margin + 2) * factor
	style.content_margin_top = (margin + 1) * factor
	style.content_margin_bottom = (margin + 2) * factor
	return style

# Ícone do HUD (icone_*.png / moeda*.png) ampliado por inteiro, sem filtro.
static func make_hud_icon(file: String, px: float = 32.0) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = hud_texture(file, 1)
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# Painel com slot de ícone à esquerda (painel_dinheiro / painel_cartas /
# painel_leis): a parte do ícone fica sem esticar, o resto estica.
static func make_hud_icon_panel(file: String, icon_slot: int = 30, factor: int = 1, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = hud_texture(file, factor)
	style.texture_margin_left = icon_slot * factor
	style.texture_margin_right = 6 * factor
	style.texture_margin_top = 6 * factor
	style.texture_margin_bottom = 8 * factor
	style.content_margin_left = (icon_slot + 4) * factor
	style.content_margin_right = 8 * factor
	style.content_margin_top = 4 * factor
	style.content_margin_bottom = 6 * factor
	style.modulate_color = tint
	return style


# Slider vertical pixel art minimalista: trilho fino ameixa com borda de 2 px e
# "pega" retangular creme/dourada, sem cantos arredondados nem setas.
static func style_scrollbar(scroll: ScrollContainer) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 14
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#241a2b")
	track.set_border_width_all(2)
	track.border_color = Color("#5a4561")
	track.set_corner_radius_all(0)
	track.content_margin_left = 0
	track.content_margin_right = 0
	var grab := func(fill: Color, edge: Color) -> StyleBoxFlat:
		var g := StyleBoxFlat.new()
		g.bg_color = fill
		g.set_border_width_all(2)
		g.border_color = edge
		g.set_corner_radius_all(0)
		return g
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab.call(Color("#cfc3a6"), Color("#7c6489")))
	bar.add_theme_stylebox_override("grabber_highlight", grab.call(Color("#efe6cf"), Color("#d9a441")))
	bar.add_theme_stylebox_override("grabber_pressed", grab.call(Color("#d9a441"), Color("#9a6f2a")))


# Tema global dos sliders (vertical e horizontal) no mesmo pixel art do
# Grimório. Aplicado na janela raiz: vale para inventário, loja, apostas etc.
static func make_scroll_theme() -> Theme:
	var th := Theme.new()
	for kind in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("#241a2b")
		track.set_border_width_all(2)
		track.border_color = Color("#5a4561")
		track.set_corner_radius_all(0)
		if kind == "VScrollBar":
			track.content_margin_left = 7
			track.content_margin_right = 7
		else:
			track.content_margin_top = 7
			track.content_margin_bottom = 7
		th.set_stylebox("scroll", kind, track)
		th.set_stylebox("scroll_focus", kind, track)
		var pairs := {
			"grabber": [Color("#cfc3a6"), Color("#7c6489")],
			"grabber_highlight": [Color("#efe6cf"), Color("#d9a441")],
			"grabber_pressed": [Color("#d9a441"), Color("#9a6f2a")],
		}
		for name in pairs:
			var g := StyleBoxFlat.new()
			g.bg_color = pairs[name][0]
			g.set_border_width_all(2)
			g.border_color = pairs[name][1]
			g.set_corner_radius_all(0)
			th.set_stylebox(name, kind, g)
	return th
