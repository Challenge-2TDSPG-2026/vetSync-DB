# 🐾 ClyvoVet — Mastering Relational and Non-Relational Database

Banco de dados do **ClyvoVet / VetSync** (FIAP Challenge 2026): Oracle com PL/SQL **empacotado**, integração com a API Java (Spring Boot) e exportação dos dados para **MongoDB**.

---

## 📋 Descrição

Sistema de gerenciamento veterinário: tutores, pets, clínicas, veterinários e eventos de saúde. Na Sprint 4 as rotinas da Sprint 3 foram organizadas em **pacotes PL/SQL separados por responsabilidade**, passaram a ser **chamadas pela aplicação Java**, e o banco relacional passou a gerar um **dataset JSON** importado em um banco de **documentos (MongoDB)**.

```
Oracle (relacional) ──► pacotes PL/SQL ──► API Java (Spring) ──► JSON
        │                                                          
        └─ PKG_EXPORTACAO_JSON ──► dados/tutores.json ──► MongoDB (tutores + array de pets)
```

---

## 🗂️ Estrutura do projeto

```
vetSync-DB/
├── 2TDSPG_2026_CodigoSql_Integrantes.sql   # Script principal (tabelas + inserts + PACOTES + gatilho + testes)
├── dados/
│   └── tutores.json                      # Dataset exportado do Oracle (entrada do MongoDB)
├── exportacao/
│   └── exportar_json.sql                 # Gera dados/tutores.json a partir do Oracle (SQLcl/SQL*Plus)
├── mongo/
│   ├── 01_criar_colecao.js               # Coleção, validador de schema e índices
│   ├── 02_importar.ps1                   # mongoimport do tutores.json
│   └── 03_consultas.js                   # Consultas de demonstração
├── java/                                 # Classes a copiar para a API Java (chamam os pacotes)
├── docs/ROTEIRO_VIDEO.md                 # Roteiro da demonstração em vídeo
├── 2TDSPG_2026_Proj_BD.pdf               # Documentação (evidências)
├── ModeloLogico.dmd / ModeloRelacional.dmd / ModeloRelacional.zip   # Data Modeler
└── README.md
```

---

## 🗃️ Entidades (Oracle)

| Tabela | Descrição |
|---|---|
| `TB_TUTOR` | Donos dos pets |
| `TB_ESPECIE` / `TB_RACA` | Espécies e raças |
| `TB_PET` | Animais cadastrados |
| `TB_CLINICA` / `TB_VETERINARIO` | Clínicas e veterinários |
| `TB_TIPO_EVENTO` / `TB_EVENTO_SAUDE` | Tipos de evento e eventos de saúde |
| `TB_LOG_ERROS` | Log de erros das rotinas |
| `TB_AUDITORIA` | Auditoria de INSERT/UPDATE/DELETE em `TB_EVENTO_SAUDE` |
| `TB_RELATORIO_CUSTOS_CLINICA` | Resultado do relatório de subtotais |

---

## 📦 Pacotes PL/SQL

| Pacote | Conteúdo |
|---|---|
| `PKG_LOG_ERRO` | `PRC_REGISTRAR` — log com transação autônoma |
| `PKG_JSON_PET` | `FNC_ESCAPAR`, **Função 1** `FNC_MONTAR_JSON_PET` (JSON manual), **Procedimento 1** `PRC_LISTAR_PETS_TUTORES_JSON` (JOIN + JSON) |
| `PKG_PET` | **Função 2** `FNC_CALCULAR_IDADE` |
| `PKG_RELATORIO_CUSTOS` | **Procedimento 2** `PRC_RESUMO_CUSTOS_CLINICA_TIPO` (subtotais manuais, sem ROLLUP/CUBE) |
| `PKG_AUDITORIA_EVENTO` | `FNC_DESCREVER_EVENTO`, `PRC_REGISTRAR` — usados pelo gatilho |
| `PKG_EXPORTACAO_JSON` | `FNC_GERAR_JSON_TUTORES`, `PRC_EXPORTAR_TUTORES_JSON` — tutores com array de pets |

O gatilho `TRG_AUDITORIA_EVENTO_SAUDE` não pode ficar dentro de pacote (limitação do Oracle); ele apenas delega ao `PKG_AUDITORIA_EVENTO`.
Todas as rotinas tratam no mínimo 3 exceções (`ORA-20101…20151`) e gravam em `TB_LOG_ERROS`.

---

## ▶️ Como executar

### 1. Oracle
1. No **SQL Developer**, execute `2TDSPG_2026_CodigoSql_Integrantes.sql` inteiro (autocontido e idempotente).
2. Para testar, use o bloco `10. TESTES` no final do script (cada bloco está comentado).

```sql
SET SERVEROUTPUT ON;
EXEC pkg_relatorio_custos.prc_resumo_custos_clinica_tipo;
SELECT * FROM TB_RELATORIO_CUSTOS_CLINICA ORDER BY id_linha;
```

### 2. Exportar JSON do Oracle
Na raiz do repositório, com **SQLcl** (ou SQL*Plus):
```bash
sql usuario/senha@host:1521/servico @exportacao/exportar_json.sql
```
Gera/atualiza `dados/tutores.json`.

### 3. MongoDB local
Pré-requisitos: MongoDB em `localhost:27017`, `mongosh` e `mongoimport` (MongoDB Database Tools) no PATH.
```powershell
mongosh "mongodb://localhost:27017" mongo/01_criar_colecao.js
.\mongo\02_importar.ps1
mongosh "mongodb://localhost:27017" mongo/03_consultas.js
```

**Modelo de documentos:** um documento por **tutor** com o **array de pets** embutido (o app sempre lê o tutor com seus pets). Eventos de saúde não são embutidos, pois crescem sem limite. CPF e senha **não** são exportados.

```json
{ "_id": 1, "nome": "Maria Silva", "email": "maria@email.com",
  "pets": [ { "id_pet": 1, "nome": "Buddy", "raca": "Golden Retriever", "especie": "Cachorro" } ] }
```

### 4. API Java
Copie a pasta `java/src/main/java/br/com/fiap/vetsync/database` para o projeto Spring Boot (ajuste o `package` se necessário). Requer `spring-boot-starter-jdbc` (ou JPA) e o driver `ojdbc`, apontando para **o mesmo schema Oracle**.

| Endpoint | Pacote chamado |
|---|---|
| `GET /api/db/pets/json?tutorId=1` | `PKG_JSON_PET.PRC_LISTAR_PETS_TUTORES_JSON` |
| `GET /api/db/pets/idade?dataNascimento=2022-09-02` | `PKG_PET.FNC_CALCULAR_IDADE` |
| `GET /api/db/relatorios/custos?clinicaId=1` | `PKG_RELATORIO_CUSTOS.PRC_RESUMO_CUSTOS_CLINICA_TIPO` |
| `GET /api/db/exportacao/tutores` | `PKG_EXPORTACAO_JSON.PRC_EXPORTAR_TUTORES_JSON` |

Erros `ORA-20xxx` viram HTTP 404 (sem dados) ou 422 (dado inválido).

---

## 📐 Modelo de dados

Abra `ModeloLogico.dmd` e `ModeloRelacional.dmd` no SQL Developer Data Modeler junto com a pasta descompactada de `ModeloRelacional.zip`.

---

## 👥 Integrantes

| Nome | RM |
|---|---|
| Arthur Brito da Silva | RM562085 |
| Luiz Felipe Flosi dos Santos | RM563197 |
| Pedro Henrique Brum Lopes | RM561780 |

> Projeto desenvolvido para fins acadêmicos — FIAP Challenge 2026
