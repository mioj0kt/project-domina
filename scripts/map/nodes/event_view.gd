class_name EventView
extends Control

# Nó "?" do mapa: um encontro com 2-3 escolhas e consequências (ouro, cartas,
# Leis). Segue o mesmo padrão visual/estrutural da MESA DE APOSTAS (BetView):
# HUD lateral, fundo de bioma, inventário e tooltips. Alguns desfechos terminam em EMBOSCADA (duelo 6x6). Cada evento sai de
# _build_events() (dados) e é resolvido em _resolve() (efeitos); nenhum evento
# se repete numa mesma run (RunManager.seen_event_ids).

const MAP_SCENE_PATH: String = "res://scenes/map_view.tscn"
const PREVIEW_SCALE: float = 0.95
# Tela de transformação (forja, trocas, Lei reescrita): cartas bem maiores.
const TRANSFORM_CARD_SCALE: float = 2.0
const TRANSFORM_LAW_SCALE: float = 1.2

# --- Balanceamento (um evento rende algo na faixa de um duelo comum: ~7-14 ouro) ---
# Cofre: sucesso / agulha (perde ouro) / o resto é EMBOSCADA.
const CHEST_WIN_CHANCE: float = 0.5
const CHEST_NEEDLE_CHANCE: float = 0.25
const CHEST_AMBUSH_BONUS: int = 10
const CHEST_WIN_GOLD: int = 20
const CHEST_LOSS_GOLD: int = 8
const MERCHANT_BUY_COST: int = 12
const MERCHANT_SELL_GOLD: int = 10
const ALTAR_PRAYER_GOLD: int = 6
const FORGE_COST: int = 10
const FORGE_HELP_GOLD: int = 5
# Tomo: carta épica / perde ouro / o resto é EMBOSCADA (guardiões).
const TOME_CHANCE: float = 0.35
const TOME_LOSS_CHANCE: float = 0.35
const TOME_AMBUSH_BONUS: int = 12
const TOME_LOSS_GOLD: int = 10
const TRAVELER_HELP_COST: int = 5
# Viajante: roubo certo / perde ouro / o resto é EMBOSCADA (era isca).
const TRAVELER_ROB_CHANCE: float = 0.45
const TRAVELER_ROB_LOSS_CHANCE: float = 0.25
const TRAVELER_AMBUSH_BONUS: int = 10
# Acampamento: vasculhar dá carta, senão EMBOSCADA; montar a emboscada é duelo garantido.
const CAMP_SEARCH_CHANCE: float = 0.6
const CAMP_SEARCH_AMBUSH_BONUS: int = 8
const CAMP_SETUP_BONUS: int = 14
const TRAVELER_ROB_GOLD: int = 15
const TRAVELER_ROB_LOSS: int = 10
const MIN_DECK_FOR_SACRIFICE: int = 3
# Fonte Encantada
const FOUNTAIN_DRINK_CARD_CHANCE: float = 0.45
const FOUNTAIN_THIRST_LOSS: int = 6
const FOUNTAIN_WISH_COST: int = 5
const FOUNTAIN_WISH_CHANCE: float = 0.5
const FOUNTAIN_WISH_GOLD: int = 16
# Círculo de Cogumelos
const MUSHROOM_PICK_GOLD: int = 7
const MUSHROOM_WIN_CHANCE: float = 0.45
const MUSHROOM_LOSS_CHANCE: float = 0.30
const MUSHROOM_WIN_GOLD: int = 14
const MUSHROOM_LOSS_GOLD: int = 8
const MUSHROOM_AMBUSH_BONUS: int = 10
# Caçador Solitário
const HUNTER_SWAP_COST: int = 4
const HUNTER_DUEL_BONUS: int = 14
# Bruxa da Clareira
const WITCH_CARD_CHANCE: float = 0.45
const WITCH_LOSS_CHANCE: float = 0.30
const WITCH_GOLD: int = 10
const WITCH_HERBS_COST: int = 10
# Monge Ermitão
const MONK_SWAP_COST: int = 8
const MONK_ALMS_GOLD: int = 5

# ---- Deserto das Torres ----
const MIRAGE_OASIS_CHANCE: float = 0.35
const MIRAGE_THIRST_CHANCE: float = 0.40
const MIRAGE_THIRST_LOSS: int = 8
const MIRAGE_RUIN_GOLD: int = 12
const MIRAGE_DIG_GOLD: int = 5

const SARC_CARD_CHANCE: float = 0.40
const SARC_CURSE_CHANCE: float = 0.25
const SARC_CURSE_GOLD: int = 10
const SARC_AMBUSH_BONUS: int = 14
const SARC_LOOT_GOLD: int = 8

const CARAVAN_BREAD_COST: int = 6
const CARAVAN_RARE_COST: int = 16

const SPHINX_LAW_CHANCE: float = 0.30
const SPHINX_WRONG_LOSS: int = 6
const SPHINX_SHADOW_CARD_CHANCE: float = 0.50
const SPHINX_AMBUSH_BONUS: int = 12
const SPHINX_SILENCE_GOLD: int = 4

const STORM_WIN_CHANCE: float = 0.45
const STORM_LOSS_CHANCE: float = 0.30
const STORM_WIN_GOLD: int = 18
const STORM_LOSS_GOLD: int = 10
const STORM_AMBUSH_BONUS: int = 10
const STORM_SHELTER_GOLD: int = 3

const NOMAD_SWAP_COST: int = 4
const NOMAD_DUEL_BONUS: int = 14

# Mercador de Relíquias / Obelisco / Forja das Dunas / Escriba / Oásis / Salteadores
const RELIC_BUY_COST: int = 12
const RELIC_SELL_GOLD: int = 10
const OBELISK_PRAYER_GOLD: int = 6
const SCRIBE_ALMS_GOLD: int = 5
const OASIS_DRINK_CARD_CHANCE: float = 0.45
const OASIS_FEVER_LOSS: int = 6
const OASIS_WISH_COST: int = 5
const OASIS_WISH_CHANCE: float = 0.5
const OASIS_WISH_GOLD: int = 16
const BANDITS_SEARCH_CHANCE: float = 0.6
const BANDITS_SEARCH_AMBUSH_BONUS: int = 8
const BANDITS_SETUP_BONUS: int = 14

# ---- Mina dos Cristais ----
const VEIN_WIN_CHANCE: float = 0.45
const VEIN_LOSS_CHANCE: float = 0.30
const VEIN_WIN_GOLD: int = 18
const VEIN_LOSS_GOLD: int = 10
const VEIN_AMBUSH_BONUS: int = 10
const VEIN_CHIP_GOLD: int = 6

const SHARD_CARD_CHANCE: float = 0.40
const SHARD_LOSS_CHANCE: float = 0.25
const SHARD_LOSS_GOLD: int = 8
const SHARD_AMBUSH_BONUS: int = 12
const SHARD_COVER_GOLD: int = 3

const MINER_SWAP_COST: int = 4
const MINER_LISTEN_GOLD: int = 5

const CART_WIN_CHANCE: float = 0.45
const CART_LOSS_CHANCE: float = 0.30
const CART_WIN_GOLD: int = 16
const CART_LOSS_GOLD: int = 8
const CART_AMBUSH_BONUS: int = 10
const CART_SIFT_GOLD: int = 7

const ECHO_LAW_CHANCE: float = 0.30
const ECHO_WRONG_LOSS: int = 6
const ECHO_WHISPER_CARD_CHANCE: float = 0.50
const ECHO_AMBUSH_BONUS: int = 12
const ECHO_SILENCE_GOLD: int = 4

const PROSPECT_SEARCH_CHANCE: float = 0.6
const PROSPECT_SEARCH_AMBUSH_BONUS: int = 8
const PROSPECT_SETUP_BONUS: int = 14

const MIRROR_ALTAR_GOLD: int = 6

var hud_bar: HUDBar
var inventory_ui: InventoryUI
var card_tooltip: ActionCardTooltip
var rule_tooltip: RuleCardTooltip
var discard_modal: RuleDiscardModal

var title_label: Label
var text_label: Label
var gold_label: Label
var status_label: Label
var preview_hbox: HBoxContainer
var choices_box: VBoxContainer
var leave_btn: Button
var art_frame: Control
var art_layer: Control
var art_rect: TextureRect
var art_has_texture: bool = false
var fx: EventFx
var _kb_scale: float = 1.05      # zoom lento (Ken Burns): entra em 1.14 e assenta em 1.05
var _sway_t: float = 0.0
var _luck_played: bool = false
var _last_kind: String = ""
var dim_rect: ColorRect
var flash_rect: ColorRect
var wheel: LuckWheel
var luck_overlay: Control
var luck_dim: ColorRect
var panel_ref: PanelContainer
var luck_spinning: bool = false

var event: Dictionary = {}
var resolved: bool = false
# Desfecho que termina em duelo: "" | "ambushed" | "setup" (ver RunManager.ambush_kind).
var pending_ambush_kind: String = ""
var pending_ambush_bonus: int = 0

# Se definido (testes/depuração), força este evento em vez de sortear.
static var forced_event_id: String = ""
# Idem: força o resultado do sorteio (0..1) em vez de randf() — só testes.
static var forced_roll: float = -1.0
# Pula a roleta/animações (testes).
static var skip_animations: bool = false

func _roll() -> float:
	return forced_roll if forced_roll >= 0.0 else randf()

func _pct(x: float) -> int:
	return int(round(x * 100.0))

func _ready() -> void:
	_setup_ui()
	event = _pick_event()
	if not legacy_view and EventStage.supports(event):
		_enter_stage()
		return
	_show_event()
	_intro()

# ==========================================
# CUTSCENE (EventStage): o evento encenado no tabuleiro, no lugar do painel com arte + roleta
# ==========================================

# true = força o painel antigo (arte parada + roleta) mesmo nos eventos que têm cutscene.
static var legacy_view: bool = false
var stage: EventStage = null

func _enter_stage() -> void:
	stage = EventStage.new()
	stage.skip = skip_animations
	stage.title = String(event["title"])
	add_child(stage)
	move_child(stage, 0)
	panel_ref.visible = false
	# As cartas/Leis ganhas e o botão de seguir saem do painel antigo e vão para o palco.
	preview_hbox.get_parent().remove_child(preview_hbox)
	stage.preview_anchor.add_child(preview_hbox)
	leave_btn.get_parent().remove_child(leave_btn)
	leave_btn.custom_minimum_size = Vector2(380, 64)
	stage.footer.add_child(leave_btn)
	stage.choice_made.connect(_on_choice_pressed)
	_refresh_gold_label()
	await stage.play_intro(event)
	if not is_inside_tree():
		return
	var list: Array = []
	for choice in event["choices"]:
		var req: String = choice.get("requires", "")
		var ok: bool = _requirement_met(req)
		list.append({"id": choice["id"], "label": choice["label"], "hint": choice["hint"] if ok else _requirement_text(req),
			"enabled": ok, "color": _choice_color(choice["id"])})
	stage.show_choices("O que você faz?", list)

# A roleta (LuckWheel) girando sobre o palco até o desfecho já sorteado.
func _stage_spin(segments: Array, outcome: String) -> void:
	stage.box.visible = false
	wheel.setup(segments)
	var vp_size := get_viewport().get_visible_rect().size
	wheel.position = (Vector2(1190.0, vp_size.y / 2.0) - wheel.size / 2.0).floor()
	luck_dim.modulate.a = 0.0
	luck_overlay.visible = true
	create_tween().tween_property(luck_dim, "modulate:a", 0.75, 0.25)
	wheel.visible = true
	wheel.modulate.a = 1.0
	wheel.scale = Vector2.ONE * 0.2
	wheel.pivot_offset = wheel.size / 2.0
	var pop = create_tween()
	pop.tween_property(wheel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	luck_spinning = true
	wheel.spin_to(outcome)
	await wheel.finished
	luck_spinning = false
	_luck_played = true
	await get_tree().create_timer(0.6).timeout
	var out = create_tween()
	out.set_parallel(true)
	out.tween_property(wheel, "scale", Vector2.ONE * 0.2, 0.25)
	out.tween_property(wheel, "modulate:a", 0.0, 0.25)
	out.tween_property(luck_dim, "modulate:a", 0.0, 0.25)
	await out.finished
	luck_overlay.visible = false
	wheel.visible = false
	wheel.modulate.a = 1.0

func _stage_choice(choice_id: String) -> void:
	var segments: Array = _luck_segments(event["id"], choice_id)
	var outcome: String = ""
	var kind: String = ""
	if not segments.is_empty():
		outcome = _pick_outcome(segments)
		for s in segments:
			if s["key"] == outcome:
				kind = s.get("kind", "neutral")
	await stage.play_choice(event["id"], choice_id, not segments.is_empty())
	if not is_inside_tree():
		return
	# Escolha de sorte: a MESMA roleta de antes decide, por cima da cena.
	if not segments.is_empty() and not skip_animations:
		await _stage_spin(segments, outcome)
		if not is_inside_tree():
			return
	var gold_before: int = RunManager.gold
	var deck_before: int = RunManager.player_deck.size()
	var laws_before: int = RunManager.active_rules.size()
	preview_hbox.visible = false
	var txt: String = _resolve(event["id"], choice_id, outcome)
	var gained: bool = RunManager.player_deck.size() > deck_before or RunManager.active_rules.size() > laws_before \
		or (choice_id != "skip" and not preview_hbox.get_children().is_empty() and RunManager.player_deck.size() >= deck_before)
	var ambush: bool = pending_ambush_kind != ""
	await stage.play_result(event["id"], kind, RunManager.gold - gold_before, gained, ambush)
	if not is_inside_tree():
		return
	preview_hbox.visible = true
	_refresh_gold_label()
	var col := Color(0.78, 0.82, 0.9)
	if ambush:
		col = Color(1.0, 0.5, 0.45) if pending_ambush_kind == "ambushed" else Color(0.6, 0.95, 0.65)
	elif kind == "bad":
		col = Color(0.95, 0.7, 0.45)
	elif gained or RunManager.gold > gold_before:
		col = Color(0.6, 0.95, 0.65)
	stage.narrate(txt, col)
	leave_btn.visible = true
	if ambush:
		leave_btn.text = "LUTAR!"
		PixelUI.skin_button(leave_btn, Color(0.9, 0.3, 0.3), "", "icone_mapa")

# Leve oscilação da arte (respirar) por cima do zoom lento.
func _process(delta: float) -> void:
	if art_rect == null:
		return
	_sway_t += delta
	art_rect.pivot_offset = ART_SIZE / 2.0
	art_rect.scale = Vector2.ONE * (_kb_scale + 0.006 * sin(_sway_t * 0.55))
	art_rect.position = Vector2(sin(_sway_t * 0.42) * 3.0, cos(_sway_t * 0.31) * 2.0)

# ==========================================
# DADOS DOS EVENTOS
# ==========================================

# Cada escolha: {id, label, hint, requires (opcional): String}.
func _build_events() -> Array[Dictionary]:
	return [
		{
			"id": "chest", "title": "COFRE ENTERRADO",
			"text": "Um cofre preso entre as raízes, meio engolido pela terra. A tranca está podre de velha: uma batida boa e ela cede. Se ninguém ouvir.",
			"choices": [
				{"id": "pry", "label": "FORÇAR A TRANCA", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(CHEST_WIN_CHANCE), CHEST_WIN_GOLD, _pct(CHEST_NEEDLE_CHANCE), CHEST_LOSS_GOLD, _pct(1.0 - CHEST_WIN_CHANCE - CHEST_NEEDLE_CHANCE)]},
				{"id": "skip", "label": "DEIXAR ENTERRADO", "hint": "Nada acontece"},
			]
		},
		{
			"id": "merchant", "title": "MERCADOR ENCAPUZADO",
			"text": "Um sujeito de capuz abre a capa: cartas que caíram das ilhas quando o mundo rachou, embrulhadas em pano. Ele compra as suas também.",
			"choices": [
				{"id": "buy", "label": "COMPRAR (%d ouro)" % MERCHANT_BUY_COST, "hint": "Ganha 1 carta aleatória", "requires": "gold_%d" % MERCHANT_BUY_COST},
				{"id": "sell", "label": "VENDER UMA CARTA", "hint": "Perde 1 carta aleatória do baralho e ganha +%d ouro" % MERCHANT_SELL_GOLD, "requires": "deck_%d" % MIN_DECK_FOR_SACRIFICE},
				{"id": "skip", "label": "RECUSAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "altar", "title": "ALTAR DAS LEIS",
			"text": "Um altar de pedra coberto de musgo, com uma runa que pulsa fraca. Antes da Rachadura, cada lugar guardava as suas Leis em altares assim, e este ainda tem um pedaço de uma.",
			"choices": [
				{"id": "offer", "label": "OFERECER UMA CARTA", "hint": "Perde 1 carta aleatória e ganha 1 Lei aleatória", "requires": "deck_%d" % MIN_DECK_FOR_SACRIFICE},
				{"id": "pray", "label": "DESCANSAR AO PÉ DO ALTAR", "hint": "+%d ouro" % ALTAR_PRAYER_GOLD},
			]
		},
		{
			"id": "forge", "title": "FERREIRO ANDARILHO",
			"text": "Um ferreiro andarilho bate brasa numa bigorna no meio da mata. Por umas moedas, ele martela uma carta sua até ela virar coisa melhor.",
			"choices": [
				{"id": "forge", "label": "FORJAR (%d ouro)" % FORGE_COST, "hint": "1 carta aleatória sobe de raridade", "requires": "upgradable_%d" % FORGE_COST},
				{"id": "help", "label": "PISAR NO FOLE", "hint": "+%d ouro pelo trabalho" % FORGE_HELP_GOLD},
			]
		},
		{
			"id": "library", "title": "BIBLIOTECA ESQUECIDA",
			"text": "Uma biblioteca de pedra engolida pelo mato. Lá dentro, no meio do salão, um tomo preso por correntes treme sozinho.",
			"choices": [
				{"id": "read", "label": "LER COM CALMA", "hint": "Ganha 1 carta (comum ou rara)"},
				{"id": "tome", "label": "SOLTAR O TOMO ACORRENTADO", "hint": "%d%%: carta épica  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(TOME_CHANCE), _pct(TOME_LOSS_CHANCE), TOME_LOSS_GOLD, _pct(1.0 - TOME_CHANCE - TOME_LOSS_CHANCE)]},
			]
		},
		{
			"id": "traveler", "title": "VIAJANTE FERIDO",
			"text": "Um viajante caído na beira da trilha, com a borda rachada e a bolsa aberta. Ele pede ajuda com a voz fraca.",
			"choices": [
				{"id": "help", "label": "PAGAR O CURATIVO (%d ouro)" % TRAVELER_HELP_COST, "hint": "Ganha 1 carta rara ou melhor", "requires": "gold_%d" % TRAVELER_HELP_COST},
				{"id": "rob", "label": "REVISTAR A BOLSA", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(TRAVELER_ROB_CHANCE), TRAVELER_ROB_GOLD, _pct(TRAVELER_ROB_LOSS_CHANCE), TRAVELER_ROB_LOSS, _pct(1.0 - TRAVELER_ROB_CHANCE - TRAVELER_ROB_LOSS_CHANCE)]},
				{"id": "skip", "label": "IGNORAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "camp", "title": "ACAMPAMENTO ABANDONADO",
			"text": "Um acampamento largado às pressas: fogueira ainda morna, mochilas jogadas, ninguém por perto. Fácil demais.",
			"choices": [
				{"id": "search", "label": "VASCULHAR AS MOCHILAS", "hint": "%d%%: 1 carta (comum ou rara)  /  %d%%: EMBOSCADA (+%d ouro se vencer)" % [_pct(CAMP_SEARCH_CHANCE), _pct(1.0 - CAMP_SEARCH_CHANCE), CAMP_SEARCH_AMBUSH_BONUS]},
				{"id": "setup", "label": "ARMAR UMA EMBOSCADA", "hint": "Duelo garantido, com o inimigo desprevenido (1 carta a menos). Vitória: +%d ouro" % CAMP_SETUP_BONUS},
				{"id": "skip", "label": "CONTORNAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "fountain", "title": "FONTE ENCANTADA",
			"text": "Uma fonte de pedra no meio do nada, com uma água que brilha por conta própria. No fundo, moedas de quem fez pedidos antes.",
			"choices": [
				{"id": "drink", "label": "MERGULHAR NA FONTE", "hint": "%d%%: 1 carta (comum ou rara)  /  %d%%: -%d ouro" % [_pct(FOUNTAIN_DRINK_CARD_CHANCE), _pct(1.0 - FOUNTAIN_DRINK_CARD_CHANCE), FOUNTAIN_THIRST_LOSS]},
				{"id": "wish", "label": "JOGAR UMA MOEDA (%d ouro)" % FOUNTAIN_WISH_COST, "hint": "%d%%: +%d ouro  /  %d%%: nada acontece" % [_pct(FOUNTAIN_WISH_CHANCE), FOUNTAIN_WISH_GOLD, _pct(1.0 - FOUNTAIN_WISH_CHANCE)], "requires": "gold_%d" % FOUNTAIN_WISH_COST},
				{"id": "skip", "label": "SEGUIR VIAGEM", "hint": "Nada acontece"},
			]
		},
		{
			"id": "mushrooms", "title": "CÍRCULO DE COGUMELOS",
			"text": "Um círculo perfeito de cogumelos vermelhos. Lá de dentro vêm umas risadinhas. Dizem que quem pisa no meio dança até o sol nascer.",
			"choices": [
				{"id": "pick", "label": "COLHER PARA VENDER", "hint": "+%d ouro" % MUSHROOM_PICK_GOLD},
				{"id": "eat", "label": "PISAR NO CÍRCULO", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(MUSHROOM_WIN_CHANCE), MUSHROOM_WIN_GOLD, _pct(MUSHROOM_LOSS_CHANCE), MUSHROOM_LOSS_GOLD, _pct(1.0 - MUSHROOM_WIN_CHANCE - MUSHROOM_LOSS_CHANCE)]},
				{"id": "skip", "label": "DAR A VOLTA", "hint": "Segue viagem"},
			]
		},
		{
			"id": "hunter", "title": "CAÇADOR SOLITÁRIO",
			"text": "Um caçador de capuz verde, com arco nas costas, te mede de cima a baixo. Tem um negócio pra propor. Ou uma briga, tanto faz.",
			"choices": [
				{"id": "swap", "label": "TROCAR UMA CARTA (%d ouro)" % HUNTER_SWAP_COST, "hint": "1 carta aleatória vira outra da mesma raridade", "requires": "swapcard_%d" % HUNTER_SWAP_COST},
				{"id": "challenge", "label": "DESAFIAR PARA UM DUELO", "hint": "Duelo garantido. Vitória: +%d ouro" % HUNTER_DUEL_BONUS},
				{"id": "skip", "label": "RECUSAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "witch", "title": "BRUXA DA CLAREIRA",
			"text": "Uma bruxa mexe um caldeirão de poção verde. Diz que a poção acabou de ficar pronta e que ninguém teve coragem de provar ainda.",
			"choices": [
				{"id": "potion", "label": "PROVAR A POÇÃO", "hint": "%d%%: carta rara ou melhor  /  %d%%: perde 1 carta  /  %d%%: +%d ouro" % [_pct(WITCH_CARD_CHANCE), _pct(WITCH_LOSS_CHANCE), _pct(1.0 - WITCH_CARD_CHANCE - WITCH_LOSS_CHANCE), WITCH_GOLD]},
				{"id": "herbs", "label": "COMPRAR ERVAS (%d ouro)" % WITCH_HERBS_COST, "hint": "Ganha 1 carta comum", "requires": "gold_%d" % WITCH_HERBS_COST},
				{"id": "skip", "label": "RECUSAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "monk", "title": "MONGE ERMITÃO",
			"text": "Um monge de olhos fechados medita embaixo de uma árvore velha, cercado de pergaminhos. Diz que as suas Leis podiam ser melhores.",
			"choices": [
				{"id": "swap", "label": "REESCREVER UMA LEI (%d ouro)" % MONK_SWAP_COST, "hint": "1 Lei aleatória sua é trocada por outra", "requires": "swaplaw_%d" % MONK_SWAP_COST},
				{"id": "alms", "label": "AJUDAR NO JARDIM", "hint": "Ele paga o serviço: +%d ouro" % MONK_ALMS_GOLD},
				{"id": "skip", "label": "SEGUIR VIAGEM", "hint": "Segue viagem"},
			]
		},
		# ---------------- Deserto das Torres ----------------
		{
			"id": "mirage", "biome": "deserto", "title": "MIRAGEM NO HORIZONTE",
			"text": "Uma lagoa tremendo no horizonte, bonita demais pra ser real. Onde o ar treme, a areia parece mais fofa.",
			"choices": [
				{"id": "run", "label": "CORRER ATÉ A LAGOA", "hint": "%d%%: 1 carta (oásis de verdade)  /  %d%%: -%d ouro (sede)  /  %d%%: +%d ouro (ruínas)" % [_pct(MIRAGE_OASIS_CHANCE), _pct(MIRAGE_THIRST_CHANCE), MIRAGE_THIRST_LOSS, _pct(1.0 - MIRAGE_OASIS_CHANCE - MIRAGE_THIRST_CHANCE), MIRAGE_RUIN_GOLD]},
				{"id": "dig", "label": "CAVAR ONDE O AR TREME", "hint": "+%d ouro" % MIRAGE_DIG_GOLD},
				{"id": "skip", "label": "SEGUIR EM FRENTE", "hint": "Nada acontece"},
			]
		},
		{
			"id": "sarcophagus", "biome": "deserto", "title": "SARCÓFAGO ENTREABERTO",
			"text": "Um sarcófago de pedra meio enterrado, com a tampa torta. Sai um friozinho da fresta, e as oferendas ainda estão nos vasos em volta.",
			"choices": [
				{"id": "open", "label": "EMPURRAR A TAMPA", "hint": "%d%%: carta rara ou melhor  /  %d%%: -%d ouro (maldição)  /  %d%%: EMBOSCADA" % [_pct(SARC_CARD_CHANCE), _pct(SARC_CURSE_CHANCE), SARC_CURSE_GOLD, _pct(1.0 - SARC_CARD_CHANCE - SARC_CURSE_CHANCE)]},
				{"id": "loot", "label": "PEGAR SÓ AS OFERENDAS", "hint": "+%d ouro, sem tocar na tampa" % SARC_LOOT_GOLD},
				{"id": "skip", "label": "RESPEITAR OS MORTOS", "hint": "Segue viagem"},
			]
		},
		{
			"id": "caravan", "biome": "deserto", "title": "CARAVANA À DERIVA",
			"text": "Uma caravana parada à sombra de uma tenda listrada. O caravaneiro vende cartas: um maço barato na frente e as boas no baú do fundo.",
			"choices": [
				{"id": "bread", "label": "MAÇO BARATO (%d ouro)" % CARAVAN_BREAD_COST, "hint": "Ganha 1 carta comum", "requires": "gold_%d" % CARAVAN_BREAD_COST},
				{"id": "rare", "label": "O BAÚ DO FUNDO (%d ouro)" % CARAVAN_RARE_COST, "hint": "Ganha 1 carta rara ou melhor", "requires": "gold_%d" % CARAVAN_RARE_COST},
				{"id": "skip", "label": "RECUSAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "sphinx", "biome": "deserto", "title": "ESFINGE DE PEDRA",
			"text": "Uma esfinge de olho vazio fecha o caminho. Na frente dela, três placas de pedra: uma ampulheta, uma sombra e uma boca fechada. Cada uma cobra um preço.",
			"choices": [
				{"id": "time", "label": "PISAR NA AMPULHETA", "hint": "%d%%: 1 Lei nova  /  %d%%: -%d ouro" % [_pct(SPHINX_LAW_CHANCE), _pct(1.0 - SPHINX_LAW_CHANCE), SPHINX_WRONG_LOSS]},
				{"id": "shadow", "label": "PISAR NA SOMBRA", "hint": "%d%%: carta rara ou melhor  /  %d%%: EMBOSCADA (guardiões de pedra)" % [_pct(SPHINX_SHADOW_CARD_CHANCE), _pct(1.0 - SPHINX_SHADOW_CARD_CHANCE)]},
				{"id": "silence", "label": "PISAR NA BOCA FECHADA", "hint": "+%d ouro: a esfinge gosta de quem fica quieto" % SPHINX_SILENCE_GOLD},
			]
		},
		{
			"id": "sandstorm", "biome": "deserto", "title": "TEMPESTADE DE AREIA",
			"text": "O céu virou uma parede laranja. Tem uma torre em ruínas logo ali. O vento pode desenterrar um tesouro, ou te enterrar.",
			"choices": [
				{"id": "cross", "label": "ATRAVESSAR A TEMPESTADE", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(STORM_WIN_CHANCE), STORM_WIN_GOLD, _pct(STORM_LOSS_CHANCE), STORM_LOSS_GOLD, _pct(1.0 - STORM_WIN_CHANCE - STORM_LOSS_CHANCE)]},
				{"id": "shelter", "label": "ABRIGAR-SE NA TORRE", "hint": "+%d ouro" % STORM_SHELTER_GOLD},
			]
		},
		{
			"id": "nomad", "biome": "deserto", "title": "NÔMADE DAS DUNAS",
			"text": "Um nômade de turbante azul gira uma moeda nos dedos ao lado de um tapete com um tabuleiro desenhado. Troca cartas, e respeita quem joga bem.",
			"choices": [
				{"id": "swap", "label": "TROCAR UMA CARTA (%d ouro)" % NOMAD_SWAP_COST, "hint": "1 carta aleatória vira outra da mesma raridade", "requires": "swapcard_%d" % NOMAD_SWAP_COST},
				{"id": "challenge", "label": "DESAFIAR PARA UM DUELO", "hint": "Duelo garantido. Vitória: +%d ouro" % NOMAD_DUEL_BONUS},
				{"id": "skip", "label": "RECUSAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "relics", "biome": "deserto", "title": "MERCADOR DE RELÍQUIAS",
			"text": "Debaixo de um toldo de linho, um velho vende amuletos e cartas desenterradas de tumbas. Compra o que você tiver, sem perguntar de onde veio.",
			"choices": [
				{"id": "buy", "label": "COMPRAR (%d ouro)" % RELIC_BUY_COST, "hint": "Ganha 1 carta aleatória", "requires": "gold_%d" % RELIC_BUY_COST},
				{"id": "sell", "label": "VENDER UMA CARTA", "hint": "Perde 1 carta aleatória do baralho e ganha +%d ouro" % RELIC_SELL_GOLD, "requires": "deck_%d" % MIN_DECK_FOR_SACRIFICE},
				{"id": "skip", "label": "RECUSAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "obelisk", "biome": "deserto", "title": "OBELISCO DAS LEIS",
			"text": "Um obelisco coberto de hieróglifos, com oferendas velhas aos pés. Como os altares da mata, ele guarda um pedaço de uma Lei perdida.",
			"choices": [
				{"id": "offer", "label": "OFERECER UMA CARTA", "hint": "Perde 1 carta aleatória e ganha 1 Lei aleatória", "requires": "deck_%d" % MIN_DECK_FOR_SACRIFICE},
				{"id": "pray", "label": "DESCANSAR NA SOMBRA DELE", "hint": "+%d ouro" % OBELISK_PRAYER_GOLD},
			]
		},
		{
			"id": "scribe", "biome": "deserto", "title": "ESCRIBA DE PAPIRO",
			"text": "Um escriba sentado sobre uma pilha de papiros. Diz que as suas Leis foram escritas com pressa, e que reescreve uma por um preço justo.",
			"choices": [
				{"id": "swap", "label": "REESCREVER UMA LEI (%d ouro)" % MONK_SWAP_COST, "hint": "1 Lei aleatória sua é trocada por outra", "requires": "swaplaw_%d" % MONK_SWAP_COST},
				{"id": "alms", "label": "ORGANIZAR OS PAPIROS", "hint": "Ele paga o serviço: +%d ouro" % SCRIBE_ALMS_GOLD},
				{"id": "skip", "label": "SEGUIR VIAGEM", "hint": "Segue viagem"},
			]
		},
		{
			"id": "oasis", "biome": "deserto", "title": "OÁSIS SAGRADO",
			"text": "Uma lagoa quietinha no meio das palmeiras. Na margem, uma estaca cheia de fitas e moedas que outros viajantes deixaram.",
			"choices": [
				{"id": "drink", "label": "MERGULHAR NA LAGOA", "hint": "%d%%: 1 carta (comum ou rara)  /  %d%%: -%d ouro" % [_pct(OASIS_DRINK_CARD_CHANCE), _pct(1.0 - OASIS_DRINK_CARD_CHANCE), OASIS_FEVER_LOSS]},
				{"id": "wish", "label": "DEIXAR UMA MOEDA (%d ouro)" % OASIS_WISH_COST, "hint": "%d%%: +%d ouro  /  %d%%: nada acontece" % [_pct(OASIS_WISH_CHANCE), OASIS_WISH_GOLD, _pct(1.0 - OASIS_WISH_CHANCE)], "requires": "gold_%d" % OASIS_WISH_COST},
				{"id": "skip", "label": "SEGUIR VIAGEM", "hint": "Nada acontece"},
			]
		},
		{
			"id": "bandits", "biome": "deserto", "title": "ACAMPAMENTO DE SALTEADORES",
			"text": "Uma tenda de salteadores rasgada, fogueira apagada, um camelo amarrado. Os donos saíram agorinha e deixaram os sacos abertos.",
			"choices": [
				{"id": "search", "label": "VASCULHAR OS SACOS", "hint": "%d%%: 1 carta (comum ou rara)  /  %d%%: EMBOSCADA (+%d ouro se vencer)" % [_pct(BANDITS_SEARCH_CHANCE), _pct(1.0 - BANDITS_SEARCH_CHANCE), BANDITS_SEARCH_AMBUSH_BONUS]},
				{"id": "setup", "label": "ESPERAR ATRÁS DA DUNA", "hint": "Duelo garantido, com o inimigo desprevenido (1 carta a menos). Vitória: +%d ouro" % BANDITS_SETUP_BONUS},
				{"id": "skip", "label": "CONTORNAR", "hint": "Segue viagem"},
			]
		},
		# ---------------- Mina dos Cristais ----------------
		{
			"id": "crystal_vein", "biome": "mina", "title": "VEIO DE CRISTAL",
			"text": "Um cristal do tamanho de uma porta cresce da parede, estalando por dentro. Vale uma fortuna. Ou vale o teto.",
			"choices": [
				{"id": "pry", "label": "QUEBRAR O CRISTAL", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro (desabamento)  /  %d%%: EMBOSCADA" % [_pct(VEIN_WIN_CHANCE), VEIN_WIN_GOLD, _pct(VEIN_LOSS_CHANCE), VEIN_LOSS_GOLD, _pct(1.0 - VEIN_WIN_CHANCE - VEIN_LOSS_CHANCE)]},
				{"id": "chip", "label": "JUNTAR AS LASCAS", "hint": "+%d ouro" % VEIN_CHIP_GOLD},
				{"id": "skip", "label": "DEIXAR BRILHANDO", "hint": "Segue viagem"},
			]
		},
		{
			"id": "mirror_shard", "biome": "mina", "title": "ESPELHO RACHADO",
			"text": "Um espelho de cristal rachado de ponta a ponta. O seu reflexo se mexe um instante depois de você.",
			"choices": [
				{"id": "gaze", "label": "ENCARAR O REFLEXO", "hint": "%d%%: carta rara ou melhor  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA (o reflexo ataca)" % [_pct(SHARD_CARD_CHANCE), _pct(SHARD_LOSS_CHANCE), SHARD_LOSS_GOLD, _pct(1.0 - SHARD_CARD_CHANCE - SHARD_LOSS_CHANCE)]},
				{"id": "cover", "label": "COBRIR O ESPELHO", "hint": "+%d ouro dos cacos de baixo" % SHARD_COVER_GOLD},
				{"id": "skip", "label": "DESVIAR O OLHAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "echo_miner", "biome": "mina", "title": "MINEIRO DO ECO",
			"text": "Um mineiro de olhos leitosos escuta a parede com a picareta encostada. Diz que viu você chegando, duas vezes. Tem cartas viradas num pano.",
			"choices": [
				{"id": "swap", "label": "TROCAR UMA CARTA (%d ouro)" % MINER_SWAP_COST, "hint": "1 carta aleatória vira outra da mesma raridade", "requires": "swapcard_%d" % MINER_SWAP_COST},
				{"id": "listen", "label": "ESCUTAR A PAREDE COM ELE", "hint": "+%d ouro: ele divide o que o eco achar" % MINER_LISTEN_GOLD},
				{"id": "skip", "label": "SEGUIR VIAGEM", "hint": "Segue viagem"},
			]
		},
		{
			"id": "ore_cart", "biome": "mina", "title": "CARRINHO DESGOVERNADO",
			"text": "Um carrinho de minério cheio de ouro desce o trilho sozinho. Ao lado, uma alavanca de freio. Nenhum mineiro por perto.",
			"choices": [
				{"id": "brake", "label": "PULAR NA ALAVANCA", "hint": "%d%%: +%d ouro  /  %d%%: -%d ouro  /  %d%%: EMBOSCADA" % [_pct(CART_WIN_CHANCE), CART_WIN_GOLD, _pct(CART_LOSS_CHANCE), CART_LOSS_GOLD, _pct(1.0 - CART_WIN_CHANCE - CART_LOSS_CHANCE)]},
				{"id": "sift", "label": "PULAR NA CARGA", "hint": "+%d ouro" % CART_SIFT_GOLD},
				{"id": "skip", "label": "SAIR DA FRENTE", "hint": "Segue viagem"},
			]
		},
		{
			"id": "echo_chamber", "biome": "mina", "title": "CÂMARA DO ECO",
			"text": "Uma caverna redonda de paredes espelhadas, onde todo som volta duas vezes. No centro, uma pedra com uma fenda que guarda um eco antigo.",
			"choices": [
				{"id": "shout", "label": "BATER NA PEDRA", "hint": "%d%%: 1 Lei nova  /  %d%%: -%d ouro" % [_pct(ECHO_LAW_CHANCE), _pct(1.0 - ECHO_LAW_CHANCE), ECHO_WRONG_LOSS]},
				{"id": "whisper", "label": "EMPURRAR UMA PEDRINHA NA FENDA", "hint": "%d%%: carta rara ou melhor  /  %d%%: EMBOSCADA (alguém escuta)" % [_pct(ECHO_WHISPER_CARD_CHANCE), _pct(1.0 - ECHO_WHISPER_CARD_CHANCE)]},
				{"id": "silence", "label": "FICAR PARADO", "hint": "+%d ouro: o eco devolve só uma moeda" % ECHO_SILENCE_GOLD},
			]
		},
		{
			"id": "prospectors", "biome": "mina", "title": "ACAMPAMENTO DE GARIMPEIROS",
			"text": "Um acampamento de garimpeiros com lanterna acesa e sopa quente, mas ninguém por perto. Só umas sombras paradas no fundo da galeria.",
			"choices": [
				{"id": "search", "label": "VASCULHAR OS SACOS", "hint": "%d%%: 1 carta (comum ou rara)  /  %d%%: EMBOSCADA (+%d ouro se vencer)" % [_pct(PROSPECT_SEARCH_CHANCE), _pct(1.0 - PROSPECT_SEARCH_CHANCE), PROSPECT_SEARCH_AMBUSH_BONUS]},
				{"id": "setup", "label": "APAGAR A LANTERNA E ESPERAR", "hint": "Duelo garantido, com o inimigo desprevenido (1 carta a menos). Vitória: +%d ouro" % PROSPECT_SETUP_BONUS},
				{"id": "skip", "label": "CONTORNAR", "hint": "Segue viagem"},
			]
		},
		{
			"id": "mirror_altar", "biome": "mina", "title": "ALTAR DE ESPELHO",
			"text": "Um altar de cristal com uma face espelhada. Nela, uma versão sua mais velha e gasta. Uma mão de cristal sai do espelho pedindo uma carta.",
			"choices": [
				{"id": "offer", "label": "OFERECER UMA CARTA", "hint": "Perde 1 carta aleatória e ganha 1 Lei aleatória", "requires": "deck_%d" % MIN_DECK_FOR_SACRIFICE},
				{"id": "gaze", "label": "SÓ OLHAR", "hint": "+%d ouro" % MIRROR_ALTAR_GOLD},
				{"id": "skip", "label": "VIRAR AS COSTAS", "hint": "Segue viagem"},
			]
		},
	]

func _pick_event() -> Dictionary:
	var all = _build_events()
	if forced_event_id != "":
		for e in all:
			if e["id"] == forced_event_id:
				return e
	# Cada bioma tem os seus eventos (a floresta é o padrão de quem não declara "biome").
	var biome: String = RunManager.map_biome
	var biome_events = all.filter(func(e): return String(e.get("biome", "floresta")) == biome)
	if biome_events.is_empty():
		biome_events = all
	var seen: Array = RunManager.seen_event_ids
	var pool = biome_events.filter(func(e): return not seen.has(e["id"]))
	if pool.is_empty():
		for e in biome_events:
			seen.erase(e["id"])
		pool = biome_events
	var chosen: Dictionary = pool[randi() % pool.size()]
	seen.append(chosen["id"])
	return chosen

# Escolha disponível? (ouro, tamanho do baralho, cartas que podem subir de raridade).
func _requirement_met(req: String) -> bool:
	if req == "":
		return true
	var parts = req.split("_")
	var kind: String = parts[0]
	var amount: int = int(parts[1])
	match kind:
		"gold":
			return RunManager.gold >= amount
		"deck":
			return RunManager.player_deck.size() >= amount
		"upgradable":
			return RunManager.gold >= amount and not _upgradable_cards().is_empty()
		"swapcard":
			return RunManager.gold >= amount and not RunManager.player_deck.is_empty()
		"swaplaw":
			return RunManager.gold >= amount and not RunManager.active_rules.is_empty()
	return true

func _requirement_text(req: String) -> String:
	var parts = req.split("_")
	match parts[0]:
		"gold": return "Ouro insuficiente"
		"deck": return "Poucas cartas"
		"upgradable": return "Sem ouro ou sem carta para melhorar"
		"swapcard": return "Sem ouro ou sem cartas"
		"swaplaw": return "Sem ouro ou sem Leis"
	return ""

# ==========================================
# UI
# ==========================================

# A arte dos eventos é pixel art nativa 1280x576 (dithering de 1px): mostrada
# 1:1 pra ficar nítida (reduzir/ampliar com filtro estraga o dithering).
const CHOICE_W: float = 450.0
const ART_SIZE: Vector2 = Vector2(900, 405)
const ART_DIR: String = "res://assets/sprites/events/"
const EVENT_TINTS := {
	"chest": Color("#6b4a2a"), "merchant": Color("#4a3a6b"), "altar": Color("#3f6f8a"),
	"forge": Color("#8a4a2a"), "library": Color("#4a5a7a"), "traveler": Color("#5a6a3a"),
	"camp": Color("#6a3a3a"), "fountain": Color("#3a7a8a"), "mushrooms": Color("#8a3a4a"),
	"hunter": Color("#4a6a3a"), "witch": Color("#5a3a7a"), "monk": Color("#7a6a3a"),
	"mirage": Color("#3a8a9a"), "sarcophagus": Color("#8a7a3a"), "caravan": Color("#8a5a3a"),
	"sphinx": Color("#9a8a5a"), "sandstorm": Color("#a86a3a"), "nomad": Color("#3a5a8a"),
	"relics": Color("#7a5a8a"), "obelisk": Color("#8a8a5a"),
	"scribe": Color("#6a7a5a"), "oasis": Color("#2a8a7a"), "bandits": Color("#8a3a3a"),
	"crystal_vein": Color("#7a4ab0"), "mirror_shard": Color("#4a8aa8"), "echo_miner": Color("#6a5a7a"),
	"ore_cart": Color("#8a6a3a"), "echo_chamber": Color("#5a4a9a"), "prospectors": Color("#7a4a3a"), "mirror_altar": Color("#4a9a8a"),
}

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "EventUILayer"
	canvas.layer = 70
	add_child(canvas)

	add_child(BiomeBackground.new())

	hud_bar = HUDBar.new()
	canvas.add_child(hud_bar)
	hud_bar.open_laws_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.LAWS))
	hud_bar.open_cards_requested.connect(func(): inventory_ui.open_on_tab(InventoryUI.Tab.CARDS))

	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.setup()

	discard_modal = RuleDiscardModal.new()
	discard_modal.rule_replaced.connect(_on_reward_law_replaced)
	discard_modal.replacement_canceled.connect(_on_reward_law_declined)
	add_child(discard_modal)

	rule_tooltip = RuleCardTooltip.new()
	add_child(rule_tooltip)
	card_tooltip = ActionCardTooltip.new()
	add_child(card_tooltip)

	# Centralizado, mas deslocado pra direita pra não ficar sob o HUD lateral.
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 470)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(margin)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_pixel_panel(Color(0.09, 0.1, 0.14, 0.97), Color(0.55, 0.4, 0.8), 18))
	margin.add_child(panel)

	var content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	content_box.custom_minimum_size = Vector2(ART_SIZE.x + CHOICE_W + 16, 0)
	panel.add_child(content_box)

	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	content_box.add_child(head)
	var kicker = Label.new()
	kicker.text = "ENCONTRO"
	kicker.add_theme_font_size_override("font_size", 24)
	kicker.add_theme_color_override("font_color", Color(0.7, 0.55, 0.95))
	head.add_child(kicker)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	title_label.add_theme_constant_override("outline_size", 8)
	head.add_child(title_label)

	# --- Moldura da arte: imagem do evento (ou placeholder) + camadas de efeito ---
	var art_row = HBoxContainer.new()
	art_row.add_theme_constant_override("separation", 16)
	content_box.add_child(art_row)
	art_frame = Control.new()
	art_frame.custom_minimum_size = ART_SIZE
	art_frame.clip_contents = true
	art_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	art_row.add_child(art_frame)
	# Escolhas empilhadas na DIREITA da arte.
	choices_box = VBoxContainer.new()
	choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	choices_box.custom_minimum_size = Vector2(CHOICE_W, ART_SIZE.y)
	choices_box.add_theme_constant_override("separation", 12)
	art_row.add_child(choices_box)
	art_layer = Control.new()
	art_layer.size = ART_SIZE
	art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art_layer)
	art_layer.draw.connect(_draw_art_placeholder)
	art_rect = TextureRect.new()
	art_rect.size = ART_SIZE
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_SCALE
	art_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_layer.add_child(art_rect)
	fx = EventFx.new()
	art_layer.add_child(fx)
	fx.coin_arrived.connect(_on_coin_arrived)

	var frame_line = Panel.new()
	frame_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fl = StyleBoxFlat.new()
	fl.bg_color = Color(0, 0, 0, 0)
	fl.set_border_width_all(4)
	fl.border_color = Color("#d9a441")
	frame_line.add_theme_stylebox_override("panel", fl)
	art_frame.add_child(frame_line)

	gold_label = Label.new()
	gold_label.position = Vector2(14, 8)
	gold_label.add_theme_font_size_override("font_size", 26)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	gold_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	gold_label.add_theme_constant_override("outline_size", 6)
	art_frame.add_child(gold_label)

	dim_rect = ColorRect.new()
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_rect.color = Color(0.05, 0.03, 0.08, 0.6)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_rect.modulate.a = 0.0
	art_frame.add_child(dim_rect)

	preview_hbox = HBoxContainer.new()
	preview_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_hbox.add_theme_constant_override("separation", 24)
	preview_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(preview_hbox)

	# A roleta fica num overlay de tela cheia (fora do quadro da arte, que corta
	# o que passa da borda): assim a placa do resultado aparece inteira.
	luck_overlay = Control.new()
	luck_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	luck_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	luck_overlay.visible = false
	luck_dim = ColorRect.new()
	luck_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	luck_dim.color = Color(0.05, 0.03, 0.08, 0.78)
	luck_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	luck_overlay.add_child(luck_dim)
	wheel = LuckWheel.new()
	wheel.visible = false
	luck_overlay.add_child(wheel)
	canvas.add_child(luck_overlay)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color.WHITE
	flash_rect.modulate.a = 0.0
	art_frame.add_child(flash_rect)

	# --- Texto + escolhas ---
	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(ART_SIZE.x + CHOICE_W - 40, 0)
	text_label.add_theme_font_size_override("font_size", 40)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	content_box.add_child(text_label)
	content_box.move_child(text_label, 1)  # texto do evento logo abaixo do título, acima da arte

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(ART_SIZE.x + CHOICE_W - 40, 0)
	status_label.add_theme_font_size_override("font_size", 36)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.65))
	status_label.visible = false
	content_box.add_child(status_label)
	content_box.move_child(status_label, 2)

	leave_btn = Button.new()
	leave_btn.text = "SEGUIR VIAGEM"
	leave_btn.custom_minimum_size = Vector2(CHOICE_W, 72)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.add_theme_font_size_override("font_size", 32)
	PixelUI.skin_button(leave_btn, Color(0.4, 0.7, 0.9), "", "icone_mapa")
	leave_btn.pressed.connect(_on_leave_pressed)
	leave_btn.visible = false
	# O botão de seguir ocupa a coluna das escolhas (à direita da arte).
	var leave_holder := CenterContainer.new()
	leave_holder.custom_minimum_size = Vector2(CHOICE_W, ART_SIZE.y)
	leave_holder.add_child(leave_btn)
	art_row.add_child(leave_holder)
	leave_holder.visible = false
	leave_btn.visibility_changed.connect(func(): leave_holder.visible = leave_btn.visible)

	panel_ref = panel

func _load_art() -> void:
	var path = ART_DIR + String(event["id"]) + ".png"
	art_rect.texture = load(path) if ResourceLoader.exists(path) else null
	art_has_texture = art_rect.texture != null
	art_layer.queue_redraw()

# Placeholder (até existir assets/sprites/events/<id>.png): bandas na cor do evento.
func _draw_art_placeholder() -> void:
	if art_has_texture or event.is_empty():
		return
	var base: Color = EVENT_TINTS.get(event["id"], Color("#3a2b41"))
	var bands = 12
	for i in range(bands):
		var t = float(i) / bands
		art_layer.draw_rect(Rect2(0, t * ART_SIZE.y, ART_SIZE.x, ART_SIZE.y / bands + 1), base.darkened(0.55).lerp(base.lightened(0.1), t))
	var font = ThemeDB.fallback_font
	art_layer.draw_string(font, Vector2(0, ART_SIZE.y / 2.0 - 10), String(event["title"]), HORIZONTAL_ALIGNMENT_CENTER, ART_SIZE.x, 54, Color(1, 1, 1, 0.22))
	art_layer.draw_string(font, Vector2(0, ART_SIZE.y / 2.0 + 34), "[ arte do evento: %s%s.png  -  900x405 ]" % [ART_DIR.trim_prefix("res://"), event["id"]], HORIZONTAL_ALIGNMENT_CENTER, ART_SIZE.x, 22, Color(1, 1, 1, 0.35))

# Texto longo não pode empurrar o painel para fora da tela: quebra em linhas
# na largura do painel e, se ainda passar de MAX_TEXT_H, reduz a fonte aos poucos.
const MAX_TEXT_H: float = 190.0
const MIN_TEXT_FONT: int = 22
func _set_fit_text(label: Label, text: String, base_size: int) -> void:
	# Quebra de linha manual (o autowrap do Label crescia o painel além da tela
	# com texto longo trocado em tempo de execução).
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var width: float = label.custom_minimum_size.x
	var font: Font = label.get_theme_font("font")
	var font_size := base_size
	var wrapped := _wrap_text(font, text, width, font_size)
	while font_size > MIN_TEXT_FONT and font.get_multiline_string_size(wrapped, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).y > MAX_TEXT_H:
		font_size -= 2
		wrapped = _wrap_text(font, text, width, font_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.text = wrapped

func _wrap_text(font: Font, text: String, width: float, font_size: int) -> String:
	var out: Array[String] = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)

func _show_event() -> void:
	title_label.text = event["title"]
	_set_fit_text(text_label, event["text"], 40)
	text_label.visible = true
	status_label.text = ""
	status_label.visible = false
	_load_art()
	_refresh_gold_label()
	fx.setup(String(event.get("biome", "floresta")), String(event["id"]), EVENT_TINTS.get(event["id"], Color("#d9a441")), ART_SIZE)

	for child in choices_box.get_children():
		child.queue_free()
	var n: int = event["choices"].size()
	for choice in event["choices"]:
		var req: String = choice.get("requires", "")
		var available = _requirement_met(req)
		var btn = Button.new()
		btn.text = "%s\n%s" % [choice["label"], choice["hint"] if available else _requirement_text(req)]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(CHOICE_W, 0 if n > 3 else 140)
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 34)
		PixelUI.skin_button(btn, _choice_color(choice["id"]))
		btn.disabled = not available
		btn.pressed.connect(_on_choice_pressed.bind(choice["id"]))
		choices_box.add_child(btn)

func _choice_color(choice_id: String) -> Color:
	match choice_id:
		"skip": return Color(0.45, 0.45, 0.5)
		"pry", "tome", "rob", "search", "eat", "potion", "drink", "wish", "run", "open", "time", "shadow", "cross": return Color(0.9, 0.5, 0.3)
		"setup", "challenge": return Color(0.85, 0.35, 0.35)
		_: return Color(0.4, 0.85, 0.5)

func _refresh_gold_label() -> void:
	gold_label.text = "Ouro: %d" % RunManager.gold
	if hud_bar != null:
		hud_bar.update_gold()
		hud_bar.refresh_cards_inventory_count()

# ==========================================
# SORTE (roleta)
# ==========================================

# Escolhas de sorte -> fatias da roleta (a ordem define o sorteio cumulativo).
func _luck_segments(event_id: String, choice_id: String) -> Array:
	match event_id + "." + choice_id:
		"chest.pry":
			return [
				{"key": "win", "chance": CHEST_WIN_CHANCE, "label": "+%d OURO" % CHEST_WIN_GOLD, "kind": "good"},
				{"key": "needle", "chance": CHEST_NEEDLE_CHANCE, "label": "-%d OURO" % CHEST_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - CHEST_WIN_CHANCE - CHEST_NEEDLE_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"library.tome":
			return [
				{"key": "epic", "chance": TOME_CHANCE, "label": "CARTA ÉPICA", "kind": "good"},
				{"key": "loss", "chance": TOME_LOSS_CHANCE, "label": "-%d OURO" % TOME_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - TOME_CHANCE - TOME_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"traveler.rob":
			return [
				{"key": "win", "chance": TRAVELER_ROB_CHANCE, "label": "+%d OURO" % TRAVELER_ROB_GOLD, "kind": "good"},
				{"key": "loss", "chance": TRAVELER_ROB_LOSS_CHANCE, "label": "-%d OURO" % TRAVELER_ROB_LOSS, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - TRAVELER_ROB_CHANCE - TRAVELER_ROB_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"camp.search":
			return [
				{"key": "card", "chance": CAMP_SEARCH_CHANCE, "label": "CARTA", "kind": "good"},
				{"key": "ambush", "chance": 1.0 - CAMP_SEARCH_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"fountain.drink":
			return [
				{"key": "card", "chance": FOUNTAIN_DRINK_CARD_CHANCE, "label": "CARTA", "kind": "good"},
				{"key": "thirst", "chance": 1.0 - FOUNTAIN_DRINK_CARD_CHANCE, "label": "-%d OURO" % FOUNTAIN_THIRST_LOSS, "kind": "bad"},
			]
		"fountain.wish":
			return [
				{"key": "win", "chance": FOUNTAIN_WISH_CHANCE, "label": "+%d OURO" % FOUNTAIN_WISH_GOLD, "kind": "good"},
				{"key": "none", "chance": 1.0 - FOUNTAIN_WISH_CHANCE, "label": "NADA", "kind": "bad"},
			]
		"mushrooms.eat":
			return [
				{"key": "win", "chance": MUSHROOM_WIN_CHANCE, "label": "+%d OURO" % MUSHROOM_WIN_GOLD, "kind": "good"},
				{"key": "loss", "chance": MUSHROOM_LOSS_CHANCE, "label": "-%d OURO" % MUSHROOM_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - MUSHROOM_WIN_CHANCE - MUSHROOM_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"witch.potion":
			return [
				{"key": "card", "chance": WITCH_CARD_CHANCE, "label": "CARTA RARA", "kind": "good"},
				{"key": "loss", "chance": WITCH_LOSS_CHANCE, "label": "PERDE CARTA", "kind": "bad"},
				{"key": "gold", "chance": 1.0 - WITCH_CARD_CHANCE - WITCH_LOSS_CHANCE, "label": "+%d OURO" % WITCH_GOLD, "kind": "good"},
			]
		"mirage.run":
			return [
				{"key": "oasis", "chance": MIRAGE_OASIS_CHANCE, "label": "CARTA", "kind": "good"},
				{"key": "thirst", "chance": MIRAGE_THIRST_CHANCE, "label": "-%d OURO" % MIRAGE_THIRST_LOSS, "kind": "bad"},
				{"key": "ruin", "chance": 1.0 - MIRAGE_OASIS_CHANCE - MIRAGE_THIRST_CHANCE, "label": "+%d OURO" % MIRAGE_RUIN_GOLD, "kind": "good"},
			]
		"sarcophagus.open":
			return [
				{"key": "card", "chance": SARC_CARD_CHANCE, "label": "CARTA RARA", "kind": "good"},
				{"key": "curse", "chance": SARC_CURSE_CHANCE, "label": "-%d OURO" % SARC_CURSE_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - SARC_CARD_CHANCE - SARC_CURSE_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"sphinx.time":
			return [
				{"key": "law", "chance": SPHINX_LAW_CHANCE, "label": "NOVA LEI", "kind": "good"},
				{"key": "wrong", "chance": 1.0 - SPHINX_LAW_CHANCE, "label": "-%d OURO" % SPHINX_WRONG_LOSS, "kind": "bad"},
			]
		"sphinx.shadow":
			return [
				{"key": "card", "chance": SPHINX_SHADOW_CARD_CHANCE, "label": "CARTA RARA", "kind": "good"},
				{"key": "ambush", "chance": 1.0 - SPHINX_SHADOW_CARD_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"oasis.drink":
			return [
				{"key": "card", "chance": OASIS_DRINK_CARD_CHANCE, "label": "CARTA", "kind": "good"},
				{"key": "fever", "chance": 1.0 - OASIS_DRINK_CARD_CHANCE, "label": "-%d OURO" % OASIS_FEVER_LOSS, "kind": "bad"},
			]
		"oasis.wish":
			return [
				{"key": "win", "chance": OASIS_WISH_CHANCE, "label": "+%d OURO" % OASIS_WISH_GOLD, "kind": "good"},
				{"key": "none", "chance": 1.0 - OASIS_WISH_CHANCE, "label": "NADA", "kind": "bad"},
			]
		"bandits.search":
			return [
				{"key": "card", "chance": BANDITS_SEARCH_CHANCE, "label": "CARTA", "kind": "good"},
				{"key": "ambush", "chance": 1.0 - BANDITS_SEARCH_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"crystal_vein.pry":
			return [
				{"key": "win", "chance": VEIN_WIN_CHANCE, "label": "+%d OURO" % VEIN_WIN_GOLD, "kind": "good"},
				{"key": "loss", "chance": VEIN_LOSS_CHANCE, "label": "-%d OURO" % VEIN_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - VEIN_WIN_CHANCE - VEIN_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"mirror_shard.gaze":
			return [
				{"key": "card", "chance": SHARD_CARD_CHANCE, "label": "CARTA RARA", "kind": "good"},
				{"key": "loss", "chance": SHARD_LOSS_CHANCE, "label": "-%d OURO" % SHARD_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - SHARD_CARD_CHANCE - SHARD_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"ore_cart.brake":
			return [
				{"key": "win", "chance": CART_WIN_CHANCE, "label": "+%d OURO" % CART_WIN_GOLD, "kind": "good"},
				{"key": "loss", "chance": CART_LOSS_CHANCE, "label": "-%d OURO" % CART_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - CART_WIN_CHANCE - CART_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"echo_chamber.shout":
			return [
				{"key": "law", "chance": ECHO_LAW_CHANCE, "label": "NOVA LEI", "kind": "good"},
				{"key": "wrong", "chance": 1.0 - ECHO_LAW_CHANCE, "label": "-%d OURO" % ECHO_WRONG_LOSS, "kind": "bad"},
			]
		"echo_chamber.whisper":
			return [
				{"key": "card", "chance": ECHO_WHISPER_CARD_CHANCE, "label": "CARTA RARA", "kind": "good"},
				{"key": "ambush", "chance": 1.0 - ECHO_WHISPER_CARD_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"prospectors.search":
			return [
				{"key": "card", "chance": PROSPECT_SEARCH_CHANCE, "label": "CARTA", "kind": "good"},
				{"key": "ambush", "chance": 1.0 - PROSPECT_SEARCH_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
		"sandstorm.cross":
			return [
				{"key": "win", "chance": STORM_WIN_CHANCE, "label": "+%d OURO" % STORM_WIN_GOLD, "kind": "good"},
				{"key": "loss", "chance": STORM_LOSS_CHANCE, "label": "-%d OURO" % STORM_LOSS_GOLD, "kind": "bad"},
				{"key": "ambush", "chance": 1.0 - STORM_WIN_CHANCE - STORM_LOSS_CHANCE, "label": "EMBOSCADA", "kind": "danger"},
			]
	return []

# Sorteia a fatia (usa _roll(), então forced_roll continua valendo nos testes).
func _pick_outcome(segments: Array) -> String:
	var r: float = _roll()
	var acc := 0.0
	for s in segments:
		acc += float(s["chance"])
		if r < acc:
			return s["key"]
	return segments[segments.size() - 1]["key"]

func _on_choice_pressed(choice_id: String) -> void:
	if resolved:
		return
	resolved = true
	_luck_played = false
	_last_kind = ""
	choices_box.visible = false
	for child in preview_hbox.get_children():
		child.queue_free()
	if stage != null:
		_stage_choice(choice_id)
		return
	var segments = _luck_segments(event["id"], choice_id)
	if segments.is_empty():
		_finish_choice(choice_id, "")
		return
	var outcome = _pick_outcome(segments)
	if skip_animations:
		_finish_choice(choice_id, outcome)
		return
	_play_luck(choice_id, segments, outcome)

func _play_luck(choice_id: String, segments: Array, outcome: String) -> void:
	text_label.text = "A sorte está lançada..."
	text_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	var dim_tween = create_tween()
	dim_tween.tween_property(dim_rect, "modulate:a", 1.0, 0.25)
	wheel.setup(segments)
	var vp_size := get_viewport().get_visible_rect().size
	wheel.position = ((vp_size - wheel.size) / 2.0).floor()
	luck_dim.modulate.a = 0.0
	luck_overlay.visible = true
	create_tween().tween_property(luck_dim, "modulate:a", 1.0, 0.25)
	wheel.visible = true
	wheel.scale = Vector2.ONE * 0.2
	wheel.pivot_offset = wheel.size / 2.0
	var pop = create_tween()
	pop.tween_property(wheel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	luck_spinning = true
	wheel.spin_to(outcome)
	await wheel.finished
	luck_spinning = false
	var kind: String = "neutral"
	for s in segments:
		if s["key"] == outcome:
			kind = s.get("kind", "neutral")
	_luck_played = true
	_last_kind = kind
	_impact(kind)
	await get_tree().create_timer(0.5).timeout
	var out = create_tween()
	out.set_parallel(true)
	out.tween_property(wheel, "scale", Vector2.ONE * 0.2, 0.25)
	out.tween_property(wheel, "modulate:a", 0.0, 0.25)
	out.tween_property(luck_dim, "modulate:a", 0.0, 0.25)
	await out.finished
	luck_overlay.visible = false
	wheel.visible = false
	wheel.modulate.a = 1.0
	text_label.remove_theme_color_override("font_color")
	text_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	_finish_choice(choice_id, outcome)

# Flash colorido + tremor da arte conforme o tipo do desfecho.
func _impact(kind: String) -> void:
	var col: Color = LuckWheel.KIND_COLORS.get(kind, Color.WHITE)
	flash_rect.color = col.lightened(0.3)
	var f = create_tween()
	f.tween_property(flash_rect, "modulate:a", 0.55 if kind == "danger" else 0.35, 0.05)
	f.tween_property(flash_rect, "modulate:a", 0.0, 0.5)
	var amp: float = 16.0 if kind == "danger" else (8.0 if kind == "bad" else 4.0)
	var s = create_tween()
	for i in range(8):
		s.tween_property(art_layer, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) * (1.0 - i / 8.0), 0.04)
	s.tween_property(art_layer, "position", Vector2.ZERO, 0.04)

func _input(e: InputEvent) -> void:
	if luck_spinning and e is InputEventMouseButton and e.pressed:
		wheel.skip()

func _finish_choice(choice_id: String, outcome: String) -> void:
	var gold_before: int = RunManager.gold
	var deck_before: int = RunManager.player_deck.size()
	var laws_before: int = RunManager.active_rules.size()
	_set_fit_text(status_label, _resolve(event["id"], choice_id, outcome), 40)
	_react(RunManager.gold - gold_before,
		RunManager.player_deck.size() > deck_before or RunManager.active_rules.size() > laws_before or (choice_id != "skip" and not preview_hbox.get_children().is_empty() and RunManager.player_deck.size() >= deck_before),
		pending_ambush_kind != "")
	text_label.visible = false
	status_label.visible = true
	_refresh_gold_label()
	if not preview_hbox.get_children().is_empty():
		dim_rect.modulate.a = 1.0
	else:
		dim_rect.modulate.a = 0.0
	leave_btn.visible = true
	if pending_ambush_kind != "":
		leave_btn.text = "LUTAR!"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45) if pending_ambush_kind == "ambushed" else Color(0.6, 0.95, 0.65))
		PixelUI.skin_button(leave_btn, Color(0.9, 0.3, 0.3), "", "icone_mapa")

# ==========================================
# ENTRADA E REAÇÕES (efeitos de cena)
# ==========================================

# Entrada: cortina que abre, zoom lento da arte e título carimbado.
func _intro() -> void:
	if skip_animations or art_rect == null:
		return
	# Cortina: duas metades escuras que se abrem.
	var curtain_col := Color(0.04, 0.03, 0.07, 1.0)
	var left := ColorRect.new()
	left.color = curtain_col
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size = Vector2(ART_SIZE.x / 2.0 + 2.0, ART_SIZE.y)
	var right := ColorRect.new()
	right.color = curtain_col
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size = Vector2(ART_SIZE.x / 2.0 + 2.0, ART_SIZE.y)
	right.position = Vector2(ART_SIZE.x / 2.0 - 2.0, 0)
	art_frame.add_child(left)
	art_frame.add_child(right)
	var ct := create_tween().set_parallel(true)
	ct.tween_property(left, "position:x", -ART_SIZE.x / 2.0 - 4.0, 0.75).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	ct.tween_property(right, "position:x", ART_SIZE.x + 4.0, 0.75).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	ct.finished.connect(func():
		left.queue_free()
		right.queue_free())
	# Zoom lento: começa perto e se afasta devagar.
	_kb_scale = 1.15
	create_tween().tween_property(self, "_kb_scale", 1.05, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Título carimbado.
	title_label.modulate.a = 0.0
	await get_tree().process_frame
	if not is_inside_tree():
		return
	title_label.pivot_offset = title_label.size / 2.0
	title_label.scale = Vector2.ONE * 2.6
	var st := create_tween().set_parallel(true)
	st.tween_property(title_label, "modulate:a", 1.0, 0.12).set_delay(0.35)
	st.tween_property(title_label, "scale", Vector2.ONE, 0.22).set_delay(0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.57).timeout
	if not is_inside_tree():
		return
	# Impacto do carimbo: tremor curto, anel de poeira e brilho no objeto.
	var sh := create_tween()
	for i in range(5):
		sh.tween_property(art_layer, "position", Vector2(randf_range(-5, 5), randf_range(-4, 4)) * (1.0 - i / 5.0), 0.03)
	sh.tween_property(art_layer, "position", Vector2.ZERO, 0.03)
	fx.ring(Color(1.0, 0.85, 0.3, 0.8), Vector2(ART_SIZE.x / 2.0, 30.0))
	fx.boost_glow(1.6)

func _on_coin_arrived() -> void:
	if gold_label == null:
		return
	gold_label.pivot_offset = Vector2(40, 14)
	gold_label.scale = Vector2.ONE * 1.35
	create_tween().tween_property(gold_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Reação da cena ao desfecho: moedas, brilho dourado, perigo ou maldição.
func _react(gold_delta: int, gained: bool, ambush: bool) -> void:
	if skip_animations or fx == null:
		return
	if ambush:
		fx.pulse_danger()
		fx.ring(Color(0.95, 0.25, 0.2))
		if not _luck_played:
			_flash_color(Color(1.0, 0.3, 0.25), 0.5)
			_shake(14.0)
		return
	if _last_kind == "bad":
		# Maldição/perda: a cena escurece e solta fumaça roxa.
		fx.curse_smoke(30)
		fx.pulse_danger()
		var dk := create_tween()
		flash_rect.color = Color(0.02, 0.0, 0.05)
		dk.tween_property(flash_rect, "modulate:a", 0.78, 0.2)
		dk.tween_interval(0.35)
		dk.tween_property(flash_rect, "modulate:a", 0.0, 1.0)
		_shake(7.0)
		return
	if gold_delta > 0:
		fx.burst_coins(clampi(6 + gold_delta, 8, 26))
		fx.boost_glow(1.8)
		_flash_color(Color(1.0, 0.85, 0.3), 0.3)
	if gained:
		fx.burst_sparkles(24)
		fx.ring()
		fx.boost_glow(2.4)
		_flash_color(Color(1.0, 0.92, 0.55), 0.55)

func _flash_color(col: Color, peak: float) -> void:
	flash_rect.color = col
	var f := create_tween()
	f.tween_property(flash_rect, "modulate:a", peak, 0.06)
	f.tween_property(flash_rect, "modulate:a", 0.0, 0.7)

func _shake(amp: float) -> void:
	var s := create_tween()
	for i in range(10):
		s.tween_property(art_layer, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) * (1.0 - i / 10.0), 0.04)
	s.tween_property(art_layer, "position", Vector2.ZERO, 0.04)

# ==========================================
# RESOLUÇÃO
# ==========================================

# Devolve o texto do desfecho; cartas/Leis envolvidas aparecem em preview_hbox.
func _resolve(event_id: String, choice_id: String, outcome: String = "") -> String:
	if choice_id == "skip":
		return "Você segue seu caminho."
	match event_id:
		"chest":
			if outcome == "win":
				RunManager.add_gold(CHEST_WIN_GOLD)
				return "A tranca estala e a tampa cede: +%d de ouro." % CHEST_WIN_GOLD
			if outcome == "needle":
				return "Uma farpa de ferro da tranca racha a sua borda. O remendo custa %d de ouro." % _lose_gold(CHEST_LOSS_GOLD)
			return _start_ambush("ambushed", CHEST_AMBUSH_BONUS, "O estalo ecoa pela mata. O dono do cofre voltou, e trouxe amigos.")
		"merchant":
			if choice_id == "buy":
				RunManager.spend_gold(MERCHANT_BUY_COST)
				return "Ele tira uma carta de dentro do capuz (-%d de ouro). %s" % [MERCHANT_BUY_COST, _give_card(_random_card(ActionCard.Rarity.COMMON), "RECEBIDA")]
			var lost = _take_random_card()
			if lost != null:
				RunManager.add_gold(MERCHANT_SELL_GOLD)
				preview_hbox.add_child(_labeled_card_visual("VENDIDA", lost, Color(1.0, 0.6, 0.6, 0.8)))
				return "Ele olha a carta contra a luz da lanterna e paga %d de ouro." % MERCHANT_SELL_GOLD
			return "Ele olha suas cartas e devolve todas: \"Isso eu já tenho.\""
		"altar":
			if choice_id == "pray":
				RunManager.add_gold(ALTAR_PRAYER_GOLD)
				return "Quando a runa se apaga, você nota moedas entre as pedras, deixadas por quem passou antes: +%d de ouro." % ALTAR_PRAYER_GOLD
			var offered = _take_random_card()
			if offered != null:
				preview_hbox.add_child(_labeled_card_visual("OFERECIDA", offered, Color(1.0, 0.6, 0.6, 0.8)))
			return "A runa engole a carta e devolve o pedaço de Lei que guardava. %s" % _give_random_law()
		"forge":
			if choice_id == "help":
				RunManager.add_gold(FORGE_HELP_GOLD)
				return "Você pula no fole até a brasa ficar branca. Ele paga o trabalho: +%d de ouro." % FORGE_HELP_GOLD
			return _forge_card()
		"library":
			if choice_id == "read":
				return _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
			if outcome == "epic":
				return "As correntes caem sozinhas e o tomo se abre numa carta que ninguém via há séculos. %s" % _give_card(_random_card(ActionCard.Rarity.EPIC), "ENCONTRADA")
			if outcome == "loss":
				return "O tomo fecha com força e prende a sua borda. Pra se soltar, você deixa %d de ouro." % _lose_gold(TOME_LOSS_GOLD)
			return _start_ambush("ambushed", TOME_AMBUSH_BONUS, "As correntes se arrastam pelo salão. Os guardiões da biblioteca acordaram, e não gostam de visita.")
		"traveler":
			if choice_id == "help":
				RunManager.spend_gold(TRAVELER_HELP_COST)
				return "Ele remenda a borda, respira fundo e tira da bolsa o melhor que tinha. %s" % _give_card(_random_card(ActionCard.Rarity.RARE), "PRESENTE")
			if outcome == "win":
				RunManager.add_gold(TRAVELER_ROB_GOLD)
				return "Ele desmaia de novo antes de perceber. Você sai com +%d de ouro." % TRAVELER_ROB_GOLD
			if outcome == "loss":
				return "Ele não estava tão fraco assim: um tranco, e você foge deixando %d de ouro pra trás." % _lose_gold(TRAVELER_ROB_LOSS)
			return _start_ambush("ambushed", TRAVELER_AMBUSH_BONUS, "Ele assobia. Era isca: o bando dele sai do mato.")
		"camp":
			if choice_id == "setup":
				return _start_ambush("setup", CAMP_SETUP_BONUS, "Você se esconde atrás de uma barraca. Quando o bando volta, quem pega de surpresa é você.")
			if outcome == "card":
				return _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
			return _start_ambush("ambushed", CAMP_SEARCH_AMBUSH_BONUS, "Uma corda estica no chão e um sino toca. O bando volta correndo.")
		"fountain":
			if choice_id == "drink":
				if outcome == "card":
					return "A água fria lava a poeira da sua borda, e uma carta do fundo sobe junto com você. %s" % _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
				return "A fonte é mais funda do que parece. Quando você consegue sair, %d de ouro ficaram lá embaixo." % _lose_gold(FOUNTAIN_THIRST_LOSS)
			RunManager.spend_gold(FOUNTAIN_WISH_COST)
			if outcome == "win":
				RunManager.add_gold(FOUNTAIN_WISH_GOLD)
				return "A água brilha e devolve mais do que você jogou: +%d de ouro." % FOUNTAIN_WISH_GOLD
			return "A moeda afunda e a água volta a ficar parada. Nada aconteceu (-%d de ouro)." % FOUNTAIN_WISH_COST
		"mushrooms":
			if choice_id == "pick":
				RunManager.add_gold(MUSHROOM_PICK_GOLD)
				return "Você colhe os cogumelos da borda sem pisar no círculo e vende pro primeiro que passa: +%d de ouro." % MUSHROOM_PICK_GOLD
			if outcome == "win":
				RunManager.add_gold(MUSHROOM_WIN_GOLD)
				return "O círculo gira, a mata gira, e quando tudo para tem moeda de fada caída em volta: +%d de ouro." % MUSHROOM_WIN_GOLD
			if outcome == "loss":
				return "Você dança a noite inteira sem querer, e as fadas cobram a música: -%d de ouro." % _lose_gold(MUSHROOM_LOSS_GOLD)
			return _start_ambush("ambushed", MUSHROOM_AMBUSH_BONUS, "As risadinhas viram grito. Os guardiões do círculo não perdoam quem pisa nele.")
		"hunter":
			if choice_id == "challenge":
				return _start_ambush("ambushed", HUNTER_DUEL_BONUS, "\"Sem rancor, hein\", ele fala, e arma o tabuleiro em cima de um tronco. Começou o duelo.")
			return _hunter_swap()
		"witch":
			if choice_id == "herbs":
				RunManager.spend_gold(WITCH_HERBS_COST)
				return "Ela embrulha umas ervas e, no meio delas, uma carta velha. %s" % _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.COMMON), "RECEBIDA")
			if outcome == "card":
				return "A poção borbulha em cima de você e deixa um desenho novo: uma carta. %s" % _give_card(_random_card(ActionCard.Rarity.RARE, ActionCard.Rarity.EPIC), "RECEBIDA")
			if outcome == "loss":
				var lost = _take_random_card()
				if lost != null:
					preview_hbox.add_child(_labeled_card_visual("PERDIDA", lost, Color(1.0, 0.6, 0.6, 0.8)))
					return "A poção borbulha em cima de você e apaga uma carta que você tinha:"
				return "A poção borbulha e escorre. Você não tinha nada pra ela apagar."
			RunManager.add_gold(WITCH_GOLD)
			return "Não acontece nada. A bruxa ri tanto da sua cara que te paga pela coragem: +%d de ouro." % WITCH_GOLD
		"monk":
			if choice_id == "alms":
				RunManager.add_gold(MONK_ALMS_GOLD)
				return "Você empurra as pedras do jardim de volta pro lugar. Ele paga sem abrir os olhos: +%d de ouro." % MONK_ALMS_GOLD
			return _monk_swap_law()
		"mirage":
			if choice_id == "dig":
				RunManager.add_gold(MIRAGE_DIG_GOLD)
				return "Onde o ar tremia, a areia estava fofa. Você cava e acha uma bolsa enterrada: +%d de ouro." % MIRAGE_DIG_GOLD
			if outcome == "oasis":
				return "A lagoa era de verdade! Na margem, uma carta esquecida por outro viajante. %s" % _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
			if outcome == "thirst":
				return "Era miragem. A areia quente racha a sua borda e o remendo custa %d de ouro." % _lose_gold(MIRAGE_THIRST_LOSS)
			RunManager.add_gold(MIRAGE_RUIN_GOLD)
			return "A lagoa some quando você chega. No lugar dela, um poço seco com moedas no fundo: +%d de ouro." % MIRAGE_RUIN_GOLD
		"sarcophagus":
			if choice_id == "loot":
				RunManager.add_gold(SARC_LOOT_GOLD)
				return "Você recolhe as moedas dos vasos, sem encostar na tampa: +%d de ouro." % SARC_LOOT_GOLD
			if outcome == "card":
				return "Entre faixas douradas, uma carta guardada pra outra vida. %s" % _give_card(_random_card(ActionCard.Rarity.RARE), "ENCONTRADA")
			if outcome == "curse":
				return "O frio sai da fresta e gruda em você. Ele só solta quando você deixa %d de ouro nos vasos." % _lose_gold(SARC_CURSE_GOLD)
			return _start_ambush("ambushed", SARC_AMBUSH_BONUS, "A tampa cai, e os guardiões da tumba se levantam da areia em volta!")
		"caravan":
			if choice_id == "bread":
				RunManager.spend_gold(CARAVAN_BREAD_COST)
				return "Ele te vende o maço mais barato, amarrado com barbante (-%d de ouro). %s" % [CARAVAN_BREAD_COST, _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.COMMON), "RECEBIDA")]
			RunManager.spend_gold(CARAVAN_RARE_COST)
			return "Ele olha pros lados, abre o baú do fundo e tira uma carta embrulhada em seda (-%d de ouro). %s" % [CARAVAN_RARE_COST, _give_card(_random_card(ActionCard.Rarity.RARE), "RECEBIDA")]
		"sphinx":
			if choice_id == "silence":
				RunManager.add_gold(SPHINX_SILENCE_GOLD)
				return "A esfinge ri baixinho, como quem aprova, e deixa cair uma moeda: +%d de ouro." % SPHINX_SILENCE_GOLD
			if choice_id == "time":
				if outcome == "law":
					return "A areia da ampulheta corre pra cima, e com ela sobe uma Lei esquecida. %s" % _give_random_law()
				return "A areia da ampulheta corre pra baixo e leva %d de ouro junto." % _lose_gold(SPHINX_WRONG_LOSS)
			if outcome == "card":
				return "A sua sombra se estica até a esfinge e volta trazendo uma carta. %s" % _give_card(_random_card(ActionCard.Rarity.RARE), "RECEBIDA")
			return _start_ambush("ambushed", SPHINX_AMBUSH_BONUS, "A sombra se levanta do chão, e não vem sozinha: guardiões de pedra saem da areia!")
		"sandstorm":
			if choice_id == "shelter":
				RunManager.add_gold(STORM_SHELTER_GOLD)
				return "Você espera dentro da torre. Quando o vento passa, a areia na porta deixou moedas à mostra: +%d de ouro." % STORM_SHELTER_GOLD
			if outcome == "win":
				RunManager.add_gold(STORM_WIN_GOLD)
				return "O vento varre uma duna inteira e deixa um baú à mostra: +%d de ouro." % STORM_WIN_GOLD
			if outcome == "loss":
				return "A areia rasga a sua bolsa e %d de ouro voam com o vento." % _lose_gold(STORM_LOSS_GOLD)
			return _start_ambush("ambushed", STORM_AMBUSH_BONUS, "Da cortina de areia saem peças escuras que usavam a tempestade de esconderijo!")
		"relics":
			if choice_id == "buy":
				RunManager.spend_gold(RELIC_BUY_COST)
				return "Ele tira uma carta de uma caixinha de cedro (-%d de ouro). %s" % [RELIC_BUY_COST, _give_card(_random_card(ActionCard.Rarity.COMMON), "RECEBIDA")]
			var sold = _take_random_card()
			if sold != null:
				RunManager.add_gold(RELIC_SELL_GOLD)
				preview_hbox.add_child(_labeled_card_visual("VENDIDA", sold, Color(1.0, 0.6, 0.6, 0.8)))
				return "O velho guarda a carta na caixinha e conta as moedas devagar: +%d de ouro." % RELIC_SELL_GOLD
			return "O velho olha tudo e balança a cabeça: \"Isso não vale nem a areia.\""
		"obelisk":
			if choice_id == "pray":
				RunManager.add_gold(OBELISK_PRAYER_GOLD)
				return "Na sombra do obelisco a areia é fresca, e meio enterradas nela, moedas antigas: +%d de ouro." % OBELISK_PRAYER_GOLD
			var given = _take_random_card()
			if given != null:
				preview_hbox.add_child(_labeled_card_visual("OFERECIDA", given, Color(1.0, 0.6, 0.6, 0.8)))
			return "Os hieróglifos acendem, a areia engole a carta e a pedra devolve o pedaço de Lei que guardava. %s" % _give_random_law()
		"scribe":
			if choice_id == "alms":
				RunManager.add_gold(SCRIBE_ALMS_GOLD)
				return "Você empilha os rolos em ordem enquanto ele escreve. Ele paga o serviço: +%d de ouro." % SCRIBE_ALMS_GOLD
			return _monk_swap_law("O escriba")
		"oasis":
			if choice_id == "drink":
				if outcome == "card":
					return "A água fria tira a areia da sua borda, e uma carta deixada como oferenda sobe junto. %s" % _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
				return "Embaixo da água tem lodo. Você afunda, e %d de ouro ficam presos lá." % _lose_gold(OASIS_FEVER_LOSS)
			RunManager.spend_gold(OASIS_WISH_COST)
			if outcome == "win":
				RunManager.add_gold(OASIS_WISH_GOLD)
				return "Uma fita se solta da estaca e cai na água. Quando ela afunda, a margem brilha de moedas: +%d de ouro." % OASIS_WISH_GOLD
			return "A moeda afunda e a água volta a ficar parada. Nada aconteceu (-%d de ouro)." % OASIS_WISH_COST
		"bandits":
			if choice_id == "setup":
				return _start_ambush("setup", BANDITS_SETUP_BONUS, "Você espera atrás da duna. Quando o bando volta, quem pega de surpresa é você.")
			if outcome == "card":
				return _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
			return _start_ambush("ambushed", BANDITS_SEARCH_AMBUSH_BONUS, "Um apito corta o ar. O bando não tinha ido longe.")
		"crystal_vein":
			if choice_id == "chip":
				RunManager.add_gold(VEIN_CHIP_GOLD)
				return "Você junta as lascas do chão sem encostar no cristal: +%d de ouro." % VEIN_CHIP_GOLD
			if outcome == "win":
				RunManager.add_gold(VEIN_WIN_GOLD)
				return "O cristal se parte limpo. Cada pedaço vale uma bolsa: +%d de ouro." % VEIN_WIN_GOLD
			if outcome == "loss":
				return "O teto racha junto com o cristal. Você escapa da pedra, mas %d de ouro ficam soterrados." % _lose_gold(VEIN_LOSS_GOLD)
			return _start_ambush("ambushed", VEIN_AMBUSH_BONUS, "O estalo ecoa pelas galerias. Quem mora lá embaixo veio ver o barulho.")
		"mirror_shard":
			if choice_id == "cover":
				RunManager.add_gold(SHARD_COVER_GOLD)
				return "Com o espelho coberto, dá pra juntar os cacos do chão sem ninguém olhando: +%d de ouro." % SHARD_COVER_GOLD
			if outcome == "card":
				return "O reflexo para de te imitar, pensa um pouco e empurra uma carta pra fora do vidro. %s" % _give_card(_random_card(ActionCard.Rarity.RARE), "RECEBIDA")
			if outcome == "loss":
				return "Por um instante vocês trocam de lugar. Quando você volta, %d de ouro ficaram do outro lado." % _lose_gold(SHARD_LOSS_GOLD)
			return _start_ambush("ambushed", SHARD_AMBUSH_BONUS, "O vidro estala. O reflexo sai do espelho, e traz outros reflexos junto.")
		"echo_miner":
			if choice_id == "listen":
				RunManager.add_gold(MINER_LISTEN_GOLD)
				return "Vocês ficam encostados na pedra até o eco contar onde tem minério. Ele divide o achado: +%d de ouro." % MINER_LISTEN_GOLD
			return _hunter_swap(MINER_SWAP_COST, "O mineiro")
		"ore_cart":
			if choice_id == "sift":
				RunManager.add_gold(CART_SIFT_GOLD)
				return "Você pula na carga, junta o que brilha e pula fora antes do fim do trilho: +%d de ouro." % CART_SIFT_GOLD
			if outcome == "win":
				RunManager.add_gold(CART_WIN_GOLD)
				return "O freio morde o trilho e o carrinho para bem na sua frente. A carga é sua: +%d de ouro." % CART_WIN_GOLD
			if outcome == "loss":
				return "A alavanca quebra, o carrinho passa raspando e arrasta a sua bolsa trilho abaixo: -%d de ouro." % _lose_gold(CART_LOSS_GOLD)
			return _start_ambush("ambushed", CART_AMBUSH_BONUS, "O carrinho bate no fim do trilho com um estrondo. O barulho acordou a mina inteira.")
		"echo_chamber":
			if choice_id == "silence":
				RunManager.add_gold(ECHO_SILENCE_GOLD)
				return "Você fica parado até o último eco morrer. No chão, onde o som parou, uma moeda: +%d de ouro." % ECHO_SILENCE_GOLD
			if choice_id == "shout":
				if outcome == "law":
					return "As duas batidas voltam ao mesmo tempo, a fenda se abre e mostra uma Lei gravada lá dentro. %s" % _give_random_law()
				return "As batidas voltam desencontradas, a câmara treme e %d de ouro rolam pra dentro da fenda." % _lose_gold(ECHO_WRONG_LOSS)
			if outcome == "card":
				return "A pedrinha bate no fundo e o som volta duas vezes. Na segunda, vem uma carta junto. %s" % _give_card(_random_card(ActionCard.Rarity.RARE), "RECEBIDA")
			return _start_ambush("ambushed", ECHO_AMBUSH_BONUS, "O som volta, mas quem responde são passos. Alguém escutou.")
		"prospectors":
			if choice_id == "setup":
				return _start_ambush("setup", PROSPECT_SETUP_BONUS, "Você apaga a lanterna e espera no escuro. Quando eles voltam, quem pega de surpresa é você.")
			if outcome == "card":
				return _give_card(_random_card(ActionCard.Rarity.COMMON, ActionCard.Rarity.RARE), "ENCONTRADA")
			return _start_ambush("ambushed", PROSPECT_SEARCH_AMBUSH_BONUS, "As sombras do fundo se mexem. Eram eles, parados no escuro, te olhando o tempo todo.")
		"mirror_altar":
			if choice_id == "gaze":
				RunManager.add_gold(MIRROR_ALTAR_GOLD)
				return "Sua versão mais velha te encara um tempão e depois assente, como quem reconhece alguém. Uma moeda cai do altar: +%d de ouro." % MIRROR_ALTAR_GOLD
			var offered = _take_random_card()
			if offered != null:
				preview_hbox.add_child(_labeled_card_visual("OFERECIDA", offered, Color(1.0, 0.6, 0.6, 0.8)))
			return "A mão de cristal fecha na carta e volta pro espelho. Quando sai de novo, traz uma Lei. %s" % _give_random_law()
		"nomad":
			if choice_id == "challenge":
				return _start_ambush("ambushed", NOMAD_DUEL_BONUS, "Ele guarda a moeda, estende o tapete e arruma as peças. \"Sem rancor.\" Começou o duelo.")
			return _nomad_swap()
	return ""

# Marca o desfecho como duelo (o botão vira "LUTAR!"); devolve o texto da cena.
func _start_ambush(kind: String, bonus_gold: int, flavor: String) -> String:
	pending_ambush_kind = kind
	pending_ambush_bonus = bonus_gold
	return flavor

# Perde até `amount` de ouro (nunca abaixo de 0); devolve o quanto perdeu de verdade.
func _lose_gold(amount: int) -> int:
	var real = mini(amount, RunManager.gold)
	RunManager.gold -= real
	return real

# Sorteia uma carta com raridade entre min e max (padrão: até a mais alta).
func _random_card(min_rarity: int, max_rarity: int = ActionCard.Rarity.LEGENDARY) -> ActionCard:
	var pool = LootTables.get_player_action_cards().filter(func(c): return c.rarity >= min_rarity and c.rarity <= max_rarity)
	if pool.is_empty():
		pool = LootTables.get_all_action_cards().filter(func(c): return c.rarity >= min_rarity and c.rarity <= max_rarity)
	if pool.is_empty():
		pool = LootTables.get_all_action_cards()
	return LootTables.pick_weighted_actions(pool, 1)[0]

# Adiciona a carta ao baralho; se estiver cheio, vira ouro (metade do preço).
func _give_card(card: ActionCard, caption: String) -> String:
	preview_hbox.add_child(_labeled_card_visual(caption, card, Color(1.2, 1.15, 0.85)))
	if RunManager.add_card_to_deck(card):
		return "Você ganhou uma carta:"
	var compensation = int(card.cost_gold / 2.0)
	RunManager.add_gold(compensation)
	return "Seu baralho tá cheio, então ela vira +%d de ouro." % compensation

func _take_random_card() -> ActionCard:
	if RunManager.player_deck.is_empty():
		return null
	var card: ActionCard = RunManager.player_deck[randi() % RunManager.player_deck.size()]
	RunManager.player_deck.erase(card)
	return card

func _upgradable_cards() -> Array:
	return RunManager.player_deck.filter(func(c: ActionCard): return c.rarity < ActionCard.Rarity.LEGENDARY)

func _forge_card() -> String:
	var candidates = _upgradable_cards()
	if candidates.is_empty():
		return "Não há nada que ele possa melhorar."
	RunManager.spend_gold(FORGE_COST)
	var old_card: ActionCard = candidates[randi() % candidates.size()]
	var target_rarity = old_card.rarity + 1
	var pool = LootTables.get_player_action_cards().filter(func(c): return c.rarity == target_rarity and c.id != old_card.id)
	if pool.is_empty():
		pool = LootTables.get_all_action_cards().filter(func(c): return c.rarity == target_rarity and c.id != old_card.id)
	if pool.is_empty():
		return "A forja esfria e não rende nada. Você recebe o ouro de volta."
	var upgraded: ActionCard = pool[randi() % pool.size()]
	var idx = RunManager.player_deck.find(old_card)
	RunManager.player_deck[idx] = upgraded
	_add_transform(_card_visual(old_card, TRANSFORM_CARD_SCALE), _card_visual(upgraded, TRANSFORM_CARD_SCALE), "forge",
		ActionCardVisual.get_rarity_color(upgraded.rarity), "ANTES", "FORJADA")
	return "A carta sai da forja transformada (-%d de ouro):" % FORGE_COST

# Caçador: troca 1 carta aleatória do baralho por outra da MESMA raridade (outro id).
func _hunter_swap(cost: int = HUNTER_SWAP_COST, who: String = "O caçador") -> String:
	if RunManager.player_deck.is_empty():
		return "%s não vê nenhuma carta pra trocar." % who
	var old_card: ActionCard = RunManager.player_deck[randi() % RunManager.player_deck.size()]
	var pool = LootTables.get_player_action_cards().filter(func(c: ActionCard): return c.rarity == old_card.rarity and c.id != old_card.id)
	if pool.is_empty():
		pool = LootTables.get_all_action_cards().filter(func(c: ActionCard): return c.rarity == old_card.rarity and c.id != old_card.id)
	if pool.is_empty():
		return "%s balança a cabeça: não tem troca justa pra essa carta. Seu ouro fica com você." % who
	RunManager.spend_gold(cost)
	var new_card: ActionCard = LootTables.pick_weighted_actions(pool, 1)[0]
	RunManager.player_deck[RunManager.player_deck.find(old_card)] = new_card
	_add_transform(_card_visual(old_card, TRANSFORM_CARD_SCALE), _card_visual(new_card, TRANSFORM_CARD_SCALE), "swap",
		ActionCardVisual.get_rarity_color(new_card.rarity), "ANTES", "TROCADA")
	return "%s fecha negócio (-%d de ouro):" % [who, cost]

# Nômade: mesma troca do Caçador (mesma raridade), com o custo e a fala do deserto.
func _nomad_swap() -> String:
	var res: String = _hunter_swap(NOMAD_SWAP_COST, "O nômade")
	return res

# Monge: revoga 1 Lei aleatória e entrega outra que o jogador ainda não tem.
func _monk_swap_law(who: String = "O monge") -> String:
	if RunManager.active_rules.is_empty():
		return "%s não encontra nenhuma Lei sua para reescrever." % who
	var old_rule: RuleCard = RunManager.active_rules[randi() % RunManager.active_rules.size()]
	var owned_ids: Array[String] = []
	for r in RunManager.active_rules:
		owned_ids.append(r.id)
	var pool = LootTables.get_player_rules().filter(func(r: RuleCard): return not owned_ids.has(r.id))
	if pool.is_empty():
		pool = LootTables.get_all_rules().filter(func(r: RuleCard): return not owned_ids.has(r.id))
	pool.shuffle()
	RunManager.remove_rule(old_rule.id)
	for cand in pool:
		if RunManager.add_rule(cand):
			RunManager.spend_gold(MONK_SWAP_COST)
			_add_transform(_law_visual(old_rule, TRANSFORM_LAW_SCALE), _law_visual(cand, TRANSFORM_LAW_SCALE), "law",
				Color(0.72, 0.55, 1.0), "REVOGADA", "NOVA LEI")
			return "%s reescreve suas leis (-%d de ouro):" % [who, MONK_SWAP_COST]
	# Nenhuma serviu (todas incompatíveis ou sem opções): devolve a original.
	RunManager.add_rule(old_rule)
	return "%s não acha Lei melhor pra você. Seu ouro fica com você." % who

func _give_random_law() -> String:
	var owned_ids: Array[String] = []
	for r in RunManager.active_rules:
		owned_ids.append(r.id)
	var pool = LootTables.get_player_rules().filter(func(r: RuleCard): return not owned_ids.has(r.id))
	if pool.is_empty():
		pool = LootTables.get_all_rules().filter(func(r: RuleCard): return not owned_ids.has(r.id))
	if pool.is_empty():
		RunManager.add_gold(10)
		return "Você já conhece todas as Leis. A pedra devolve +10 de ouro."
	var rule: RuleCard = LootTables.pick_weighted_rules(pool, 1)[0]
	if RunManager.add_rule(rule):
		preview_hbox.add_child(_labeled_law_visual("NOVA LEI", rule, Color(1.2, 1.15, 0.85)))
		return "Uma Lei se revela:"
	# Limite de Leis: o jogador escolhe qual revogar.
	discard_modal.prompt_replace(rule)
	return "Suas Leis tão lotadas. Escolhe qual vai sair."

func _on_reward_law_replaced(_old: RuleCard, new_rule: RuleCard) -> void:
	_set_fit_text(status_label, "Uma Lei se revela:", 40)
	preview_hbox.add_child(_labeled_law_visual("NOVA LEI", new_rule, Color(1.2, 1.15, 0.85)))

func _on_reward_law_declined() -> void:
	_set_fit_text(status_label, "Você recusou a Lei oferecida.", 40)

func _on_leave_pressed() -> void:
	if pending_ambush_kind != "":
		# Escaramuça 6x6 forçada; ao vencer, volta pro mapa (nó do "?" já consumido).
		RunManager.ambush_kind = pending_ambush_kind
		RunManager.ambush_bonus_gold = pending_ambush_bonus
		RunManager.current_node_type = MapNode.NodeType.Duelo
		RunManager.current_board_size = RunManager.AMBUSH_BOARD_SIZE
		RunManager.current_board_layout = Board.LAYOUT_CLASSIC
		SceneTransition.go("res://scenes/main.tscn")
		return
	SceneTransition.go(MAP_SCENE_PATH)

# Pré-visualizações (mesmo padrão da BetView).
# Carta / Lei com tooltip no hover, sem legenda (usado pela tela de transformação).
func _card_visual(card: ActionCard, sc: float) -> Control:
	var visual = ActionCardVisual.new(card, true, sc)
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if card_tooltip:
			card_tooltip.show_tooltip(card, visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0)))
	visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip())
	return visual

func _law_visual(rule: RuleCard, sc: float) -> Control:
	var visual = RuleCardVisual.new(rule, null, true, sc)
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if rule_tooltip:
			rule_tooltip.show_tooltip(rule, visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0)))
	visual.mouse_exited.connect(func():
		if rule_tooltip:
			rule_tooltip.hide_tooltip())
	return visual

func _add_transform(old_v: Control, new_v: Control, kind: String, accent: Color, old_cap: String, new_cap: String) -> void:
	var tr := TransformReveal.new(old_v, new_v, kind, accent, old_cap, new_cap)
	preview_hbox.add_child(tr)
	if skip_animations:
		tr.finish_now()

func _labeled_card_visual(caption: String, card: ActionCard, tint: Color) -> Control:
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(label)
	var visual = ActionCardVisual.new(card, true, PREVIEW_SCALE)
	visual.modulate = tint
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if card_tooltip:
			card_tooltip.show_tooltip(card, visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0))
	)
	visual.mouse_exited.connect(func():
		if card_tooltip:
			card_tooltip.hide_tooltip()
	)
	box.add_child(visual)
	return box

func _labeled_law_visual(caption: String, rule: RuleCard, tint: Color) -> Control:
	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(label)
	var visual = RuleCardVisual.new(rule, null, true, PREVIEW_SCALE)
	visual.modulate = tint
	visual.mouse_filter = Control.MOUSE_FILTER_STOP
	visual.mouse_entered.connect(func():
		if rule_tooltip:
			rule_tooltip.show_tooltip(rule, visual.global_position + Vector2(visual.custom_minimum_size.x / 2.0, 0.0))
	)
	visual.mouse_exited.connect(func():
		if rule_tooltip:
			rule_tooltip.hide_tooltip()
	)
	box.add_child(visual)
	return box
