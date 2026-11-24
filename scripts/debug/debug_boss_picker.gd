class_name DebugBossPicker
extends PanelContainer

# Debug (DebugFlags.SHORTCUTS): painel "TESTAR CHEFE" do canto inferior direito, ao
# lado do EVENTOS e do TRANS. Uma aba por bioma com o chefe dele e um botão por
# Lei: clicar abre o duelo de Chefe direto com aquela Lei (o mesmo que as teclas
# 1-6 no mapa fazem, mas de qualquer tela e para qualquer bioma). Sem run em
# andamento (ex.: no menu), começa uma run nova antes.

# bioma -> [título da aba, nome do chefe, campo do RunManager, [[id da lei, nome], ...]]
const BOSSES: Array = [
	["floresta", "FLORESTA", "MUSGO, O ANCIÃO", "forest_boss_law_id", [
		["frog_devourer", "Sapo Devorador"], ["owl_night", "Noite da Coruja"], ["closing_forest", "A Floresta Fecha"],
		["vines", "Cipós"], ["fireflies", "Vaga-lumes"], ["hungry_roots", "Raízes Famintas"]]],
	["deserto", "DESERTO", "O FARAÓ VAIDOSO", "desert_boss_law_id", [
		["scorching_sun", "Sol Escaldante"], ["sandstorm", "Tempestade de Areia"], ["quicksand", "Areia Movediça"],
		["hourglass", "Ampulheta"], ["sarcophagi", "Sarcófagos"], ["cacti", "Cactos"]]],
	["mina", "MINA", "O GARIMPEIRO CEGO", "mine_boss_law_id", [
		["lantern", "Lampião"], ["ricochet", "Ricochete"], ["cave_in", "Desabamento"], ["rails", "Trilhos"], ["nuggets", "Garimpo"]]],
	["cume", "CUME", "O ÚLTIMO MONTANHISTA", "cume_boss_law_id", [
		["frost", "Geada"], ["ice", "Gelo Escorregadio"], ["avalanche", "Avalanche"], ["rope", "Cordada"],
		["thin_air", "Ar Rarefeito"], ["polar", "Luz Polar"]]],
	["caldeira", "CALDEIRA", "A FERREIRA DA CALDEIRA", "caldeira_boss_law_id", [
		["anvil", "Bigorna"], ["foundry", "Fundição"], ["crown_price", "Preço da Coroa"], ["lava_flow", "Escorrida"],
		["hammer", "Martelada"], ["boiling_cauldron", "Caldeirão Fervente"]]],
]
const DUEL_SCENE: String = "res://scenes/main.tscn"
const BOSS_BOARD := Vector2i(10, 10)

var _biome: String = "floresta"
var _tabs: Dictionary = {}
var _list: VBoxContainer
var _title: Label

func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(560, 0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.07, 0.10, 0.94)
	bg.border_color = Color(0.89, 0.85, 0.74)
	bg.set_border_width_all(3)
	bg.set_content_margin_all(12)
	add_theme_stylebox_override("panel", bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var head := Label.new()
	head.text = "TESTAR CHEFE"
	head.add_theme_font_size_override("font_size", 22)
	col.add_child(head)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
	for b in BOSSES:
		var t := Button.new()
		t.text = b[1]
		t.toggle_mode = true
		t.focus_mode = Control.FOCUS_NONE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_theme_font_size_override("font_size", 16)
		t.pressed.connect(_select_biome.bind(String(b[0])))
		tabs.add_child(t)
		_tabs[b[0]] = t
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	col.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)

func toggle() -> void:
	visible = not visible
	if visible:
		var cur: String = RunManager.map_biome
		_select_biome(cur if _tabs.has(cur) else _biome)

func _select_biome(biome: String) -> void:
	_biome = biome
	for k in _tabs:
		_tabs[k].button_pressed = (k == biome)
		_tabs[k].modulate = Color(1.0, 0.85, 0.35) if k == biome else Color.WHITE
	for c in _list.get_children():
		c.queue_free()
	for b in BOSSES:
		if b[0] != biome:
			continue
		_title.text = String(b[2])
		var i: int = 0
		for law in b[4]:
			i += 1
			var btn := Button.new()
			btn.text = "%d. %s   (%s)" % [i, law[1], law[0]]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(520, 44)
			btn.add_theme_font_size_override("font_size", 18)
			btn.pressed.connect(_open.bind(biome, String(b[3]), String(law[0])))
			_list.add_child(btn)

func _open(biome: String, field: String, law_id: String) -> void:
	if SceneTransition.busy:
		return
	if RunManager.map_data.is_empty():
		RunManager.start_new_run()
		RunManager.run_intro_pending = false
		RunManager.biome_intro_pending = false
	RunManager.map_biome = biome
	RunManager.set(field, law_id)
	RunManager.current_node_type = MapNode.NodeType.Chefe
	RunManager.current_board_size = BOSS_BOARD
	RunManager.current_board_layout = Board.LAYOUT_CLASSIC
	visible = false
	SceneTransition.go(DUEL_SCENE)
