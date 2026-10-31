-- Exporta o dataset JSON (tutores com array de pets) a partir do banco relacional.
-- Execute com SQLcl ou SQL*Plus, a partir da RAIZ do repositorio, conectado ao
-- mesmo schema Oracle onde o script 2TDSPG_2026_CodigoSql_Integrantes.sql foi executado:
--
--     sql usuario/senha@host:1521/servico @exportacao/exportar_json.sql
--
-- O arquivo gerado (dados/tutores.json) e o que o mongoimport importa.

SET SERVEROUTPUT OFF
SET LONG 10000000
SET LONGCHUNKSIZE 10000000
SET LINESIZE 32767
SET PAGESIZE 0
SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET TAB OFF
SET TRIMSPOOL ON
SET TERMOUT OFF

SPOOL dados/tutores.json
SELECT pkg_exportacao_json.fnc_gerar_json_tutores FROM dual;
SPOOL OFF

SET TERMOUT ON
PROMPT Arquivo dados/tutores.json gerado.
EXIT
