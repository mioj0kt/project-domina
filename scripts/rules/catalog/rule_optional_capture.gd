class_name RuleOptionalCapture
extends RuleCard

func _init() -> void:
	id = "optional_capture"
	name = "Captura Opcional"
	description = "Você não é obrigado a capturar. Os movimentos comuns continuam valendo."
	category = Category.CAPTURE
	scope = Scope.PLAYER_ONLY
	priority = 20

func evaluate_mandatory_capture(_team: int, _default_mandatory: bool) -> bool:
	return false # Captura vira escolha do jogador
