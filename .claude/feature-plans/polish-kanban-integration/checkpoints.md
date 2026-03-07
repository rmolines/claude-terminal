## Checkpoint 1 — Deliverable 1

_2026-03-06T18:02:57Z_

### O que foi construído

`backlog.json` ganhou `"chores": []` top-level. `polish.md` ganhou: deteccao de `--close`
(guard de branch + jq status update + delete local/remote), Passo 5 com `swift test` +
RenderPreview checklist para itens de UI, e Passo 6b que escreve entrada em `chores[]`
apos criar o PR.

### Assuncoes validadas

- [verified] Nenhum dos arquivos e hot file do CLAUDE.md — confirmado, sem conflitos
- [verified] Padrao REPO_ROOT + jq null-safe funciona para nova key `chores` — make check verde

### Assuncoes ainda em aberto

- [assumed] `jq` disponivel na maquina do dev — nao testado diretamente, skip silencioso como fallback

### Resposta do usuario

> como eu valido? / sim
