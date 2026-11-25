<p align="center">
  <b>Português (Brasil)</b> | <a href="README.md">English</a>
</p>

<p align="center">
  <img src="docs/cover.png" alt="Ilustração de um modelo de dados com tabelas ligadas alimentando um painel" width="760">
</p>

<h1 align="center">powerbi-plugin</h1>

<p align="center">
  Trabalhe com modelos semânticos, DAX e visuais de relatório do Power BI pelo <a href="https://claude.com/claude-code">Claude Code</a>, com travas que perguntam antes de qualquer passo arriscado.
</p>

<p align="center">
  <img alt="Licença: MIT" src="https://img.shields.io/badge/licen%C3%A7a-MIT-4F5BD5">
  <img alt="Plataforma: Windows" src="https://img.shields.io/badge/plataforma-Windows-4F5BD5">
  <img alt="Plugin do Claude Code" src="https://img.shields.io/badge/Claude%20Code-plugin-E8A317">
</p>

---

## O que vem no plugin

| Parte | O que faz |
|---|---|
| **Servidor MCP** `powerbi-modeling-mcp` | Servidor da Microsoft para ler e alterar um modelo semântico: tabelas, colunas, medidas, relacionamentos, consultas DAX, partições, funções de segurança e mais. É iniciado com `npx` e nunca vem embutido. |
| **Skill** `powerbi-mcp` | Escolhe a ferramenta e o método certos para criar ou inspecionar um modelo, DAX e visuais de relatório (PBIR). Traz 24 arquivos de referência: padrões de DAX, regras de modelagem, TMDL, PBIP e um catálogo de erros comuns com a forma de evitá-los. |
| **Skill** `power-bi-dax-optimization` | Analisa uma fórmula DAX e propõe uma versão mais rápida e legível. |
| **Skill** `power-bi-screenshot` | Tira uma captura de tela da janela do Power BI Desktop aberta, para conferir uma alteração olhando o resultado. |
| **Skill** `powerbi-setup` | Instala e configura o plugin até funcionar e prova com uma verificação. Feita para ser conduzida por um agente. |

<p align="center">
  <img src="docs/pt-BR/architecture.svg" alt="Como o plugin liga o Claude Code ao Power BI Desktop, a arquivos PBIP e ao Fabric" width="900">
</p>

## Instalação

<p align="center">
  <img src="docs/pt-BR/flow-install.svg" alt="Quatro etapas: adicione o marketplace, instale o plugin, aceite o EULA da Microsoft você mesmo e peça ao Claude" width="900">
</p>

No Claude Code:

```text
/plugin marketplace add armandonettox/powerbi-plugin
/plugin install powerbi@powerbi-plugin
```

Se as skills ou o servidor MCP não aparecerem logo depois de instalar, reinicie o Claude Code.

### Instalar com um agente

Prefere que um agente faça isso? Cole no seu agente:

```text
Instale o plugin do Power BI neste computador seguindo as instruções de
https://raw.githubusercontent.com/armandonettox/powerbi-plugin/main/skills/powerbi-setup/SKILL.md
Diga o que vai alterar antes de alterar e não aceite nenhum contrato de licença por mim.
```

O agente lê a skill `powerbi-setup`, confere o Node.js, instala, pede para você ler e aceitar a licença da Microsoft por conta própria e termina rodando uma verificação que prova que o servidor inicia.

| Agente | Situação |
|---|---|
| Claude Code | Suportado e testado |
| Codex e outros agentes | Melhor esforço, não testado pelo autor. A skill traz os passos e sempre termina com a mesma verificação, que diz se funcionou. |

O link aponta para um arquivo deste repositório. Abra antes, se quiser ver o que o seu agente vai receber como instrução.

### Requisitos

- **Windows.** Este plugin suporta somente Windows: o Power BI Desktop e o script de captura são só para Windows, e o `.mcp.json` inicia o servidor na forma do Windows, `cmd /c npx`. O servidor da Microsoft também é publicado para Linux, mas essa configuração não é testada nem suportada aqui.
- [Power BI Desktop](https://www.microsoft.com/power-platform/products/power-bi/desktop) para edição ao vivo. Sem ele, a skill ainda edita arquivos PBIP/TMDL em disco.
- [Node.js](https://nodejs.org/) (para o `npx`). O servidor é baixado na primeira execução.
- Claude Code.

### Aceite o EULA da Microsoft (obrigatório)

O servidor MCP de modelagem do Power BI é um software da Microsoft distribuído sob um Contrato de Licença de Usuário Final (EULA) próprio. Este plugin **não** o aceita por você. Leia o contrato em <https://go.microsoft.com/fwlink/?LinkId=2381247> e aceite de um destes jeitos (conforme a documentação do próprio servidor):

| Jeito | Como | Fica salvo? |
|---|---|---|
| Variável de ambiente | Defina `PBI_MODELING_MCP_ACCEPT_EULA=true` antes de abrir o Claude Code | Não, vale para o processo em execução |
| Linha de comando | Acrescente `--accept-eula` aos `args` do servidor na sua própria cópia da configuração do MCP | Não, vale para o processo em execução |
| Ferramenta do MCP | Peça ao Claude para chamar a ferramenta `accept_eula` do servidor com o endereço do contrato | Sim |

## Como uma alteração é feita

<p align="center">
  <img src="docs/pt-BR/flow-edit-model.svg" alt="Você pede, a skill checa o contexto, conecta, altera e testa, e pergunta a você antes de atualizar ou salvar" width="900">
</p>

1. **Você pede** em linguagem natural.
2. **Checagem de contexto.** A skill olha o nome do arquivo e o workspace. Se o modelo parecer de um contexto diferente do da sessão atual (por exemplo, um modelo de empresa numa sessão pessoal), ela para e pergunta antes de conectar.
3. **Conexão** com a instância aberta do Desktop. A porta muda a cada abertura do Desktop, então a skill procura de novo.
4. **Altera e testa.** As edições passam pelo MCP e o resultado é conferido com uma consulta DAX.
5. **Você confirma.** A skill pergunta antes de atualizar os dados (Refresh) e antes de editar o JSON do relatório com o modelo aberto.

## Experimente

Abra um modelo no Power BI Desktop e peça, por exemplo:

- "Liste as medidas do modelo aberto e aponte as que estão sem descrição."
- "Crie uma medida de vendas acumuladas no ano e coloque na tabela de medidas."
- "Por que esta matriz está lenta? Otimize a medida."
- "Tire uma captura de tela do relatório e diga se a legenda cobre o gráfico."

A skill `powerbi-mcp` carrega sozinha quando o pedido é sobre modelo semântico, DAX ou visual de relatório.

## Segurança

- **Pergunta antes de passos arriscados.** Atualizar dados (Refresh) e editar o JSON do relatório com o modelo aberto exigem o seu aval a cada vez. Uma autorização vale para uma ação, não para a próxima.
- **Trava de contexto.** Para antes de conectar quando o arquivo ou o workspace parece dado de outro contexto.
- **Seus dados ficam com você.** O plugin não contém dados, credenciais nem arquivos do Power BI. O servidor roda na sua máquina.
- **A captura mostra o que está na tela.** O script copia a área onde a janela do Desktop está. Se o Windows impedir de trazer a janela para a frente, outra janela por cima pode aparecer na imagem. Confira a imagem antes de compartilhar.
- **Telemetria.** A skill de autoria vem da Microsoft e mantém a exigência original do cabeçalho `x-ms-fabric-skill` nas chamadas à API do Fabric.

## Solução de problemas

| Problema | O que fazer |
|---|---|
| As ferramentas não funcionam no primeiro uso | Confirme que você aceitou o EULA (veja acima). A variável e a flag precisam estar presentes toda vez que o servidor inicia. |
| As ferramentas falham depois de reabrir o Desktop | A conexão se perde e a porta muda. Peça ao Claude para listar as instâncias locais e conectar de novo. |
| O `npx` não é encontrado | Instale o Node.js e reinicie o Claude Code. |
| A captura mostra a janela errada | Feche ou mova a janela que cobre o Desktop e rode de novo. |
| Você quer uma versão mais nova do servidor | A versão está fixada no `.mcp.json`. Troque depois de ler as notas de versão da Microsoft. |

## Créditos e licenças

Este plugin usa a licença MIT (veja [LICENSE](LICENSE)). Ele inclui material sob licença MIT da Microsoft e do GitHub, listado em [NOTICE](NOTICE):

- `semantic-model-authoring`, da Microsoft Corporation, de [microsoft/skills-for-fabric](https://github.com/microsoft/skills-for-fabric), incluída aqui como `powerbi-mcp`, traduzida e ampliada.
- `power-bi-dax-optimization`, do GitHub, de [github/awesome-copilot](https://github.com/github/awesome-copilot).

O servidor MCP de modelagem do Power BI não faz parte deste repositório e é coberto pelo EULA da própria Microsoft.

Este é um projeto independente da comunidade e não é afiliado nem endossado pela Microsoft.
