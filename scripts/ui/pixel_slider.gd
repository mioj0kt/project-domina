class_name PixelSlider
extends HSlider

# Slider em pixel art: trilho em blocos (segmentos) com contorno escuro, blocos
# cheios em dourado até o valor, e um cursor quadrado cor de creme.

const INK := Color("#241a2b")
const PLUM_D := Color("#3a2b41")
const PLUM_M := Color("#5a4561")
const GOLD := Color("#d9a441")
const GOLD_L := Color("#f2cf7a")
const GOLD_D := Color("#9a6f2a")
const CREAM := Color("#efe6cf")
const CREAM_D := Color("#cfc3a6")
const SEG_W: float = 14.0
const SEG_GAP: float = 4.0
const BAR_H: float = 22.0
const KNOB_W: float = 18.0
const KNOB_H: float = 40.0

var _hover: bool = false

func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, 48.0)
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("slider", empty)
	add_theme_stylebox_override("grabber_area", empty)
	add_theme_stylebox_override("grabber_area_highlight", empty)
	var blank := ImageTexture.create_from_image(Image.create_empty(int(KNOB_W), 1, false, Image.FORMAT_RGBA8))
	add_theme_icon_override("grabber", blank)
	add_theme_icon_override("grabber_highlight", blank)
	add_theme_icon_override("grabber_disabled", blank)
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())
	value_changed.connect(func(_v): queue_redraw())
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var cy: float = size.y * 0.5
	var inner_x0: float = KNOB_W * 0.5
	var inner_w: float = w - KNOB_W
	var r: float = 0.0
	if max_value > min_value:
		r = clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
	# moldura escura do trilho
	var bar := Rect2(inner_x0 - 6.0, cy - BAR_H * 0.5 - 4.0, inner_w + 12.0, BAR_H + 8.0)
	draw_rect(bar, INK)
	draw_rect(bar.grow(-4.0), PLUM_D)
	# segmentos
	var n: int = maxi(1, int(floorf((inner_w + SEG_GAP) / (SEG_W + SEG_GAP))))
	var seg_w: float = (inner_w - SEG_GAP * float(n - 1)) / float(n)
	var filled: int = int(round(r * float(n)))
	for i in range(n):
		var x: float = inner_x0 + float(i) * (seg_w + SEG_GAP)
		var seg := Rect2(x, cy - BAR_H * 0.5 + 2.0, seg_w, BAR_H - 4.0)
		if i < filled:
			draw_rect(seg, GOLD_D)
			draw_rect(Rect2(seg.position, Vector2(seg.size.x, seg.size.y - 4.0)), GOLD)
			draw_rect(Rect2(seg.position, Vector2(seg.size.x, 4.0)), GOLD_L)
		else:
			draw_rect(seg, PLUM_M.darkened(0.25))
			draw_rect(Rect2(seg.position, Vector2(seg.size.x, 4.0)), PLUM_M)
	# cursor quadrado
	var kx: float = clampf(inner_x0 + r * inner_w, inner_x0, inner_x0 + inner_w)
	var knob := Rect2(kx - KNOB_W * 0.5, cy - KNOB_H * 0.5, KNOB_W, KNOB_H)
	draw_rect(knob.grow(4.0), INK)
	draw_rect(knob, CREAM_D)
	draw_rect(Rect2(knob.position, Vector2(KNOB_W, KNOB_H - 6.0)), CREAM if not _hover else Color.WHITE)
	draw_rect(Rect2(knob.position + Vector2(KNOB_W * 0.5 - 2.0, 8.0), Vector2(4.0, KNOB_H - 22.0)), GOLD_D)
