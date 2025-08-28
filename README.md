# Como correr a tool
[Em todos os comandos é necessário estar na diretoria do projeto daml (onde está o daml.yaml)]
Se ainda não tiver venv criado é preciso correr
```python3 -m venv .venv```
```source .venv/bin/activate```
```pip install -U pip pytest hypothesis requests```

Se ainda não tiver dar, é preciso correr
```daml build```
### Terminal A
 ```daml sandbox --port 6865```

### Terminal B
```daml json-api --ledger-host localhost --ledger-port 6865 --http-port 7575```

### Terminal C
É também necessário dar upload do DAR:
```daml ledger upload-dar --host localhost --port 6865 .daml/dist/ZeroTokenBank-1.0.0.dar```

Depois de garantir que há venv
 ```source .venv/bin/activate```
```pytest -q -s tests/test_zerotokenbank.py::test_deposit_increases_balance```


---------------------------------------------------------------------------------------------------------
# Ficheiro de teste
Importar a lib:
```from daml_pbt import make_request, make_auth, make_admin_auth, ensure_ok, allocate_party, allocate_unique_party
```
É necessário ir buscar o package_id. Para tal, correr  ```daml damlc inspect-dar .daml/dist/ZeroTokenBank-1.0.0.dar```
e vai aparecer algures dentro do output:

```DAR archive contains the following packages:

ZeroTokenBank-1.0.0-c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514 "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"```

A constante "PKG" é o que está dentro das aspas.
```PKG = "c6f004b1cd672ae532964d33767186c66d1b0673ce87a0e05b35e7b78c2fc514"```