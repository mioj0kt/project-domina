class_name RulePolarLight
extends RuleCard

# A faixa da aurora é movida por DuelBossCume; aqui só se consome o escudo
# (BoardPiece.polar_shield) quando alguém tenta capturar a peça protegida.

func _init() -> void:
	id = "polar"
	boss_law = true
	name = "Luz Polar"
	description = "No fim de cada turno do chefe a aurora ilumina uma fileira (a próxima fica marcada mais fraca). As peças do chefe nela ganham escudo: a próxima captura contra cada uma falha (quem pulou pousa, a peça fica). A faixa sobe e desce pelo tabuleiro."
	category = Category.BOSS
	scope = Scope.BOTH
	priority = 1
	cost = 0

func try_prevent_capture(victim: BoardPiece, _board: RefCounted) -> bool:
	if victim != null and victim.polar_shield:
		victim.polar_shield = false
		return true
	return false
