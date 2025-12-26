# Documentação Técnica do Bitcoin-PoCX

**Versão**: 1.0
**Base do Bitcoin Core**: v30.0
**Status**: Fase de Testnet
**Última Atualização**: 25/12/2025

---

## Sobre Esta Documentação

Esta é a documentação técnica completa do Bitcoin-PoCX, uma integração ao Bitcoin Core que adiciona suporte ao consenso Proof of Capacity neXt generation (PoCX). A documentação está organizada como um guia navegável com capítulos interconectados que cobrem todos os aspectos do sistema.

**Públicos-Alvo**:
- **Operadores de Nós**: Capítulos 1, 5, 6, 8
- **Mineradores**: Capítulos 2, 3, 7
- **Desenvolvedores**: Todos os capítulos
- **Pesquisadores**: Capítulos 3, 4, 5

## Traduções

| | | | | | |
|---|---|---|---|---|---|
| [🇩🇪 Alemão](../deu/index.md) | [🇸🇦 Árabe](../ara/index.md) | [🇧🇬 Búlgaro](../bul/index.md) | [🇨🇿 Checo](../ces/index.md) | [🇨🇳 Chinês](../zho/index.md) | [🇰🇷 Coreano](../kor/index.md) |
| [🇩🇰 Dinamarquês](../dan/index.md) | [🇪🇸 Espanhol](../spa/index.md) | [🇪🇪 Estoniano](../est/index.md) | [🇵🇭 Filipino](../fil/index.md) | [🇫🇮 Finlandês](../fin/index.md) | [🇫🇷 Francês](../fra/index.md) |
| [🇬🇷 Grego](../ell/index.md) | [🇮🇱 Hebraico](../heb/index.md) | [🇮🇳 Hindi](../hin/index.md) | [🇳🇱 Holandês](../nld/index.md) | [🇭🇺 Húngaro](../hun/index.md) | [🇮🇩 Indonésio](../ind/index.md) |
| [🇬🇧 Inglês](../../index.md) | [🇮🇹 Italiano](../ita/index.md) | [🇯🇵 Japonês](../jpn/index.md) | [🇱🇻 Letão](../lav/index.md) | [🇱🇹 Lituano](../lit/index.md) | [🇳🇴 Norueguês](../nor/index.md) |
| [🇵🇱 Polaco](../pol/index.md) | [🇷🇴 Romeno](../ron/index.md) | [🇷🇺 Russo](../rus/index.md) | [🇷🇸 Sérvio](../srp/index.md) | [🇰🇪 Suaíli](../swa/index.md) | [🇸🇪 Sueco](../swe/index.md) |
| [🇹🇷 Turco](../tur/index.md) | [🇺🇦 Ucraniano](../ukr/index.md) | [🇻🇳 Vietnamita](../vie/index.md) | | | |

---

## Índice

### Parte I: Fundamentos

**[Capítulo 1: Introdução e Visão Geral](1-introduction.md)**
Visão geral do projeto, arquitetura, filosofia de design, recursos principais e como o PoCX difere do Proof of Work.

**[Capítulo 2: Formato de Arquivo de Plot](2-plot-format.md)**
Especificação completa do formato de plot PoCX, incluindo otimização SIMD, escalabilidade de proof-of-work e evolução do formato a partir do POC1/POC2.

**[Capítulo 3: Consenso e Mineração](3-consensus-and-mining.md)**
Especificação técnica completa do mecanismo de consenso PoCX: estrutura de blocos, assinaturas de geração, ajuste de base target, processo de mineração, pipeline de validação e algoritmo de Time Bending.

---

### Parte II: Recursos Avançados

**[Capítulo 4: Sistema de Atribuição de Forja](4-forging-assignments.md)**
Arquitetura exclusivamente baseada em OP_RETURN para delegação de direitos de forja: estrutura de transações, design de banco de dados, máquina de estados, tratamento de reorganizações e interface RPC.

**[Capítulo 5: Sincronização de Tempo e Segurança](5-timing-security.md)**
Tolerância a desvio de relógio, mecanismo de forja defensiva, proteção contra manipulação de relógio e considerações de segurança relacionadas a tempo.

**[Capítulo 6: Parâmetros de Rede](6-network-parameters.md)**
Configuração de chainparams, bloco gênesis, parâmetros de consenso, regras de coinbase, escalonamento dinâmico e modelo econômico.

---

### Parte III: Uso e Integração

**[Capítulo 7: Referência da Interface RPC](7-rpc-reference.md)**
Referência completa de comandos RPC para mineração, atribuições e consultas à blockchain. Essencial para integração de mineradores e pools.

**[Capítulo 8: Guia da Carteira e Interface Gráfica](8-wallet-guide.md)**
Guia do usuário para a carteira Qt do Bitcoin-PoCX: diálogo de atribuição de forja, histórico de transações, configuração de mineração e resolução de problemas.

---

## Navegação Rápida

### Para Operadores de Nós
→ Comece pelo [Capítulo 1: Introdução](1-introduction.md)
→ Em seguida, revise o [Capítulo 6: Parâmetros de Rede](6-network-parameters.md)
→ Configure a mineração com o [Capítulo 8: Guia da Carteira](8-wallet-guide.md)

### Para Mineradores
→ Entenda o [Capítulo 2: Formato de Plot](2-plot-format.md)
→ Aprenda o processo no [Capítulo 3: Consenso e Mineração](3-consensus-and-mining.md)
→ Integre usando o [Capítulo 7: Referência RPC](7-rpc-reference.md)

### Para Operadores de Pools
→ Revise o [Capítulo 4: Atribuições de Forja](4-forging-assignments.md)
→ Estude o [Capítulo 7: Referência RPC](7-rpc-reference.md)
→ Implemente usando as RPCs de atribuição e submit_nonce

### Para Desenvolvedores
→ Leia todos os capítulos sequencialmente
→ Faça referência cruzada aos arquivos de implementação mencionados ao longo do texto
→ Examine a estrutura do diretório `src/pocx/`
→ Compile releases com [GUIX](../bitcoin/contrib/guix/README.md)

---

## Convenções da Documentação

**Referências a Arquivos**: Detalhes de implementação referenciam arquivos fonte como `caminho/para/arquivo.cpp:linha`

**Integração de Código**: Todas as alterações são sinalizadas por feature flags com `#ifdef ENABLE_POCX`

**Referências Cruzadas**: Os capítulos se conectam a seções relacionadas usando links relativos em markdown

**Nível Técnico**: A documentação pressupõe familiaridade com Bitcoin Core e desenvolvimento em C++

---

## Compilação

### Build de Desenvolvimento

```bash
# Clone com submódulos
git clone --recursive https://github.com/PoC-Consortium/bitcoin-pocx.git
cd bitcoin-pocx/bitcoin

# Configure com PoCX habilitado
cmake -B build -DENABLE_POCX=ON

# Compile
cmake --build build -j$(nproc)
```

**Variantes de Build**:
```bash
# Com interface gráfica Qt
cmake -B build -DENABLE_POCX=ON -DBUILD_GUI=ON

# Build de depuração
cmake -B build -DENABLE_POCX=ON -DCMAKE_BUILD_TYPE=Debug
```

**Dependências**: Dependências padrão de build do Bitcoin Core. Consulte a [documentação de build do Bitcoin Core](https://github.com/bitcoin/bitcoin/tree/master/doc#building) para requisitos específicos de cada plataforma.

### Builds de Release

Para binários de release reproduzíveis, use o sistema de build GUIX: Veja [bitcoin/contrib/guix/README.md](../bitcoin/contrib/guix/README.md)

---

## Recursos Adicionais

**Repositório**: [https://github.com/PoC-Consortium/bitcoin-pocx](https://github.com/PoC-Consortium/bitcoin-pocx)

**Framework Core do PoCX**: [https://github.com/PoC-Consortium/pocx](https://github.com/PoC-Consortium/pocx)

**Projetos Relacionados**:
- Plotter: Baseado no [engraver](https://github.com/PoC-Consortium/engraver)
- Minerador: Baseado no [scavenger](https://github.com/PoC-Consortium/scavenger)

---

## Como Ler Esta Documentação

**Leitura Sequencial**: Os capítulos são projetados para serem lidos em ordem, construindo sobre conceitos anteriores.

**Leitura de Referência**: Use o índice para ir diretamente a tópicos específicos. Cada capítulo é autocontido, com referências cruzadas a material relacionado.

**Navegação no Navegador**: Abra `index.md` em um visualizador de markdown ou navegador. Todos os links internos são relativos e funcionam offline.

**Exportação para PDF**: Esta documentação pode ser concatenada em um único PDF para leitura offline.

---

## Status do Projeto

**✅ Funcionalidades Completas**: Todas as regras de consenso, mineração, atribuições e recursos de carteira implementados.

**✅ Documentação Completa**: Todos os 8 capítulos completos e verificados contra o código-fonte.

**🔬 Testnet Ativa**: Atualmente em fase de testnet para testes pela comunidade.

---

## Contribuindo

Contribuições para a documentação são bem-vindas. Por favor, mantenha:
- Precisão técnica acima de verbosidade
- Explicações breves e diretas ao ponto
- Sem código ou pseudocódigo na documentação (referencie arquivos fonte em vez disso)
- Apenas o que está implementado (sem recursos especulativos)

---

## Licença

Bitcoin-PoCX herda a licença MIT do Bitcoin Core. Veja `COPYING` na raiz do repositório.

Atribuição do framework core do PoCX documentada no [Capítulo 2: Formato de Plot](2-plot-format.md).

---

**Iniciar Leitura**: [Capítulo 1: Introdução e Visão Geral →](1-introduction.md)
