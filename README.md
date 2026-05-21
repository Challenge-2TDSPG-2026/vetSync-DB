# 🐾 ClyvoVet — Mastering Relational and Non-Relational Database

Sistema de gerenciamento veterinário desenvolvido como projeto acadêmico para a disciplina **Mastering Relational and Non-Relational Database**.

---

## 📋 Descrição

O **ClyvoVet** é um banco de dados relacional voltado para clínicas veterinárias, permitindo o gerenciamento de tutores, pets, veterinários, clínicas, eventos de saúde, medicamentos e prescrições. O projeto foi desenvolvido em **Oracle SQL** com uso de procedures, cursores, relatórios analíticos e controle de erros via log.

---

## 🗂️ Estrutura do Projeto

```
MASTERING RELATIONAL AND NON-RELATIONAL DATABASE/
├── ClyvoVet.sql                                         # Script principal (DDL + DML + relatórios)
├── ModeloLogicoClyvoVet.dmd                             # Modelo lógico (Oracle Data Modeler)
├── ModeloRelacionalClyvoVet.dmd                         # Modelo relacional (Oracle Data Modeler)
├── ClyvoVet_Documentacao.pdf                            # Documentação do projeto
└── OS_BACKS-CLYVOVET.pdf                                # Backlog / OS do projeto
```

---

## 🗃️ Principais Entidades

| Tabela              | Descrição                              |
|---------------------|----------------------------------------|
| `TB_TUTOR`          | Donos dos pets (CPF, e-mail, telefone) |
| `TB_ESPECIE`        | Espécies animais                       |
| `TB_RACA`           | Raças vinculadas a espécies            |
| `TB_PET`            | Animais cadastrados                    |
| `TB_CLINICA`        | Clínicas veterinárias                  |
| `TB_VETERINARIO`    | Veterinários vinculados às clínicas    |
| `TB_TIPO_EVENTO`    | Categorias de eventos de saúde         |
| `TB_EVENTO_SAUDE`   | Consultas, exames e procedimentos      |
| `TB_MEDICAMENTO`    | Medicamentos disponíveis               |
| `TB_PRESCRICAO`     | Prescrições vinculadas a eventos       |
| `TB_LOG_ERROS`      | Log automático de erros de procedures  |

---

## ⚙️ Tecnologias Utilizadas

- **Oracle SQL / PL-SQL**
- **Oracle Data Modeler**
- Procedures armazenadas com tratamento de exceções
- Cursores e relatórios analíticos via `DBMS_OUTPUT`

---

## ▶️ Como Executar

1. Abra o **Oracle SQL Developer** (ou ferramenta equivalente) conectado a um banco Oracle.
2. Execute o script `ClyvoVet.sql` na ordem em que está estruturado:
   - Limpeza de objetos anteriores
   - Criação das tabelas
   - Criação das procedures
   - Inserção de dados
   - Execução dos relatórios
3. Ative a saída do servidor antes de rodar os relatórios:
   ```sql
   SET SERVEROUTPUT ON;
   ```

---

## 👥 Integrantes

| Nome | RM |
|------|----|
| Arthur Brito da Silva | RM562085 |
| Luiz Felipe Flosi dos Santos | RM563197 |
| Pedro Henrique Brum Lopes | RM561780 |

---

> Projeto desenvolvido para fins acadêmicos — FIAP