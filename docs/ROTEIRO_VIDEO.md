# Roteiro do vídeo — Sprint 4 (Mastering Relational and Non-Relational Database)

Gravar com narração (sem narração: -5 pontos). Sem cortes nos trechos de execução.

1. **Abertura (30s)** — mostrar o repositório e dizer o objetivo: pacotes PL/SQL + Java + MongoDB.
2. **Pacotes no Oracle (1 min)** — abrir o `.sql` e mostrar os 6 pacotes e o gatilho no SQL Developer (árvore *Packages*). Explicar "um pacote por responsabilidade".
3. **Execução das procedures pelo backend Java (2 min)** — com a API rodando, chamar no navegador/Postman:
   - `GET /banco/pets/json` (Procedimento 1 + Função 1)
   - `GET /banco/pets/idade?dataNascimento=2022-09-02` (Função 2)
   - `GET /banco/relatorios/custos` (Procedimento 2 — subtotais e total)
   - `GET /banco/pets/json?tutorId=<tutor sem pets>` → **404** (exceção tratada) e mostrar a linha em `TB_LOG_ERROS`
4. **Inserção no banco relacional (1 min)** — inserir um registro pela aplicação (ex.: novo evento de saúde) e dar `SELECT` em `TB_EVENTO_SAUDE` e `TB_AUDITORIA_EVENTO` (gatilho + `PKG_AUDITORIA_EVENTO`).
5. **Exportação para JSON (1 min)** — rodar `exportacao/exportar_json.sql` (ou `GET /banco/exportacao/tutores`) e abrir `dados/tutores.json` mostrando tutor com array de pets (Beatriz com `pets: []`).
6. **Importação no MongoDB (1,5 min)** — `01_criar_colecao.js`, `02_importar.ps1`, depois `03_consultas.js`; mostrar contagem, `$unwind` por espécie e o validador rejeitando e-mail inválido. Explicar o modelo (tutor + array de pets).
7. **Encerramento (20s)** — recapitular os 5 entregáveis.
