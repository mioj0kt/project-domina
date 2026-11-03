class_name MultiCoinFlipView
extends Node2D

# Mostra N moedas enfileiradas e centralizadas, jogando UMA de cada vez
# (não todas ao mesmo tempo) — cada moeda já resolvida continua visível
# na tela enquanto a próxima gira, então no final as N aparecem lado a
# lado com seus resultados. Um clique pula só a moeda ATUAL, não a
# sequência inteira (chame skip_current(), não skip de todas de uma vez).

signal sequence_completed(results: Array)

const SPACING_FACTOR: float = 1.4

var coins: Array[CoinFlipView] = []
var current_index: int = -1

var white_sprite_path: String = "res://assets/sprites/pieces/white.png"
var black_sprite_path: String = "res://assets/sprites/pieces/black.png"
# Cada moeda é favorável quando cai na cor do time beneficiado.
var favorable_is_white: bool = true
var win_text: String = "BRANCA!"
var lose_text: String = "PRETA!"

func play_sequence(center: Vector2, count: int, coin_size: float = 64.0) -> Array:
	clear()

	var spacing = coin_size * SPACING_FACTOR
	var start_x = center.x - (spacing * (count - 1)) / 2.0
	for i in range(count):
		var coin = CoinFlipView.new()
		add_child(coin)
		coin.set_side_textures(white_sprite_path, black_sprite_path)
		coin.favorable_is_white = favorable_is_white
		coin.win_text = win_text
		coin.lose_text = lose_text
		# Fica parada mostrando o resultado (não some sozinha) — só
		# desaparece quando clear() for chamado, no final da sequência
		# inteira, não logo depois do próprio resultado dela.
		coin.auto_hide_coin_after_result = false
		coins.append(coin)

	var results: Array = []
	for i in range(count):
		current_index = i
		var coin_center = Vector2(start_x + i * spacing, center.y)
		coins[i].play_toss(coin_center, coin_size)
		var favorable: bool = await coins[i].flip_completed
		results.append(favorable)

	current_index = -1
	sequence_completed.emit(results)
	return results

# Pula só a moeda que está girando NESTE momento — as próximas da fila
# ainda vão girar normalmente (uma de cada vez), não pula tudo de uma vez.
func skip_current() -> void:
	if current_index >= 0 and current_index < coins.size():
		coins[current_index].skip_spin()

func is_active() -> bool:
	return current_index >= 0

func clear() -> void:
	for c in coins:
		c.queue_free()
	coins.clear()
	current_index = -1
