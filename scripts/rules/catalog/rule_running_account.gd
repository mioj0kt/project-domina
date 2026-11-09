class_name RuleRunningAccount
extends RuleCard

# Cada captura DENTRO de um combo paga 2, 4, 6, 8... moedas, e a escada continua
# subindo pelo duelo inteiro. Ex.: combo de 2 = +2 +4; depois combo de 3 = +6 +8 +10.
# Ouro direto (sem o teto de ouro de efeitos): a escada é o ponto da Lei.
const STEP: int = 2
var ladder: int = 0

func _init() -> void:
	id = "running_account"
	name = "Lei da Conta Corrente"
	description = "Cada captura de um combo rende ouro, e o valor sobe a cada captura de combo do duelo: +2, +4, +6, +8... (um combo de 2 rende +2 +4; o próximo, de 3, rende +6 +8 +10)."
	category = Category.COMBO
	scope = Scope.PLAYER_ONLY
	rarity = Rarity.EPIC
	priority = 17

func on_game_event(event_name: StringName, context: Dictionary, board: RefCounted) -> void:
	if event_name == &"duel_started":
		ladder = 0
		return
	if event_name != &"combo_ended":
		return
	var total: int = 0
	for i in range(int(context.get("count", 0))):
		ladder += 1
		total += STEP * ladder
	if total > 0 and RunManager != null:
		RunManager.add_gold(total)
		board.rule_fired.emit(id)
