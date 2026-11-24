class_name DebugEventPicker
extends PanelContainer

# Debug (DebugFlags.SHORTCUTS): painel "TESTAR EVENTO" do canto inferior direito, ao lado
# do TRANS. Lista todos os eventos do jogo separados por bioma; clicar num deles abre
# a tela do evento direto com ele. Sem run em andamento (ex.: no menu), começa uma run
# nova no bioma do evento, para o "SEGUIR VIAGEM" voltar a um mapa coerente.

const BIOMES: Array = [["floresta", "FLORESTA"], ["deserto", "DESERTO"], ["mina", "MINA"], ["cume", "CUME"], ["caldeira", "CALDEIRA"]]
const EVENT_SCENE: String = "res://scenes/event_view.tscn"

var _events: Array = []          # cache de EventView._build_events()
var _biome: String = "floresta"
var _tabs: Dictionary = {}       # bioma -> botão da aba
var _list: VBoxContainer
var _count: Label

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
	var title := Label.new()
	title.text = "TESTAR EVENTO"
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
	for b in BIOMES:
		var t := Button.new()
		t.text = b[1]
		t.toggle_mode = true
		t.focus_mode = Control.FOCUS_NONE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_theme_font_size_override("font_size", 16)
		t.pressed.connect(_select_biome.bind(String(b[0])))
		tabs.add_child(t)
		_tabs[b[0]] = t
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 16)
	_count.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	col.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

# Abre/fecha. Na primeira vez lê a lista de eventos e já seleciona o bioma atual.
func toggle() -> void:
	visible = not visible
	if not visible:
		return
	if _events.is_empty():
		_load_events()
	var cur: String = RunManager.map_biome
	_select_biome(cur if _tabs.has(cur) else _biome)

func _load_events() -> void:
	var ev: EventView = EventView.new()   # só para ler os dados; nunca entra na árvore
	_events = ev._build_events()
	ev.free()

func _select_biome(biome: String) -> void:
	_biome = biome
	for k in _tabs:
		_tabs[k].button_pressed = (k == biome)
		_tabs[k].modulate = Color(1.0, 0.85, 0.35) if k == biome else Color.WHITE
	for c in _list.get_children():
		c.queue_free()
	var n: int = 0
	for e in _events:
		if String(e.get("biome", "floresta")) != biome:
			continue
		n += 1
		var id: String = String(e["id"])
		var b := Button.new()
		var cut: String = "" if EventStage.supports(e) else "  (sem cutscene)"
		b.text = "%s\n%s%s" % [String(e["title"]), id, cut]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(520, 56)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_open.bind(id, biome))
		_list.add_child(b)
	_count.text = "%d eventos" % n

func _open(id: String, biome: String) -> void:
	if SceneTransition.busy:
		return
	if RunManager.map_data.is_empty():
		# sem run: começa uma no bioma do evento (sem as telas de introdução)
		RunManager.start_new_run()
		RunManager.map_biome = biome
		RunManager.run_intro_pending = false
		RunManager.biome_intro_pending = false
	EventView.debug_next_event_id = id
	visible = false
	SceneTransition.go(EVENT_SCENE)
