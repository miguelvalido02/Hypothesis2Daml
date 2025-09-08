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

## Exemplos concretos
Há **8** exemplos concretos neste repositório, localizados em:  
`miguel-valido-repo/benchmark/daml_contracts/`

## Templates
Existem **3** templates, disponíveis em:  
`miguel-valido-repo/benchmark/daml_contracts/templates`
