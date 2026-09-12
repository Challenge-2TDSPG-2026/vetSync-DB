# 🐾 ClyvoVet — Mastering Relational and Non-Relational Database

Sistema de gerenciamento veterinário desenvolvido como projeto acadêmico para a disciplina **Mastering Relational and Non-Relational Database**, FIAP Challenge 2026.

---

## 📋 Descrição

O **ClyvoVet** é um banco de dados relacional voltado para clínicas veterinárias, permitindo o gerenciamento de tutores, pets, veterinários, clínicas e eventos de saúde. O projeto foi desenvolvido em **Oracle SQL** com uso de procedures, funções, cursores, triggers de auditoria e controle de erros via log.

---

## 🗂️ Estrutura do Projeto

```
vetSync-DB/
├── 2TDSPG_2026_CodigoSql_Integrantes.sql  # Script principal (CREATE TABLE + INSERT + objetos PL/SQL)
├── ModeloLogico.dmd                       # Modelo lógico (Oracle Data Modeler)
├── ModeloRelacional.dmd                   # Modelo relacional (Oracle Data Modeler)
├── ModeloRelacional.zip                   # Pasta de suporte do projeto Data Modeler (serve os dois dmd)
├── 2TDSPG_2026_Proj_BD.pdf                # Documentação da Sprint 3 (capa, prints de execução e exceções)
└── README.md
```

---

## 🗃️ Entidades

| Tabela | Descrição |
|---|---|
| `TB_TUTOR` | Donos dos pets (CPF, e-mail, telefone) |
| `TB_ESPECIE` | Espécies animais |
| `TB_RACA` | Raças vinculadas a espécies |
| `TB_PET` | Animais cadastrados |
| `TB_CLINICA` | Clínicas veterinárias |
| `TB_VETERINARIO` | Veterinários vinculados às clínicas |
| `TB_TIPO_EVENTO` | Categorias de eventos de saúde |
| `TB_EVENTO_SAUDE` | Consultas, exames e procedimentos |
| `TB_LOG_ERROS` | Log automático de erros de procedures/functions |
| `TB_AUDITORIA` | Auditoria de INSERT/UPDATE/DELETE em `TB_EVENTO_SAUDE` |
| `TB_RELATORIO_CUSTOS_CLINICA` | Tabela de apoio com o resultado do relatório de subtotais manuais |

---

## ⚙️ Objetos PL/SQL — Sprint 3

| Objeto | Tipo | Descrição |
|---|---|---|
| `FNC_MONTAR_JSON_PET` | Função | Converte dados de pet (já unidos via JOIN) em string JSON, montada manualmente, sem funções nativas do Oracle |
| `PRC_LISTAR_PETS_TUTORES_JSON` | Procedimento | JOIN entre `TB_PET`, `TB_TUTOR`, `TB_RACA` e `TB_ESPECIE`, retornando um array JSON com todos os pets (ou filtrado por tutor) |
| `FNC_CALCULAR_IDADE` | Função | Calcula idade em anos completos a partir da data de nascimento, substituindo a regra hoje presente no Java (`PetService.calcularIdade`) |
| `PRC_RESUMO_CUSTOS_CLINICA_TIPO` | Procedimento | Subtotais manuais (Clínica × Tipo de Evento) sobre `TB_EVENTO_SAUDE`, sem `ROLLUP`/`CUBE`/`GROUPING SETS` |
| `TRG_AUDITORIA_EVENTO_SAUDE` | Trigger | Registra em `TB_AUDITORIA` toda operação de INSERT/UPDATE/DELETE em `TB_EVENTO_SAUDE`, com usuário, operação, data/hora e valores antigos/novos |
| `PRC_LOG_ERRO` | Procedimento utilitário | Centraliza o log de erros em `TB_LOG_ERROS` usando transação autônoma, isolando o log da transação de quem chamou |

Todas as functions e procedures tratam no mínimo 3 exceções distintas, com log automático em `TB_LOG_ERROS`.

---

## ▶️ Como Executar

1. Abra o **Oracle SQL Developer** conectado a um banco Oracle.
2. Execute o script `2TDSPG_2026_CodigoSql_Integrantes.sql` inteiro (é autocontido: limpa objetos anteriores, cria as tabelas do zero, popula com dados de exemplo, e cria todos os objetos PL/SQL).
3. Ative a saída do servidor antes de testar as procedures:
   ```sql
   SET SERVEROUTPUT ON;
   ```
4. Exemplos de uso:
   ```sql
   -- Procedimento 1: JSON de todos os pets
   DECLARE
       v_json CLOB;
   BEGIN
       prc_listar_pets_tutores_json(v_json);
   END;
   /

   -- Procedimento 2: resumo de custos por clínica e tipo de evento
   EXEC prc_resumo_custos_clinica_tipo;
   SELECT * FROM TB_RELATORIO_CUSTOS_CLINICA ORDER BY id_linha;
   ```

---

## 📐 Modelo de Dados

Os arquivos `ModeloLogico.dmd` e `ModeloRelacional.dmd` (Oracle SQL Developer Data Modeler) devem ser abertos junto com a pasta de suporte do projeto (`ModeloRelacional.zip`, descompactada no mesmo diretório dos `.dmd`) — os três arquivos compõem um único projeto de modelagem.

---

## 👥 Integrantes

| Nome | RM |
|---|---|
| Arthur Brito da Silva | RM562085 |
| Luiz Felipe Flosi dos Santos | RM563197 |
| Pedro Henrique Brum Lopes | RM561780 |

---

> Projeto desenvolvido para fins acadêmicos — FIAP Challenge 2026