# Introdução

Esta ferramenta fornece uma biblioteca Python para **testes baseados em propriedades (property-based testing)** de contratos **Daml**, executando-os via **Daml JSON API**. 
O módulo `daml_pbt` integra-se com **Hypothesis** (geração e *shrinking* de dados) e **pytest** (execução e relatórios), 
permitindo validar **invariantes**, **pré/pós-condições** e **workflows stateful** com exemplos gerados automaticamente e **contra-exemplos reprodutíveis**.

**Principais funcionalidades**
- *Helpers* para criar contratos, exercer *choices* e fazer *queries*.
- Geração automática de inputs com Hypothesis e *shrinking* de contraexemplos.
- Isolamento de partes por teste (evita interferências entre casos).
- Integração com pytest para correr localmente e em CI.

**O que encontrarás neste repositório**
- O módulo `daml_pbt` com os *helpers*.
- **Exemplos concretos** de contratos Daml com propriedades de referência.
- **Templates reutilizáveis** para arrancar rapidamente novos testes.

**Pré-requisitos**
- **Daml SDK** a correr localmente (**Sandbox** e **JSON API**).
- **Python 3.x** com `pytest`, `hypothesis` e `requests`.
- Um **DAR** do teu projeto Daml (ver secção abaixo).

## Tipos de ficheiros
A ferramenta usa o seguinte tipo de ficheiros:
- **DAR** (Daml Archive): pacote compilado contendo os módulos e templates DAML do projeto.
- **VENV** (Virtual Environment): ambiente virtual de Python que isola dependências e executáveis do projeto.

# Como correr a tool
Em todos os comandos é necessário estar na pasta do projeto daml (onde está o ficheiro daml.yaml).
Se ainda não tiver venv criado é preciso correr
```python3 -m venv .venv```
```source .venv/bin/activate```
```pip install -U pip pytest hypothesis requests```

Se ainda não tiver ficheiro DAR, é preciso correr
```daml build```.
São precisos 3 terminais para os testes.

### Terminal A
Correr o comando
 ```daml sandbox --port 6865```

### Terminal B
Correr o comando
```daml json-api --ledger-host localhost --ledger-port 6865 --http-port 7575```

### Terminal C
É necessário carregar o DAR:
```daml ledger upload-dar --host localhost --port 6865 .daml/dist/TestBankTemplate-1.0.0.dar```

Depois de garantir que há VENV (passo inicial), correr:
 ```source .venv/bin/activate```
 Para correr o teste:
```pytest -q -s tests/test_bank_template.py::test_deposit_increases_balance```
Também é possível correr todos os testes do ficheiro:
```pytest -q -s tests/test_bank_template.py```

---------------------------------------------------------------------------------------------------------
# Ficheiro de teste
Há alguns exemplos de ficheiros de teste neste repositório mas aqui ficam duas dicas:
Como importar a lib:
```from daml_pbt import make_request, make_auth, make_admin_auth, ensure_ok, allocate_party, allocate_unique_party```

É necessário ir buscar o package_id. Para tal, correr 
 ```daml damlc inspect-dar .daml/dist/TestBankTemplate-1.0.0.dar```
e vai aparecer algures dentro do output:

```DAR archive contains the following packages: TestBankTemplate-1.0.0-c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514 "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"```

A constante "PKG" é o que está dentro das aspas.
```PKG = "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"```

---------------------------------------------------------------------------------------------------------
# Exemplos e templates

## Exemplos concretos
Há **8** exemplos concretos neste repositório, localizados em:  
`miguel-valido-repo/benchmark/daml_contracts/`

- **AssetTransfer**
  Workflow de compra/venda com estados (p.ex., `Active`, `OfferPlaced`,`PendingInspection`,`Inspected`, `Accepted`/`Rejected`) e papéis/roles (owner, buyer, inspector e appraiser).  
  *Propriedades*: transições válidas, guards de aceitação/rejeição, permissões
  por papel/role.

- **BorrowAndLending**
  *Pool* de empréstimos: depositar (lend), levantar (withdraw), pedir (borrow) e
  reembolsar (repay).  
  *Propriedades*: `Lend` acumula saldos; `Withdraw` respeita saldo disponível;
  ciclo `Borrow/Repay` restaura o estado corretamente.

- **DefectiveComponentCounter** 
  Contagem de componentes defeituosos com permissões por fabricante.  
  *Propriedades*: `ComputeTotal` preserva a soma; apenas o fabricante está autorizado.

- **DigitalLocker** 
  Cofre digital para partilha de documentos com pedidos e revogações.  
  *Propriedades*: `UploadDocuments` define campos; ciclo `Request→Accept→Release`; ida e volta `Share→Revoke` restaura estado corretamente.

- **FrequentFlier**
  Programa de milhas com acumulação e regras de recompensa.  
  *Propriedades*: `AddMiles` atualiza milhas/recompensas; apenas o viajante autorizado.

- **SimpleMarket**
  Marketplace simples com oferta/aceitação/rejeição e mudanças de estado.  
  *Propriedades*: `MakeOffer` apenas a partir de `ItemAvailable`; `MakeOffer` muda para `OfferPlaced`; só o *owner* aceita/rejeita ofertas; guards respeitados.

- **WhitelistedRegistry**
  Registo com *owner* e lista branca de partes autorizadas.  
  *Propriedades*: só o *owner* pode alterar owner/whitelist; `SetWhitelisted` alterna a filiação; `IsWhitelisted` reflete o estado real.

- **ZeroTokenBank** 
  “Banco” mínimo sem token nativo: abrir conta, depositar, levantar e consultar saldo.  
  *Propriedades*: depósito aumenta saldo corretamente; levantamento é proibido com saldo zero.

---

### Templates
Existem **3** templates, disponíveis em:  
`miguel-valido-repo/benchmark/daml_contracts/templates`

- **BorrowLendingTemplate**  
  Base para *pools* de empréstimo: `Lend`, `Withdraw`, `Borrow`, `Repay`, saldos por parte e validações de limites. Útil para testar invariantes de contabilização, regras de colateral e *round-trips* de *borrow/repay*.

- **WhitelistedRegistryTemplate**  
  Padrão de controlo de acesso com *owner* e *whitelist*: `SetWhitelisted` (liga/desliga), `IsWhitelisted` (consulta) e troca de *owner*. Serve de base para cenários onde autorizações e papéis variam ao longo do tempo.

- **ZeroTokenBankTemplate**  
  “Banco” custodial minimalista: abrir conta, depositar, levantar, consultar. Ideal para invariantes simples (saldo nunca negativo, soma de saldos consistente) e testes de permissões básicos.

> Dica: cada template e exemplo concreto inclui um conjunto pequeno de propriedades de arranque
> no diretório `tests/` correspondente, que podem ser usados como padrão.

