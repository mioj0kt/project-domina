class_name AlertBadge
extends Control
## Selo de aviso "!" em pixel art (balãozinho dourado pulsando e quicando de leve).
## Usado no botão do Grimório quando dá para gastar Coroas lá.
##     AlertBadge.attach(botao)            -> no canto de cima à direita do botão
##     var b := AlertBadge.new(); pai.add_child(b); b.position = ...

const C_OUT := Color("1f161d")
const C_GOLD := Color("f0d27a")
const C_GOLD_SH := Color("c99a3a")
const C_HI := Color("fff3c4")
const U: float = 3.0                  # tamanho do pixel
const W: int = 9                      # largura em pixels de arte
const H: int = 11                     # altura em pixels de arte (com o biquinho)

var _t: float = 0.0


static func attach(ctrl: Control, offset: Vector2 = Vector2(-10, -14)) -> AlertBadge:
	var b := AlertBadge.new()
	ctrl.add_child(b)
	b.position = Vector2(ctrl.size.x - W * U * 0.5, 0) + offset
	ctrl.resized.connect(func():
		if is_instance_valid(b):
			b.position = Vector2(ctrl.size.x - W * U * 0.5, 0) + offset)
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H) * U
	size = custom_minimum_size
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _px(x: float, y: float, w: float, h: float, c: Color, oy: float) -> void:
	draw_rect(Rect2(Vector2(x, y + oy) * U, Vector2(w, h) * U), c)


func _draw() -> void:
	var oy: float = roundf(sin(_t * 4.0) * 0.6)          # quica 1 pixel
	var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
	var fill: Color = C_GOLD_SH.lerp(C_GOLD, pulse)
	# contorno (cantos cortados) + biquinho embaixo
	_px(1, 0, W - 2, 9, C_OUT, oy)
	_px(0, 1, W, 7, C_OUT, oy)
	_px(3, 9, 3, 1, C_OUT, oy)
	_px(4, 10, 1, 1, C_OUT, oy)
	# corpo
	_px(1, 1, W - 2, 7, fill, oy)
	_px(2, 1, W - 4, 1, C_HI, oy)
	_px(4, 8, 1, 1, fill, oy)
	_px(4, 9, 1, 1, fill, oy)
	# "!"
	_px(4, 2, 1, 3, C_OUT, oy)
	_px(4, 6, 1, 1, C_OUT, oy)
