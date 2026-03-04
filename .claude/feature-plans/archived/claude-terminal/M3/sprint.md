# Sprint M3 — DMG público
_Gerado em: 2026-03-01_

## Milestone

**Objetivo:** 10 usuários externos instalaram e usaram sem ajuda.

**Critério de done:** 10 instalações em Macs que não são os seus, sem você ajudar a instalar. Pelo menos 2 delas reportaram um bug espontaneamente.

## Features (ordem de execução)

| # | Feature | Slug | Deps | Esforço | Status |
|---|---------|------|------|---------|--------|
| 1 | Service que lê/valida/escreve `~/.claude/settings.json` atomicamente com allowlist (zero config manual para hooks) | `hook-installer-service` | — | baixo | ✅ done |
| 2 | GitHub Actions: `xcodebuild archive` → sign Developer ID → `xcrun notarytool` → staple → create-dmg → GitHub Release | `release-pipeline` | — | alto | ✅ done |
| 3 | OnboardingView (first launch) com botão "Set up hooks" que chama o service + badge de status instalado/não instalado | `hook-setup-onboarding` | `hook-installer-service` | baixo | ✅ done |
| 4 | README.md com GIF do HITL flow + instruções de instalação (download DMG + 1-click hook setup) + badge macOS 14+ | `readme-demo` | — | baixo | ✅ done |
| 5 | Integrar Sparkle 2.x: dependência SPM, EdDSA key gen, `appcast.xml`, auto-check no launch | `sparkle-autoupdate` | `release-pipeline` | médio | ✅ done |
| 6 | PR para `hesreallyhim/awesome-claude-code` + rascunho do Show HN post | `launch-distribution` | `hook-setup-onboarding`, `release-pipeline`, `readme-demo` | baixo | ✅ done |

## Grafo de dependências

```
hook-installer-service → hook-setup-onboarding
release-pipeline       → sparkle-autoupdate
hook-setup-onboarding, release-pipeline, readme-demo → launch-distribution
readme-demo (independente)
```

## Critério de granularidade

Uma feature está bem-scoped quando:

- Toca 1–3 arquivos principais
- Tem um "demonstrável" claro (tela que aparece, teste que passa, endpoint que responde)
- Pode ser implementada em 1 sessão de Claude Code sem `/clear` intermediário
- Nome kebab-case descreve o QUÊ, não o PORQUÊ

## Estado atual (atualizado 2026-03-01)

- `hook-installer-service` ✅ done
- `release-pipeline` ✅ done (PR #11)
- `hook-setup-onboarding` ✅ done (PR #10)
- `sparkle-autoupdate` ✅ done
- `readme-demo` ✅ done
- `launch-distribution` ✅ done

## Próximo passo

M3 completo. Todas as features entregues.
