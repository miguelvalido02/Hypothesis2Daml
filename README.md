# Tipos de ficheiros
A ferramenta usa o seguinte tipo de ficheiros:
- **DAR** (Daml Archive): pacote compilado contendo os módulos e templates DAML do projeto.
- **VENV** (Virtual Environment): ambiente virtual de Python que isola dependências e executáveis do projeto.

# Como correr a tool
Em todos os comandos é necessário estar na pasta do projeto daml (onde está o ficheiro daml.yaml)
Se ainda não tiver venv criado é preciso correr
```python3 -m venv .venv```
```source .venv/bin/activate```
```pip install -U pip pytest hypothesis requests```

Se ainda não tiver ficheiro DAR, é preciso correr
```daml build```
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

### Exemplos concretos
Há **8** exemplos concretos neste repositório, localizados em:  
`miguel-valido-repo/benchmark/daml_contracts/`

- **AssetTransfer** (`AssetTransfer/`)  
  Workflow de compra/venda com estados (p.ex., `ItemAvailable`, `OfferPlaced`,
  inspeção/avaliação, `Accepted`/`Rejected`) e papéis (owner, buyer, inspector,
  appraiser).  
  *Propriedades*: transições válidas, guards de aceitação/rejeição, permissões
  por papel.

- **BorrowAndLending** (`BorrowAndLending/`)  
  *Pool* de empréstimos: depositar (lend), levantar (withdraw), pedir (borrow) e
  reembolsar (repay).  
  *Propriedades*: `Lend` acumula saldos; `Withdraw` respeita saldo disponível;
  ciclo `Borrow/Repay` restaura o estado.

- **DefectiveComponentCounter** (`DefectiveComponentCounter/`)  
  Contagem de componentes defeituosos com permissões por fabricante.  
  *Propriedades*: `ComputeTotal` preserva a soma; apenas o fabricante está
  autorizado.

- **DigitalLocker** (`DigitalLocker/`)  
  Cofre digital para partilha de documentos com pedidos e revogações.  
  *Propriedades*: `UploadDocuments` define campos; ciclo
  `Request→Accept→Release`; ida e volta `Share→Revoke`.

- **FrequentFlier** (`FrequentFlier/`)  
  Programa de milhas com acumulação e regras de recompensa.  
  *Propriedades*: `AddMiles` atualiza milhas/recompensas; apenas o viajante
  autorizado.

- **SimpleMarket** (`SimpleMarket/`)  
  Marketplace simples com oferta/aceitação/rejeição e mudanças de estado.  
  *Propriedades*: `MakeOffer` apenas a partir de `ItemAvailable`; muda para
  `OfferPlaced`; só o *owner* aceita/rejeita; guards respeitados.

- **WhitelistedRegistry** (`WhitelistedRegistry/`)  
  Registo com *owner* e lista branca de partes autorizadas.  
  *Propriedades*: só o *owner* pode alterar owner/whitelist; `SetWhitelisted`
  alterna a filiação; `IsWhitelisted` reflete o estado real.

- **ZeroTokenBank** (`ZeroTokenBank/`)  
  “Banco” mínimo sem token nativo: abrir conta, depositar, levantar e consultar
  saldo.  
  *Propriedades*: depósito aumenta saldo; levantamento é proibido com saldo zero.

---

### Templates
Existem **3** templates, disponíveis em:  
`miguel-valido-repo/benchmark/daml_contracts/templates`

- **BorrowLendingTemplate**  
  Base para *pools* de empréstimo: `Lend`, `Withdraw`, `Borrow`, `Repay`,
  saldos por parte e validações de limites. Útil para testar invariantes de
  contabilização, regras de *collateral* e rondas de *borrow/repay*.

- **WhitelistedRegistryTemplate**  
  Padrão de controlo de acesso com *owner* e *whitelist*: `SetWhitelisted`
  (liga/desliga), `IsWhitelisted` (consulta) e troca de *owner*. Serve de base
  para cenários onde autorizações e papéis variam ao longo do tempo.

- **ZeroTokenBankTemplate**  
  “Banco” custodial minimalista: abrir conta, depositar, levantar, consultar.
  Ideal para invariantes simples (saldo nunca negativo, soma de saldos
  consistente) e testes de permissões básicos.

> Dica: cada template inclui um conjunto pequeno de propriedades de arranque
> no diretório `tests/` correspondente, que podes usar como padrão e expandir.

