# powerbi-plugin

Plugin do Claude Code para Power BI: servidor MCP da Microsoft (`.mcp.json`, via `npx`), skills em `skills/` e documentação (`README.md`). Visão de uso e instalação no `README.md`. Estado e decisões no vault pessoal.

## Contexto
- Projeto pessoal e público (GitHub `armandonettox`). O objetivo é um plugin genérico, que qualquer pessoa instala e que o dono leva para qualquer empresa.
- Conteúdo do plugin (skills, references, README, NOTICE) em inglês. Este arquivo e a conversa com o dono em português.
- Nomes de arquivos e pastas em minúsculo com hífen. Comentários simples e naturais, sem emojis.

- Suporte só a Windows (decisão do dono): o `.mcp.json` usa `cmd /c npx` e o script de captura é PowerShell. Não prometer Linux nem macOS na documentação. **Motivação:** não há como testar Linux neste notebook, e uma promessa sem teste vira reclamação de usuário.

## Mapa
- `.claude-plugin/`: `plugin.json` e `marketplace.json`.
- `.mcp.json`: sobe o `powerbi-modeling-mcp` com `cmd /c npx -y @microsoft/powerbi-modeling-mcp@<versão> --start`.
- `skills/powerbi-mcp/`: `SKILL.md` e `references/` (24 arquivos). Origem: `semantic-model-authoring` da Microsoft, traduzida, limpa e estendida.
- `skills/power-bi-dax-optimization/`: cópia sem mudanças da skill do `github/awesome-copilot`.
- `skills/power-bi-screenshot/`: `SKILL.md` e `scripts/capture-screenshot.ps1`.
- `README.md` (inglês, principal) e `README.pt-BR.md` (português). Imagens em `docs/`; os diagramas em português ficam em `docs/pt-BR/` (gerados a partir dos SVGs em inglês).
- `LICENSE` (MIT do dono) e `NOTICE` (créditos e texto MIT de Microsoft e GitHub).

## Comandos
- Validar o plugin antes de commitar: `claude plugin validate . --profile directory`.
- Conferir resíduos: buscar em `skills/` por nomes de empresa, `vault`, `L-NNN`, caminhos `C:\Users`, datas de sessão e acentos (o conteúdo é todo em inglês).
- Conferir links e âncoras entre `SKILL.md` e `references/` depois de qualquer mudança de título.

## Regras
1. **Nenhum dado de empresa ou pessoal no repositório.** Sem nome de empresa, projeto, relatório, tabela real, caminho do usuário, e-mail, ID de plano ou de pessoa, nem arquivos `.pbix`/`.pbip`. Exemplos usam nomes genéricos (Sales, Customer). Antes de cada commit, buscar nos arquivos alterados. **Motivação:** o repositório é público e o dono usa o mesmo notebook para trabalho e projetos pessoais; dado corporativo (LGPD) nunca vai para remoto pessoal, e repo público não tem como "desenviar".

2. **O plugin não aceita o EULA da Microsoft em nome de ninguém.** O `.mcp.json` nunca leva `--accept-eula` nem a variável de aceite; o README explica as 3 formas de aceitar. **Motivação:** aceitar um contrato por quem instala, sem a pessoa ler, é decisão dela, não do plugin. O README é o lugar que dá a informação para ela decidir.

3. **Manter o crédito e a licença das skills de terceiros.** `NOTICE` com o copyright de Microsoft Corporation e GitHub, Inc. e o texto MIT acompanha qualquer cópia. Skill nova de terceiros entra no `NOTICE` com origem e licença conferidas no `LICENSE` do repositório de origem, não em página de terceiros. **Motivação:** a licença MIT exige manter o aviso de copyright; sem isso a publicação viola os termos.

4. **Não redistribuir o servidor MCP.** O plugin só o executa via `npx`, com a versão fixada no `.mcp.json`. Subir a versão só depois de testar o servidor (handshake `initialize` e `tools/list`) e ler as notas de versão. **Motivação:** o servidor tem EULA próprio, e uma versão fixada evita que uma atualização do pacote mude o comportamento de quem instalou.

5. **Regra nova de skill ou reference leva motivação e entra genérica.** Aprendizado que veio de uma sessão real entra sem empresa, projeto, data ou número de learning, mantendo a regra técnica e o porquê. Arquivo novo em `references/` ganha entrada na tabela de tópicos do `SKILL.md`. **Motivação:** sem o porquê a IA segue a regra cegamente; sem entrada na tabela o arquivo nunca é carregado.

6. **A skill `powerbi-mcp` aqui diverge da cópia pessoal em `~/.claude/skills`.** Melhoria genérica feita lá deve ser trazida para cá limpa; o que for específico de uma empresa fica só lá. Não manter as duas ativas ao mesmo tempo. **Motivação:** duas skills com o mesmo nome carregam instruções duplicadas e podem se contradizer.

7. **Visuais e documentação seguem a paleta aprovada em 2026-11-25**, tema claro e escuro, fonte Inter:

   | Papel | Claro | Escuro |
   |---|---|---|
   | Fundo | `#F7F8FA` | `#12151C` |
   | Texto | `#1A1F2B` | `#E8EAF0` |
   | Acento principal (fluxo, links) | `#4F5BD5` | `#8B93F0` |
   | Dados e modelo | `#E8A317` | `#F2B84B` |
   | Verificado e sucesso | `#2E9E6B` | `#4CC38A` |

   Diagramas em SVG com `prefers-color-scheme`, título e descrição para leitores de tela. Texto sempre em SVG, nunca dentro de imagem gerada por IA (os geradores erram acentos e palavras); imagens do Gemini ficam sem texto, sem logotipo da Microsoft e sem o amarelo e preto da marca Power BI. Cores num lugar só (variáveis CSS). **Motivação:** cada projeto visual pessoal tem identidade própria aprovada pelo dono (regra 1 do `AGENTS.md` pessoal). O índigo dá identidade própria, o âmbar lembra painéis de dados sem imitar a marca e o verde fica reservado para "conferido". Evitar o amarelo e preto evita parecer produto oficial da Microsoft.

8. **Os dois READMEs andam juntos.** Qualquer mudança em `README.md` entra em `README.pt-BR.md` no mesmo commit, e mudança num diagrama de `docs/` exige refazer o de `docs/pt-BR/` (texto do diagrama traduzido, conferido renderizado para não cortar). A descrição do repositório no GitHub (campo About) fica em português. **Motivação:** duas versões que divergem fazem o leitor de uma delas seguir instruções velhas ou erradas, e texto em português mais longo corta dentro das caixas do SVG.

## Referência
- AGENTS.md global (`~/AGENTS.md`) e pessoal (`~/armandonettox/AGENTS.md`): regras gerais de commits (em português, sem atribuição de IA), comentários, emojis e nomes.
- Licenças conferidas em 2026-11-25: `microsoft/skills-for-fabric` (MIT, Microsoft Corporation), `github/awesome-copilot` (MIT, GitHub, Inc.), `@microsoft/powerbi-modeling-mcp` (EULA da Microsoft).
