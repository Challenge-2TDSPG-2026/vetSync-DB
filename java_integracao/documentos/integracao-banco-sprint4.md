# Integração com o banco (Mastering Relational and Non-Relational Database — Sprint 4)

A API chama pacotes PL/SQL do mesmo Oracle da aplicação. Eles são criados pelo Flyway na migration
`V57__pacotes_plsql_banco_sprint4.sql`.

| Pacote | Rotinas | Endpoint |
|---|---|---|
| `PKG_JSON_PET` | `PRC_LISTAR_PETS_TUTORES_JSON` (JOIN + JSON manual) | `GET /banco/pets/json?tutorId=` (ADMIN) |
| `PKG_PET` | `FNC_CALCULAR_IDADE` | `GET /banco/pets/idade?dataNascimento=` |
| `PKG_RELATORIO_CUSTOS` | `PRC_RESUMO_CUSTOS_CLINICA_TIPO` (subtotais manuais) | `GET /banco/relatorios/custos?clinicaId=` (ADMIN) |
| `PKG_EXPORTACAO_JSON` | `PRC_EXPORTAR_TUTORES_JSON` (tutores + array de pets, para o MongoDB) | `GET /banco/exportacao/tutores` (ADMIN) |
| `PKG_AUDITORIA_EVENTO` / `PKG_LOG_ERRO` | usados pelo gatilho `TRG_AUDITORIA_EVENTO_SAUDE` e pelo log de erros | — |

- O gatilho audita `INSERT/UPDATE/DELETE` de `TB_EVENTO_SAUDE` em `TB_AUDITORIA_EVENTO`
  (a `TB_AUDITORIA` da aplicação continua separada).
- Erros `ORA-20xxx` dos pacotes viram HTTP 404 (sem dados) ou 422 (dado inválido) pelo `GlobalExceptionHandler`.
- O relatório de custos regrava `TB_RELATORIO_CUSTOS_CLINICA` a cada chamada; não é pensado para uso concorrente.
- Rotas exigem JWT; as de dados gerais exigem perfil `ADMIN`.
- Dependência do schema Oracle: privilégios `CREATE PROCEDURE` e `CREATE TRIGGER`.
