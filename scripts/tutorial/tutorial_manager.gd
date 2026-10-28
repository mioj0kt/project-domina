extends Node

# Autoload — acessível como "TutorialManager" em qualquer script, igual
# RunManager. Guarda em qual passo do roteiro fixo o jogador está, o
# conteúdo de todas as falas do Guia (a peça que conduz o tutorial) e os
# OBJETIVOS guiados de cada lição ("aprender fazendo").
#
# Formato das falas: cada item é uma String ou um Dictionary
#   {"t": "texto", "spot": "id_do_destaque", "caption": "legenda curta"}
# O "spot" é resolvido pela cena que está tocando a fala (duelo, loja, aposta)
# e vira um holofote sobre aquela parte da tela.

signal step_changed(new_step: int)
# Objetivo guiado atual (texto + se já foi cumprido). A TutorialGuideView
# escuta e mostra o quadro "OBJETIVO"; text == "" esconde o quadro.
signal objective_changed(text: String, done: bool)
# Um objetivo novo ficou ativo (dicionário completo, com spot/caption).
signal objective_started(objective: Dictionary)
# Disparado quando TODOS os objetivos da lição foram cumpridos.
signal objectives_completed()
# Disparado quando um objetivo foi cumprido (id do evento).
signal objective_done(event_id: String)
# Disparado UMA vez por duelo, na primeira vez que uma Lei age (o Guia avisa).
signal law_first_applied()
var law_applied_announced: bool = false

enum Step {
	INTRO,
	DUEL_1_BASICS,
	SHOP,
	DUEL_3_CARDS_AND_LAWS,
	BET,
	FINISHED
}

# Ouro que o jogador recebe para a Loja do tutorial (sobra para o reroll).
const TUTORIAL_GOLD: int = 100
# Leis e Cartas à venda na Loja do tutorial — as mesmas que ele usa no Duelo 3.
const SHOP_LAW_IDS: Array[String] = ["second_move"]
const SHOP_CARD_IDS: Array[String] = ["coronation", "recruit", "extra_turn"]

var is_active: bool = false
var current_step: int = Step.INTRO

# true depois que o Guia já explicou a Morte Súbita dentro do Duelo 1
# (evita repetir). Zerada a cada novo tutorial.
var duel1_sudden_death_done: bool = false

# Resultado do último duelo do tutorial — usado pelo mapa pra decidir se
# avança pro próximo nó (venceu) ou deixa tentar o mesmo de novo (perdeu).
var last_duel_won: bool = true

# Marcas de dicas já mostradas NESTE duelo — zeradas a cada novo duelo do
# tutorial (ver reset_duel_flags()), pra cada dica só aparecer 1 vez.
var shown_tips: Dictionary = {}

# Objetivos da lição atual: lista de {event, text, done_tip, spot, caption}.
var _objectives: Array = []
var _objective_idx: int = 0
# true depois que a introdução do duelo/lição terminou e os objetivos começaram.
var objectives_begun: bool = false
var _pending_done_tip: String = ""

func start_tutorial() -> void:
	objectives_begun = false
	is_active = true
	current_step = Step.INTRO
	shown_tips.clear()
	duel1_sudden_death_done = false
	last_duel_won = true
	_objectives.clear()
	# O tutorial usa uma run própria e limpa (nada do jogador é afetado: o
	# botão JOGAR do menu sempre começa uma run nova).
	if RunManager != null:
		RunManager.start_new_run()
		RunManager.player_deck.clear()
		RunManager.gold = TUTORIAL_GOLD

func end_tutorial() -> void:
	is_active = false
	_objectives.clear()

func advance_to(step: int) -> void:
	objectives_begun = false
	current_step = step
	shown_tips.clear()
	_objectives.clear()
	step_changed.emit(current_step)

func reset_duel_flags() -> void:
	law_applied_announced = false
	objectives_begun = false
	shown_tips.clear()
	_objectives.clear()

# Chamado pelo letreiro de Lei (RuleTriggerBannerView) sempre que uma Lei age.
func report_law_applied() -> void:
	if not is_active or law_applied_announced or not objectives_begun:
		return
	# Só no duelo de Cartas e Leis: no Duelo 1 o jogador ainda não tem Leis (o
	# letreiro ali vem de efeitos do próprio sistema) e a fala fora de hora
	# atrapalhava o fim do duelo.
	if current_step != Step.DUEL_3_CARDS_AND_LAWS:
		return
	law_applied_announced = true
	law_first_applied.emit()

func get_law_applied_lines() -> Array:
	return TutorialDialogue.get_law_applied_lines()

func has_shown_tip(tip_id: String) -> bool:
	return shown_tips.has(tip_id)

func mark_tip_shown(tip_id: String) -> void:
	shown_tips[tip_id] = true

# ---------------------------------------------------------------------
# Currículo — usado pelo mapa do tutorial e pelos cartões de título.
# ---------------------------------------------------------------------

const LESSON_COUNT: int = 4

func get_lesson_number(step: int) -> int:
	match step:
		Step.DUEL_1_BASICS:
			return 1
		Step.SHOP:
			return 2
		Step.DUEL_3_CARDS_AND_LAWS:
			return 3
		Step.BET:
			return 4
	return 0

func get_lesson_title(step: int) -> String:
	return TutorialDialogue.get_lesson_title(step)

func get_lesson_goal(step: int) -> String:
	return TutorialDialogue.get_lesson_goal(step)

# ---------------------------------------------------------------------
# Objetivos guiados — "aprender fazendo". A cena chama begin_objectives()
# quando a fala de introdução termina e report_event() quando o jogador faz
# algo relevante (selecionar, capturar, promover, usar Carta, comprar...).
# ---------------------------------------------------------------------

func get_objectives(step: int) -> Array:
	return TutorialDialogue.get_objectives(step)

func begin_objectives() -> void:
	if not is_active:
		return
	_objectives = get_objectives(current_step)
	_objective_idx = 0
	objectives_begun = true
	_emit_current_objective()

func report_event(event_id: String) -> void:
	if not is_active or _objectives.is_empty() or _objective_idx >= _objectives.size():
		return
	var obj: Dictionary = _objectives[_objective_idx]
	if obj["event"] != event_id:
		return
	# A fala de conclusão precisa estar pronta ANTES do sinal (o quadro a consome).
	_pending_done_tip = obj.get("done_tip", "")
	objective_changed.emit(obj["text"], true)
	objective_done.emit(event_id)
	_objective_idx += 1
	if _objective_idx >= _objectives.size():
		objectives_completed.emit()
	else:
		_emit_current_objective()

func get_objective_number() -> int:
	return _objective_idx + 1

func consume_done_tip() -> String:
	var t = _pending_done_tip
	_pending_done_tip = ""
	return t

func all_objectives_done() -> bool:
	return _objectives.is_empty() or _objective_idx >= _objectives.size()

func _emit_current_objective() -> void:
	if _objective_idx < _objectives.size():
		var obj: Dictionary = _objectives[_objective_idx]
		objective_changed.emit(obj["text"], false)
		objective_started.emit(obj)

# ---------------------------------------------------------------------
# Configuração de cada duelo do tutorial
# ---------------------------------------------------------------------

func get_duel_board_size(step: int) -> Vector2i:
	match step:
		Step.DUEL_1_BASICS:
			return Vector2i(6, 6)
		Step.DUEL_3_CARDS_AND_LAWS:
			return Vector2i(8, 8)
	return Vector2i(8, 8)

# Posição inicial do Duelo 1 (6x6), em coordenadas Vector2i(coluna, linha).
# Montada para ensinar na ordem certa: uma captura obrigatória logo de cara,
# e uma peça perto da última fileira para a coroação. O jogador (brancas)
# joga embaixo, subindo; o inimigo joga em cima, descendo.
func get_duel1_human_pieces() -> Array[Vector2i]:
	return [Vector2i(3, 4), Vector2i(1, 2), Vector2i(0, 5), Vector2i(2, 5), Vector2i(4, 5)]

func get_duel1_enemy_pieces() -> Array[Vector2i]:
	return [Vector2i(4, 3), Vector2i(5, 0), Vector2i(3, 0)]

# ---------------------------------------------------------------------
# Falas do Guia
# ---------------------------------------------------------------------

func get_intro_lines() -> Array:
	return TutorialDialogue.get_intro_lines()

func get_duel1_intro_lines() -> Array:
	return TutorialDialogue.get_duel1_intro_lines()

func get_sudden_death_started_lines() -> Array:
	return TutorialDialogue.get_sudden_death_started_lines()

func get_sudden_death_forced_lines() -> Array:
	return TutorialDialogue.get_sudden_death_forced_lines()

func get_card_reward_explanation_lines() -> Array:
	return TutorialDialogue.get_card_reward_explanation_lines()

func get_shop_intro_lines() -> Array:
	return TutorialDialogue.get_shop_intro_lines()

func get_shop_lines() -> Array:
	return TutorialDialogue.get_shop_lines()

func get_shop_law_board_lines() -> Array:
	return TutorialDialogue.get_shop_law_board_lines()

func get_shop_done_lines() -> Array:
	return TutorialDialogue.get_shop_done_lines()

func get_duel3_intro_lines() -> Array:
	return TutorialDialogue.get_duel3_intro_lines()

func get_bet_intro_lines() -> Array:
	return TutorialDialogue.get_bet_intro_lines()

func get_real_map_lines() -> Array:
	return TutorialDialogue.get_real_map_lines()

# Final do tutorial: o Guia se coroa (vira Dama = peça virada) e cai no lado de
# baixo, o do Irmão (vilão final). Falas em TutorialDialogue.get_flip_lines().
# Desligue com FLIP_ENDING = false.
const FLIP_ENDING := true
func get_flip_walk_lines() -> Array:
	return TutorialDialogue.get_flip_walk_lines()

func get_flip_lines() -> Array:
	return TutorialDialogue.get_flip_lines()

func get_finished_lines() -> Array:
	return TutorialDialogue.get_finished_lines()

func get_missed_objectives_lines() -> Array:
	return TutorialDialogue.get_missed_objectives_lines(current_step)

func get_retry_hint(step: int) -> String:
	return TutorialDialogue.get_retry_hint(step)

func get_in_duel_tip(step: int, tip_id: String) -> String:
	return TutorialDialogue.get_in_duel_tip(step, tip_id)
