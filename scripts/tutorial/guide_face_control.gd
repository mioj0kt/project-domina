class_name GuideFaceControl
extends Control

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# Rosto animado de um personagem do tutorial: O Guia (sorridente) ou o Irmão
# (maligno). Cada um é uma tira de 8 quadros de 32x32 — quadro 0 = boca
# fechada (parado), 1..6 = formas de boca da fala.

const FRAME_SIZE := 32
const FRAME_COUNT := 8
const TEXTURES := {
	"guide": "res://assets/sprites/retratos/guide_talk.png",
	"evil": "res://assets/sprites/retratos/evil_talk.png",
	# Chefes: se o sprite próprio (tira 8x 32x32, igual aos acima) ainda não existir,
	# usa o rosto do Irmão com a cor do bioma (tint) como provisório.
	"boss_floresta": "res://assets/sprites/retratos/boss_floresta_talk.png",
	"boss_deserto": "res://assets/sprites/retratos/boss_deserto_talk.png",
	"boss_mina": "res://assets/sprites/retratos/boss_mina_talk.png",
}
var fallback_tint: Color = Color.WHITE
const FALLBACK_PATH := "res://assets/sprites/retratos/evil_talk.png"
const TALK_FPS := 11.0

var who: String = "guide"
# Aura atrás do sprite (usada pelos chefes): halo pulsante, raios girando devagar
# e brasas subindo, tudo na cor `aura_color`. Desenha além dos limites do controle.
var aura: bool = false
var aura_color: Color = Color.WHITE
var talking: bool = false
var _t: float = 0.0

func setup(p_size: float, p_who: String = "guide") -> void:
	who = p_who
	custom_minimum_size = Vector2(p_size, p_size)
	size = custom_minimum_size
	# Dentro de HBox/VBox não estica: o rosto é sempre quadrado.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_redraw()

func set_who(p_who: String) -> void:
	who = p_who
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()

func _frame_index() -> int:
	if not talking:
		return 0
	# Passeia pelas bocas abertas (1..6) numa ordem que não parece repetitiva.
	var step := int(_t * TALK_FPS)
	@warning_ignore("integer_division")
	return 1 + (step * 5 + (step / 6) * 2) % 6

var _atlas_cache: Dictionary = {}

func _frame_texture(path: String, frame: int) -> Texture2D:
	var key := "%s#%d" % [path, frame]
	if not _atlas_cache.has(key):
		var at := AtlasTexture.new()
		at.atlas = load(path)
		at.region = Rect2(frame * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_atlas_cache[key] = at
	return _atlas_cache[key]

# Textura do quadro `frame` de qualquer personagem (usada pelos efeitos de tela
# cheia, que desenham o rosto gigante fora deste controle).
func texture_for(p_who: String, frame: int = 0) -> Texture2D:
	var path: String = TEXTURES.get(p_who, TEXTURES["guide"])
	return _frame_texture(path, frame)

func _draw_aura(center: Vector2, side: float) -> void:
	var u: float = side / 32.0   # 1 "pixel" do sprite
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.2)
	# Raios girando (atrás do halo).
	var rays := 10
	for k in rays:
		var ang: float = _t * 0.35 + TAU * k / rays
		var half: float = 0.11 + 0.03 * sin(_t * 1.7 + k * 1.3)
		var ray_len: float = side * (0.78 + 0.10 * sin(_t * 1.3 + k * 2.1))
		PixelBeam.beam(self, center, ang, ray_len, half * 0.7, Color(aura_color, 0.35 + 0.15 * pulse))
	# Halo em degraus (visual pixel-art): círculos concêntricos de alfa crescente.
	var steps := 6
	for i in steps:
		var r: float = side * (0.74 - i * 0.075) + pulse * u * 1.5
		PixelBeam.disc(self, center, r, Color(aura_color.lightened(i * 0.05), 0.05 + i * 0.03), maxf(u, 2.0))
	# Brasas subindo.
	for k in 12:
		var ph: float = fposmod(_t * (0.18 + 0.05 * (k % 3)) + k * 0.137, 1.0)
		var hx: float = fposmod(sin(k * 12.9898) * 43758.5453, 1.0) - 0.5
		var x: float = snappedf(center.x + hx * side * 1.0, u)
		var y: float = snappedf(center.y + side * 0.5 - ph * side * 1.15, u)
		var sz: float = u * (1.0 + float(k % 2))
		draw_rect(Rect2(x, y, sz, sz), Color(aura_color.lightened(0.45), sin(ph * PI) * 0.9))

func _draw() -> void:
	var path: String = TEXTURES.get(who, TEXTURES["guide"])
	var tint: Color = Color.WHITE
	if not ResourceLoader.exists(path):
		if not who.begins_with("boss_") or not ResourceLoader.exists(FALLBACK_PATH):
			return
		path = FALLBACK_PATH
		tint = fallback_tint
	var side: float = min(size.x, size.y)
	if aura:
		_draw_aura(size / 2.0, side)
	draw_texture_rect(_frame_texture(path, _frame_index()), Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), false, tint)
