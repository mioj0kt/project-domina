class_name BossUnlockModal
extends CanvasLayer
## Tela da 1ª vitória sobre o Chefe de um bioma: mostra as Leis e Cartas que
## acabaram de ser liberadas no Grimório (MetaProgress.claim_boss_first_win).
## As cartas entram viradas e se revelam uma a uma.

signal closed

const C_GOLD := Color(1.0, 0.84, 0.3)
const C_CREAM := Color(0.94, 0.9, 0.81)
const RULE_SCALE: float = 0.6
const CARD_SCALE: float = 1.0

var _data: Dictionary
var _rule_tip: RuleCardTooltip
var _card_tip: ActionCardTooltip
var _btn: Button


func _init(data: Dictionary) -> void:
	_data = data
	layer = 140


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)

	var title := Label.new()
	title.text = "PRIMEIRA VITÓRIA SOBRE O CHEFE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_GOLD)
	title.add_theme_color_override("font_outline_color", Color("1f161d"))
	title.add_theme_constant_override("outline_size", 8)
	v.add_child(title)

	var biome: String = String(_data.get("biome", ""))
	var sub := Label.new()
	sub.text = "Bioma vencido: %s. Novas Leis e Cartas entram no seu Grimório." % String(RunManager.BIOME_TITLES.get(biome, biome.to_upper()))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", C_CREAM)
	v.add_child(sub)

	_rule_tip = RuleCardTooltip.new()
	_card_tip = ActionCardTooltip.new()

	var delay: float = 0.4
	var rules: Array = _data.get("rules", [])
	if not rules.is_empty():
		v.add_child(_section("LEIS"))
		var row := _row(28)
		v.add_child(row)
		for r in rules:
			var vis := RuleCardVisual.new(r, _rule_tip, false, RULE_SCALE)
			row.add_child(vis)
			vis.play_flip_reveal(delay)
			delay += 0.18

	var cards: Array = _data.get("cards", [])
	if not cards.is_empty():
		v.add_child(_section("CARTAS"))
		var row2 := _row(20)
		v.add_child(row2)
		for c in cards:
			var cv := ActionCardVisual.new(c, false, CARD_SCALE)
			cv.mouse_filter = Control.MOUSE_FILTER_STOP
			cv.mouse_entered.connect(func():
				_card_tip.show_tooltip(c, cv.global_position + Vector2(ActionCardVisual.CARD_WIDTH * CARD_SCALE / 2.0, 0.0)))
			cv.mouse_exited.connect(func(): _card_tip.hide_tooltip())
			row2.add_child(cv)
			cv.play_flip_reveal(delay)
			delay += 0.14

	if int(_data.get("coroas", 0)) > 0:
		var extra := Label.new()
		extra.text = "Você já tinha quase tudo liberado: +%d COROAS no lugar do que faltou." % int(_data["coroas"])
		extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		extra.add_theme_font_size_override("font_size", 22)
		extra.add_theme_color_override("font_color", C_GOLD)
		v.add_child(extra)

	_btn = Button.new()
	_btn.text = "CONTINUAR"
	_btn.custom_minimum_size = Vector2(320, 64)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.add_theme_font_size_override("font_size", 28)
	PixelUI.skin_button(_btn, Color(0.3, 0.9, 0.45), "", "icone_confirmar")
	_btn.pressed.connect(_close)
	_btn.disabled = true
	v.add_child(_btn)

	add_child(_rule_tip)
	add_child(_card_tip)

	Sfx.play("vitoria")
	await get_tree().create_timer(delay + 0.3).timeout
	if is_instance_valid(_btn):
		_btn.disabled = false


func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(C_CREAM, 0.7))
	return l


func _row(sep: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", sep)
	return r


func _close() -> void:
	if _rule_tip != null and _rule_tip.has_method("hide_tooltip"):
		_rule_tip.call("hide_tooltip")
	if _card_tip != null:
		_card_tip.hide_tooltip()
	closed.emit()
	queue_free()
