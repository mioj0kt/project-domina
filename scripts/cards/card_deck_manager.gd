class_name CardDeckManager
extends RefCounted

signal hand_updated()
signal card_played(card: ActionCard)

const MAX_HAND_SIZE: int = 5

var draw_pile: Array[ActionCard] = []
var hand: Array[ActionCard] = []
var discard_pile: Array[ActionCard] = []

# Chamado ao iniciar o duelo: todo o deck do jogador vai para a pilha de compra
func setup_duel(deck_source: Array[ActionCard]) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()

	for card in deck_source:
		draw_pile.append(card.duplicate())

	draw_pile.shuffle()

	# Mão inicial: compra até o limite de 5
	while hand.size() < MAX_HAND_SIZE and not draw_pile.is_empty():
		_draw_one_card_raw()

	hand_updated.emit()

# Chamado no início de cada turno do jogador
func on_turn_started() -> void:
	draw_cards(1)

# Compra uma quantidade N de cartas respeitando o limite da mão e sem reciclar o descarte
func draw_cards(amount: int = 1) -> void:
	var drew_any = false
	for i in range(amount):
		if hand.size() >= MAX_HAND_SIZE or draw_pile.is_empty():
			break
		_draw_one_card_raw()
		drew_any = true

	if drew_any:
		hand_updated.emit()

func _draw_one_card_raw() -> void:
	if not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())

func play_card_at(card_index: int) -> ActionCard:
	if card_index < 0 or card_index >= hand.size():
		return null

	var card = hand[card_index]
	hand.remove_at(card_index)
	# Vai para o descarte e permanece lá até o próximo duelo
	discard_pile.append(card)

	card_played.emit(card)
	hand_updated.emit()
	return card

func get_draw_count() -> int:
	return draw_pile.size()

func get_discard_count() -> int:
	return discard_pile.size()
