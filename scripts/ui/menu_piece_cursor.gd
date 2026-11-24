class_name MenuPieceCursor
extends Control
## A peça do jogador que acompanha o mouse pelos botões de uma tela (o mesmo
## "charme" do tabuleiro do menu inicial, para os outros menus e modais): ela
## fica parada do lado do botão ativo e, quando o mouse (ou o foco) passa para
## outro botão, pula até ele num arco, com sombra no chão e "amassada" ao pousar.
## No clique dá um pulinho no lugar.
##
## Uso mais simples — vigia TODOS os botões de uma tela/modal, inclusive os que
## forem criados depois (modais que remontam o conteúdo a cada abertura):
##     MenuPieceCursor.auto(self)
## Botões pequenos (setas, X, engrenagem) ficam de fora pelo tamanho; para tirar
## um botão específico: botao.set_meta("no_piece", true).
## Ou só alguns alvos: MenuPieceCursor.attach(self, [btn_a, btn_b]).

const HOP_SEC: float = 0.17
const MIN_W: float = 110.0                 # botões mais estreitos que isso não recebem a peça
const GAP: float = 10.0                    # distância entre a peça e a borda do botão

var _root: Node = null                     # auto(): tudo que entrar embaixo dele é vigiado
var _targets: Array = []
var _cur: Control = null
var _pos := Vector2.ZERO                   # centro da peça (sem o pulo), em coordenadas do canvas
var _lift: float = 0.0
var _squash: float = 0.0
var _hopping: bool = false
var _alpha: float = 0.0
var _t: float = 0.0
var _px: float = 3.0                       # escala de pixel da peça (inteira)
var _tw: Tween = null


static func auto(root: Node) -> MenuPieceCursor:
	var c := MenuPieceCursor.new()
	c._root = root
	root.add_child(c)
	c._scan(root)
	return c


static func attach(host: Node, targets: Array) -> MenuPieceCursor:
	var c := MenuPieceCursor.new()
	host.add_child(c)
	for t in targets:
		c.track(t)
	return c


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	position = Vector2.ZERO


func _ready() -> void:
	if _root != null and not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _root != null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.node_added.is_connected(_on_node_added):
			tree.node_added.disconnect(_on_node_added)


func _scan(n: Node) -> void:
	for ch in n.get_children():
		if ch is BaseButton:
			track(ch)
		_scan(ch)


func _on_node_added(n: Node) -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	if n is BaseButton and _root != null and is_instance_valid(_root) and _root.is_ancestor_of(n):
		track(n)


func track(t: Control) -> void:
	if t == null or t in _targets or t.has_meta("no_piece"):
		return
	_targets.append(t)
	if t.has_meta("piece_tracked"):
		return   # saiu e voltou para a árvore (botão movido de lugar): os sinais já estão ligados
	t.set_meta("piece_tracked", true)
	_make_slab(t)
	t.mouse_entered.connect(_go.bind(t))
	t.focus_entered.connect(_go.bind(t))
	if t is BaseButton:
		t.pressed.connect(_bump.bind(t))
	t.tree_exiting.connect(func():
		if is_instance_valid(self):
			_targets.erase(t)
			if _cur == t:
				_cur = null)


# Botões de tamanho normal viram placas do menu, com o encaixe onde a peça pousa.
func _make_slab(t: Control) -> void:
	if not (t is Button) or t.has_meta("slab"):
		return
	var cms: Vector2 = t.custom_minimum_size
	if cms.y < 40.0 or (cms.x > 0.0 and cms.x < MIN_W):
		return
	PixelUI.skin_slab_button(t, t.get_meta("skin_accent", Color.WHITE), String(t.get_meta("skin_icon", "")))


# ------------------------------------------------------------------ alvos ----

func _usable(t: Control) -> bool:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree() or not t.is_visible_in_tree():
		return false
	if t.has_meta("no_piece") or t.size.x < MIN_W:
		return false
	if t is BaseButton and t.disabled:
		return false
	# CanvasLayer escondido (modal fechado) também esconde o botão
	var p: Node = t.get_parent()
	while p != null:
		if p is CanvasLayer and not p.visible:
			return false
		if p is ScrollContainer and not p.get_global_rect().grow(4.0).encloses(t.get_global_rect()):
			return false   # rolado para fora da área visível
		p = p.get_parent()
	return true


func _piece_size() -> Vector2:
	var tex: Texture2D = PieceSkin.player_texture()
	if tex == null:
		return Vector2(48, 48)
	return Vector2(tex.get_width(), tex.get_height()) * _px


# Onde a peça senta junto de `t` (centro). Botão sozinho na linha: do lado esquerdo
# (ou direito, se não couber). Botões lado a lado (abas, fileira de opções): em pé
# em cima do botão, no canto esquerdo — assim a peça nunca fica "entre" dois botões.
func _anchor(t: Control) -> Vector2:
	if t.has_meta("slab"):
		# placa: a peça pousa dentro do encaixe, na mesma escala dele
		_px = SlabStyleBox.socket_scale(t.size.y)
		return (t.get_global_transform() * SlabStyleBox.socket_center(t.size)).round()
	var r: Rect2 = t.get_global_rect()
	var tex: Texture2D = PieceSkin.player_texture()
	var th: float = float(tex.get_height()) if tex != null else 16.0
	_px = maxf(1.0, roundf(clampf(r.size.y * 0.8, 34.0, 64.0) / th))
	var ps: Vector2 = _piece_size()
	var cy: float = r.get_center().y
	var top := Vector2(r.position.x + ps.x * 0.5 + 8.0, r.position.y - ps.y * 0.32).round()
	if _has_row_mate(t, r):
		return top
	var left := Vector2(r.position.x - GAP - ps.x * 0.5, cy)
	if _free(left, ps, t):
		return left.round()
	var right := Vector2(r.end.x + GAP + ps.x * 0.5, cy)
	if _free(right, ps, t):
		return right.round()
	return top


func _has_row_mate(t: Control, r: Rect2) -> bool:
	for o in _targets:
		if o == t or not is_instance_valid(o) or not o.is_visible_in_tree() or o.size.x < MIN_W:
			continue
		var orr: Rect2 = o.get_global_rect()
		var overlap: float = minf(r.end.y, orr.end.y) - maxf(r.position.y, orr.position.y)
		if overlap > r.size.y * 0.5 and absf(orr.get_center().x - r.get_center().x) < r.size.x + orr.size.x:
			return true
	return false


func _free(c: Vector2, ps: Vector2, self_t: Control) -> bool:
	var pr := Rect2(c - ps * 0.5, ps).grow(2.0)
	if not get_viewport_rect().encloses(pr):
		return false
	for o in _targets:
		if o != self_t and is_instance_valid(o) and o.is_visible_in_tree() and o.get_global_rect().intersects(pr):
			return false
	return true


# A peça precisa estar no MESMO CanvasLayer do botão (senão fica por baixo do modal
# ou com as coordenadas trocadas): muda de camada junto com o alvo.
func _layer_of(n: Node) -> Node:
	var p: Node = n.get_parent()
	while p != null:
		if p is CanvasLayer:
			return p
		p = p.get_parent()
	return null

func _follow_layer(t: Control) -> void:
	var want: Node = _layer_of(t)
	if want == _layer_of(self):
		return
	var dest: Node = want if want != null else (_root if _root != null and is_instance_valid(_root) else t.get_tree().current_scene)
	if dest != null and dest != get_parent():
		reparent.call_deferred(dest, false)
		_alpha = 0.0

func _go(t: Control) -> void:
	if not _usable(t) or t == _cur:
		return
	_follow_layer(t)
	var to: Vector2 = _anchor(t)
	var first: bool = _cur == null or _alpha < 0.05
	_cur = t
	if first:
		_pos = to
		_lift = 0.0
		return
	_hop(to)


func _hop(to: Vector2) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var from: Vector2 = _pos
	var dist: float = from.distance_to(to)
	if dist < 2.0:
		return
	var h: float = clampf(dist * 0.22, 14.0, 70.0)
	var dur: float = HOP_SEC + minf(dist / 2600.0, 0.18)
	_hopping = true
	_tw = create_tween()
	_tw.tween_method(func(k: float) -> void:
		var dest: Vector2 = _anchor(_cur) if _usable(_cur) else to   # o botão pode se mexer no meio do pulo
		_pos = from.lerp(dest, k)
		_lift = sin(k * PI) * h, 0.0, 1.0, dur)
	_tw.tween_callback(func() -> void:
		_hopping = false
		_lift = 0.0
		Sfx.play("salto", -6.0))
	_tw.tween_method(func(k: float) -> void: _squash = sin(k * PI), 0.0, 1.0, 0.09)
	_tw.tween_callback(func() -> void: _squash = 0.0)


# Clique: pulinho no lugar (a ação do botão roda na hora, sem esperar a peça).
func _bump(t: Control) -> void:
	if t != _cur or _hopping or _alpha < 0.5:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(func(k: float) -> void: _lift = sin(k * PI) * 12.0, 0.0, 1.0, 0.14)
	_tw.tween_method(func(k: float) -> void: _squash = sin(k * PI), 0.0, 1.0, 0.08)
	_tw.tween_callback(func() -> void:
		_lift = 0.0
		_squash = 0.0)


# --------------------------------------------------------------- quadro a quadro ----

func _process(delta: float) -> void:
	_t += delta
	size = get_viewport_rect().size
	global_position = Vector2.ZERO
	var ok: bool = _usable(_cur)
	if not ok:
		_cur = null
		# sem botão ativo (tela acabou de abrir / o modal reabriu): senta no botão
		# disponível mais perto do mouse
		var best: Control = null
		var best_d: float = INF
		var mouse: Vector2 = get_viewport().get_mouse_position()
		for t in _targets:
			if _usable(t):
				var d: float = t.get_global_rect().get_center().distance_squared_to(mouse)
				if d < best_d:
					best_d = d
					best = t
		if best != null:
			_cur = best
			_follow_layer(best)
			_pos = _anchor(best)
			_lift = 0.0
			ok = true
	elif not _hopping:
		_pos = _anchor(_cur)   # acompanha o botão se o layout mexer (pop, rolagem)
	_alpha = move_toward(_alpha, 1.0 if ok else 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var tex: Texture2D = PieceSkin.player_texture()
	if tex == null:
		return
	var u: float = _px
	var sz := Vector2(tex.get_width(), tex.get_height()) * u
	# no encaixe da placa ela fica assentada (sem balançar e sem sombra, como no menu)
	var seated: bool = _cur != null and is_instance_valid(_cur) and _cur.has_meta("slab")
	var bob: float = 0.0 if (seated or _hopping or _lift > 0.0) else roundf(sin(_t * 2.6) * 1.0) * u * 0.5
	var base: Vector2 = _pos.round()
	# sombra no chão (encolhe com a altura do pulo)
	var air: float = clampf(_lift / 40.0, 0.0, 1.2)
	if not seated or _lift > 0.5:
		draw_set_transform(base + Vector2(0, sz.y * 0.42), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, sz.x * 0.36 * (1.0 - 0.3 * air), Color(0, 0, 0, 0.32 * _alpha))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var s := Vector2(sz.x * (1.0 + 0.10 * _squash), sz.y * (1.0 - 0.12 * _squash))
	var c: Vector2 = base - Vector2(0, roundf((_lift + bob) / u) * u)
	draw_texture_rect(tex, Rect2((c - s * 0.5 + Vector2(0, s.y * 0.06 * _squash)).round(), s.round()), false, Color(1, 1, 1, _alpha))
