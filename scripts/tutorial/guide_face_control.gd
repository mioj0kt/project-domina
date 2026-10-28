class_name GuideFaceControl
extends Control

# Rosto animado de um personagem do tutorial: O Guia (sorridente) ou o Irmão
# (maligno). Cada um é uma tira de 8 quadros de 32x32 — quadro 0 = boca
# fechada (parado), 1..6 = formas de boca da fala.

const FRAME_SIZE := 32
const FRAME_COUNT := 8
const TEXTURES := {
	"guide": "res://assets/sprites/guide/guide_talk.png",
	"evil": "res://assets/sprites/guide/evil_talk.png",
	# Chefes: se o sprite próprio (tira 8x 32x32, igual aos acima) ainda não existir,
	# usa o rosto do Irmão com a cor do bioma (tint) como provisório.
	"boss_floresta": "res://assets/sprites/guide/boss_floresta_talk.png",
	"boss_deserto": "res://assets/sprites/guide/boss_deserto_talk.png",
}
var fallback_tint: Color = Color.WHITE
const FALLBACK_PATH := "res://assets/sprites/guide/evil_talk.png"
const TALK_FPS := 11.0

var who: String = "guide"
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

func _draw() -> void:
	var path: String = TEXTURES.get(who, TEXTURES["guide"])
	var tint: Color = Color.WHITE
	if not ResourceLoader.exists(path):
		if not who.begins_with("boss_") or not ResourceLoader.exists(FALLBACK_PATH):
			return
		path = FALLBACK_PATH
		tint = fallback_tint
	var side: float = min(size.x, size.y)
	draw_texture_rect(_frame_texture(path, _frame_index()), Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), false, tint)
