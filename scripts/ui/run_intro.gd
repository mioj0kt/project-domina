class_name RunIntro
extends Node
## Abertura de run/tutorial: tela preta, a peça do jogador volta aos pedaços e se
## encaixa no nodo inicial com impacto; então o preto some com a peça já no lugar.
## Uso: await RunIntro.new().run(self, camera, world_pos_do_nodo, piece_px)
## Clique/tecla pula.

var _skip: bool = false
var _running: bool = false
var _impacted: bool = false

func _input(event: InputEvent) -> void:
	if not _running:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
		_skip = true
		Sfx.stop("vento_nascer")
	if event is InputEventMouseButton or event is InputEventKey:
		get_viewport().set_input_as_handled()

func _wait(t: float) -> void:
	var el: float = 0.0
	while el < t and not _skip:
		await get_tree().process_frame
		el += get_process_delta_time()

func run(host: Node, camera: Camera2D, world_pos: Vector2, piece_px: float) -> void:
	host.add_child(self)
	_running = true
	var black := CanvasLayer.new()
	black.layer = 150
	add_child(black)
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 1)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	black.add_child(rect)
	var flash := ColorRect.new()
	flash.color = Color(1, 0.95, 0.85, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.add_child(flash)
	var fxl := CanvasLayer.new()
	fxl.layer = 151
	add_child(fxl)
	var fx := PieceAssembleFx.new()
	fxl.add_child(fx)
	fx.setup(PixelRenderer.get_piece_texture(BoardPiece.new(Board.WHITE, false)), piece_px)

	var follow := func() -> void:
		var ct: Transform2D = host.get_viewport().get_canvas_transform()
		fx.position = ct * world_pos
		var sc: float = ct.get_scale().x
		fx.scale = Vector2(sc, sc)
	await get_tree().process_frame
	follow.call()
	await _wait(0.5)

	if not _skip:
		fx.play()
		Sfx.play("vento_nascer")
		fx.impact.connect(func(): _impacted = true)
		while not _impacted and not _skip:
			await get_tree().process_frame
			follow.call()
		if _impacted:
			Sfx.play("nascer")
			var ftw := create_tween()
			flash.color.a = 0.5
			ftw.tween_property(flash, "color:a", 0.0, 0.3)
			_shake(camera, 14.0, 0.45)
			var el := 0.0
			while el < 0.35 and not _skip:
				await get_tree().process_frame
				follow.call()
				el += get_process_delta_time()

	# some o preto (o brilho/ondas continuam por cima enquanto o mapa surge)
	var fade: float = 0.25 if _skip else 0.9
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, fade)
	var ft := 0.0
	while ft < fade:
		await get_tree().process_frame
		follow.call()
		ft += get_process_delta_time()
	if _skip:
		fx.queue_free()
	else:
		var rest := 0.0
		while rest < 0.5 and is_instance_valid(fx) and fx._t >= 0.0:
			await get_tree().process_frame
			follow.call()
			rest += get_process_delta_time()
	_running = false
	queue_free()

func _shake(camera: Camera2D, amp: float, dur: float) -> void:
	if camera == null:
		return
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(camera):
			camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp * (1.0 - k),
		0.0, 1.0, dur)
	tw.tween_callback(func():
		if is_instance_valid(camera):
			camera.offset = Vector2.ZERO)
