class_name NewBadge
extends Control
## Selo dourado "NOVA" em pixel art, pendurado no topo de uma Lei/Carta que o
## jogador nunca levou para uma run (MetaProgress.is_new). Pisca devagar e tem
## um brilho que atravessa de tempos em tempos.

const FONT := preload("res://assets/fonts/m5x7.ttf")
const PIX: float = 2.0
const FS: int = 32
const C_OUT := Color("1f161d")
const C_GOLD := Color("f0d27a")
const C_GOLD_HI := Color("f8e6a0")
const C_GOLD_SH := Color("c99a3a")

var text: String = "NOVA"
var _t: float = 0.0


## Prende o selo no topo de `visual` se o item for novo. Devolve o selo (ou null).
static func attach(visual: Control, is_rule: bool, id: String, label: String = "NOVA") -> NewBadge:
	if visual == null or MetaProgress == null or not MetaProgress.is_new(is_rule, id):
		return null
	var b := NewBadge.new()
	b.text = label
	visual.add_child(b)
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5
	tooltip_text = ""


func _ready() -> void:
	var tw: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	size = Vector2(roundf((tw + PIX * 12.0) / PIX) * PIX, PIX * 15.0)
	_place()
	var p := get_parent()
	if p is Control:
		(p as Control).resized.connect(_place)


func _place() -> void:
	var p := get_parent() as Control
	if p == null:
		return
	var w: float = maxf(p.size.x, p.custom_minimum_size.x)
	position = Vector2(roundf((w - size.x) * 0.5 / PIX) * PIX, -roundf(size.y * 0.55 / PIX) * PIX)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var u: float = PIX
	var w: float = size.x
	var h: float = size.y
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.5)
	# contorno com cantos cortados + espessura embaixo
	draw_rect(Rect2(Vector2(u, 0), Vector2(w - u * 2.0, h)), C_OUT)
	draw_rect(Rect2(Vector2(0, u), Vector2(w, h - u * 2.0)), C_OUT)
	var body := C_GOLD_SH.lerp(C_GOLD, 0.55 + 0.45 * pulse)
	draw_rect(Rect2(Vector2(u, u), Vector2(w - u * 2.0, h - u * 2.0)), body)
	draw_rect(Rect2(Vector2(u, h - u * 4.0), Vector2(w - u * 2.0, u * 2.0)), C_GOLD_SH.darkened(0.15))
	draw_rect(Rect2(Vector2(u * 2.0, u), Vector2(w - u * 4.0, u)), C_GOLD_HI)
	# brilho diagonal que atravessa a cada ~2,5 s
	var k: float = fmod(_t, 2.5) / 0.6
	if k < 1.0:
		var x: float = roundf(lerpf(-u * 6.0, w + u * 2.0, k) / u) * u
		for i in range(int((h - u * 2.0) / u)):
			var yy: float = u + i * u
			var xx: float = x - i * u
			if xx > u and xx < w - u * 3.0:
				draw_rect(Rect2(Vector2(xx, yy), Vector2(u * 2.0, u)), Color(1, 1, 1, 0.55))
	# texto
	var tw: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	var ty: float = (h - u * 2.0) * 0.5 + (FONT.get_ascent(FS) - FONT.get_descent(FS)) * 0.5
	draw_string(FONT, Vector2(roundf((w - tw) * 0.5), roundf(ty)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, C_OUT)
