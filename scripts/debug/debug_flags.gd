class_name DebugFlags
extends RefCounted

# Chave geral dos atalhos de debug. Ponha false antes de exportar a build:
#   B  (mapa)        -> abre a casa de apostas direto
#   E  (mapa)        -> abre um evento "?" direto
#   1-6 (mapa)       -> abre um duelo de CHEFE com a lei escolhida
#                       (1 Sapo, 2 Coruja, 3 Floresta, 4 Cipós, 5 Vaga-lumes, 6 Raízes)
#   botão TRANS (canto inferior direito, qualquer tela) -> painel com um botão por
#                       estilo de transição, paleta e Chefe
#   F6 / F7 (qualquer tela) -> TESTA as transições de cena: F6 próxima, F7 anterior
#                       (mostra o nome do estilo); F8 alterna a paleta de Chefe;
#                       F9 alterna a paleta (floresta, deserto, tutorial, menu)
#   teclas no duelo  -> DebugRuleConsole (vencer, perder, alternar leis...)
#   (o reset de progresso agora é o botão RESETAR PROGRESSO nas configurações)
# Continua exigindo build de debug onde já exigia (OS.is_debug_build()).
const SHORTCUTS: bool = true

# Pré-visualização de bioma do mapa: "" = segue o RunManager (floresta);
# "deserto" força o Deserto das Torres em qualquer run NOVA (mapa, fundos dos
# duelos/loja/aposta e cores das transições). Deixe "" na build final.
const MAP_BIOME_OVERRIDE: String = "deserto"
