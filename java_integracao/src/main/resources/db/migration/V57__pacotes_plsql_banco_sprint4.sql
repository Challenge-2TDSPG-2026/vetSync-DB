-- V57: empacotamento PL/SQL do banco (disciplina Mastering Relational and Non-Relational Database - Sprint 4).
--
-- Cria os pacotes PKG_LOG_ERRO, PKG_JSON_PET, PKG_PET, PKG_RELATORIO_CUSTOS, PKG_AUDITORIA_EVENTO
-- e PKG_EXPORTACAO_JSON, o gatilho de auditoria de TB_EVENTO_SAUDE e as duas tabelas de apoio.
-- O backend chama estes pacotes por RotinasOracleRepository (endpoints /banco/**).
--
-- Observacao: a auditoria do gatilho grava em TB_AUDITORIA_EVENTO. A TB_AUDITORIA ja existe
-- (V32) e e usada pela AuditoriaService com outro formato, por isso nao foi reaproveitada.
-- Requer os privilegios CREATE PROCEDURE e CREATE TRIGGER no schema Oracle.

CREATE TABLE TB_RELATORIO_CUSTOS_CLINICA (
    id_linha       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_clinica     VARCHAR2(150),
    nm_tipo_evento VARCHAR2(80),
    vl_total       NUMBER(12,2),
    ds_tipo_linha  VARCHAR2(20) -- 'DETALHE', 'SUBTOTAL' ou 'TOTAL'
);

CREATE TABLE TB_AUDITORIA_EVENTO (
    id_auditoria       NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_usuario         VARCHAR2(100) DEFAULT USER NOT NULL,
    ds_operacao        VARCHAR2(10)  NOT NULL,
    dt_operacao        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    id_evento_afetado  NUMBER,
    ds_valores_antigos VARCHAR2(1000),
    ds_valores_novos   VARCHAR2(1000),
    CONSTRAINT ck_auditoria_evento_operacao CHECK (ds_operacao IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- 3. PKG_LOG_ERRO
-- Centraliza o log de erros em TB_LOG_ERROS. Usa transacao autonoma para que o
-- log nao seja desfeito por um ROLLBACK de quem chamou.

CREATE OR REPLACE PACKAGE pkg_log_erro AS
    PROCEDURE prc_registrar (
        p_nm_procedure   IN TB_LOG_ERROS.nm_procedure%TYPE,
        p_nr_codigo_erro IN TB_LOG_ERROS.nr_codigo_erro%TYPE,
        p_ds_mensagem    IN TB_LOG_ERROS.ds_mensagem%TYPE
    );
END pkg_log_erro;
/

CREATE OR REPLACE PACKAGE BODY pkg_log_erro AS

    PROCEDURE prc_registrar (
        p_nm_procedure   IN TB_LOG_ERROS.nm_procedure%TYPE,
        p_nr_codigo_erro IN TB_LOG_ERROS.nr_codigo_erro%TYPE,
        p_ds_mensagem    IN TB_LOG_ERROS.ds_mensagem%TYPE
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES (p_nm_procedure, p_nr_codigo_erro, SUBSTR(p_ds_mensagem, 1, 500));
        COMMIT;
    END prc_registrar;

END pkg_log_erro;
/

-- 4. PKG_JSON_PET
-- Funcao 1 (conversao manual relacional -> JSON, sem funcoes nativas do Oracle)
-- e Procedimento 1 (JOIN entre PET, TUTOR, RACA e ESPECIE + JSON).

CREATE OR REPLACE PACKAGE pkg_json_pet AS

    -- Escapa barra invertida e aspas para uso seguro dentro de uma string JSON.
    FUNCTION fnc_escapar (p_texto IN VARCHAR2) RETURN VARCHAR2;

    -- FUNCAO 1: monta o JSON de um pet.
    FUNCTION fnc_montar_json_pet (
        p_id_pet        IN TB_PET.id_pet%TYPE,
        p_nm_pet        IN TB_PET.nm_pet%TYPE,
        p_dt_nascimento IN TB_PET.dt_nascimento%TYPE,
        p_nr_peso_kg    IN TB_PET.nr_peso_kg%TYPE,
        p_nm_raca       IN TB_RACA.nm_raca%TYPE,
        p_nm_especie    IN TB_ESPECIE.nm_especie%TYPE,
        p_nm_tutor      IN TB_TUTOR.nm_tutor%TYPE
    ) RETURN VARCHAR2;

    -- PROCEDIMENTO 1: JOIN + array JSON (todos os pets ou filtrado por tutor).
    PROCEDURE prc_listar_pets_tutores_json (
        p_json_saida OUT CLOB,
        p_id_tutor   IN TB_TUTOR.id_tutor%TYPE DEFAULT NULL
    );

END pkg_json_pet;
/

CREATE OR REPLACE PACKAGE BODY pkg_json_pet AS

    FUNCTION fnc_escapar (p_texto IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_texto IS NULL THEN
            RETURN '';
        END IF;
        RETURN REPLACE(REPLACE(p_texto, '\', '\\'), '"', '\"');
    END fnc_escapar;

    FUNCTION fnc_montar_json_pet (
        p_id_pet        IN TB_PET.id_pet%TYPE,
        p_nm_pet        IN TB_PET.nm_pet%TYPE,
        p_dt_nascimento IN TB_PET.dt_nascimento%TYPE,
        p_nr_peso_kg    IN TB_PET.nr_peso_kg%TYPE,
        p_nm_raca       IN TB_RACA.nm_raca%TYPE,
        p_nm_especie    IN TB_ESPECIE.nm_especie%TYPE,
        p_nm_tutor      IN TB_TUTOR.nm_tutor%TYPE
    ) RETURN VARCHAR2
    IS
        e_id_invalido   EXCEPTION; PRAGMA EXCEPTION_INIT(e_id_invalido,   -20101);
        e_nome_vazio    EXCEPTION; PRAGMA EXCEPTION_INIT(e_nome_vazio,    -20102);

        v_json          VARCHAR2(4000);
        v_msg           VARCHAR2(500);
        v_cod           NUMBER;

    BEGIN
        IF p_id_pet IS NULL OR p_id_pet <= 0 THEN
            RAISE_APPLICATION_ERROR(-20101, 'ID do pet invalido para geracao de JSON.');
        END IF;

        IF TRIM(p_nm_pet) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20102, 'Nome do pet vazio, nao e possivel montar o JSON.');
        END IF;

        v_json := '{'
            || '"id_pet":' || p_id_pet
            || ',"nome":"' || fnc_escapar(p_nm_pet) || '"'
            || ',"data_nascimento":"' || TO_CHAR(p_dt_nascimento, 'YYYY-MM-DD') || '"'
            || ',"peso_kg":' || NVL(TO_CHAR(p_nr_peso_kg, 'FM999990D00', 'NLS_NUMERIC_CHARACTERS=''.,'''), 'null')
            || ',"raca":"' || fnc_escapar(p_nm_raca) || '"'
            || ',"especie":"' || fnc_escapar(p_nm_especie) || '"'
            || ',"tutor":"' || fnc_escapar(p_nm_tutor) || '"'
            || '}';

        RETURN v_json;

    EXCEPTION
        WHEN e_id_invalido THEN
            v_msg := 'ID de pet invalido: ' || NVL(TO_CHAR(p_id_pet), 'NULL') || ' | ' || SQLERRM;
            pkg_log_erro.prc_registrar('fnc_montar_json_pet', -20101, v_msg);
            RAISE;
        WHEN e_nome_vazio THEN
            v_msg := 'Nome vazio para pet id=' || NVL(TO_CHAR(p_id_pet), 'NULL') || ' | ' || SQLERRM;
            pkg_log_erro.prc_registrar('fnc_montar_json_pet', -20102, v_msg);
            RAISE;
        WHEN OTHERS THEN
            v_cod := SQLCODE;
            v_msg := SQLERRM;
            pkg_log_erro.prc_registrar('fnc_montar_json_pet', v_cod, v_msg);
            RAISE;
    END fnc_montar_json_pet;

    PROCEDURE prc_listar_pets_tutores_json (
        p_json_saida OUT CLOB,
        p_id_tutor   IN TB_TUTOR.id_tutor%TYPE DEFAULT NULL
    ) IS

        e_sem_pets    EXCEPTION; PRAGMA EXCEPTION_INIT(e_sem_pets,    -20110);
        e_json_grande EXCEPTION; PRAGMA EXCEPTION_INIT(e_json_grande, -20112);

        CURSOR c_pets IS
            SELECT
                p.id_pet,
                p.nm_pet,
                p.dt_nascimento,
                p.nr_peso_kg,
                r.nm_raca,
                esp.nm_especie,
                t.nm_tutor
            FROM TB_PET p
            JOIN TB_TUTOR  t   ON p.id_tutor  = t.id_tutor
            JOIN TB_RACA   r   ON p.id_raca   = r.id_raca
            JOIN TB_ESPECIE esp ON r.id_especie = esp.id_especie
            WHERE (p_id_tutor IS NULL OR p.id_tutor = p_id_tutor)
            ORDER BY p.id_pet;

        v_total        NUMBER := 0;
        v_json_pet     VARCHAR2(4000);
        v_json_array   CLOB;
        v_msg          VARCHAR2(500);
        v_cod          NUMBER;

        C_TAMANHO_MAXIMO CONSTANT NUMBER := 100000;

    BEGIN
        SELECT COUNT(*) INTO v_total
        FROM TB_PET p
        WHERE (p_id_tutor IS NULL OR p.id_tutor = p_id_tutor);

        IF v_total = 0 THEN
            RAISE_APPLICATION_ERROR(-20110, 'Nenhum pet encontrado para gerar o JSON (tutor filtrado: '
                || NVL(TO_CHAR(p_id_tutor), 'TODOS') || ').');
        END IF;

        DBMS_LOB.CREATETEMPORARY(v_json_array, TRUE);
        v_json_array := '[';

        FOR r_pet IN c_pets LOOP
            v_json_pet := fnc_montar_json_pet(
                p_id_pet        => r_pet.id_pet,
                p_nm_pet        => r_pet.nm_pet,
                p_dt_nascimento => r_pet.dt_nascimento,
                p_nr_peso_kg    => r_pet.nr_peso_kg,
                p_nm_raca       => r_pet.nm_raca,
                p_nm_especie    => r_pet.nm_especie,
                p_nm_tutor      => r_pet.nm_tutor
            );

            IF DBMS_LOB.GETLENGTH(v_json_array) > 1 THEN
                v_json_array := v_json_array || ',';
            END IF;
            v_json_array := v_json_array || v_json_pet;

            IF DBMS_LOB.GETLENGTH(v_json_array) > C_TAMANHO_MAXIMO THEN
                RAISE_APPLICATION_ERROR(-20112, 'JSON gerado excedeu o tamanho maximo permitido.');
            END IF;
        END LOOP;

        v_json_array := v_json_array || ']';
        p_json_saida := v_json_array;

        DBMS_OUTPUT.PUT_LINE('Total de pets no JSON: ' || v_total);
        FOR i IN 0 .. TRUNC(DBMS_LOB.GETLENGTH(v_json_array) / 200) LOOP
            DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(v_json_array, 200, (i * 200) + 1));
        END LOOP;

    EXCEPTION
        WHEN e_sem_pets THEN
            v_msg := 'Nenhum pet encontrado (tutor filtrado: ' || NVL(TO_CHAR(p_id_tutor), 'TODOS') || '). | ' || SQLERRM;
            pkg_log_erro.prc_registrar('prc_listar_pets_tutores_json', -20110, v_msg);
            RAISE;
        WHEN e_json_grande THEN
            v_msg := 'JSON excedeu tamanho maximo (' || C_TAMANHO_MAXIMO || ' chars). | ' || SQLERRM;
            pkg_log_erro.prc_registrar('prc_listar_pets_tutores_json', -20112, v_msg);
            RAISE;
        WHEN OTHERS THEN
            v_cod := SQLCODE;
            v_msg := SQLERRM;
            pkg_log_erro.prc_registrar('prc_listar_pets_tutores_json', v_cod, v_msg);
            RAISE;
    END prc_listar_pets_tutores_json;

END pkg_json_pet;
/

-- 5. PKG_PET
-- Funcao 2: regra de negocio (idade em anos completos), antes feita no Java.

CREATE OR REPLACE PACKAGE pkg_pet AS
    FUNCTION fnc_calcular_idade (
        p_dt_nascimento IN DATE
    ) RETURN NUMBER;
END pkg_pet;
/

CREATE OR REPLACE PACKAGE BODY pkg_pet AS

    FUNCTION fnc_calcular_idade (
        p_dt_nascimento IN DATE
    ) RETURN NUMBER
    IS
        e_data_nula   EXCEPTION; PRAGMA EXCEPTION_INIT(e_data_nula,   -20120);
        e_data_futura EXCEPTION; PRAGMA EXCEPTION_INIT(e_data_futura, -20121);

        v_idade NUMBER;
        v_msg   VARCHAR2(500);
        v_cod   NUMBER;
    BEGIN
        IF p_dt_nascimento IS NULL THEN
            RAISE_APPLICATION_ERROR(-20120, 'Data de nascimento nula, nao e possivel calcular idade.');
        END IF;

        IF p_dt_nascimento > SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20121, 'Data de nascimento no futuro: ' || TO_CHAR(p_dt_nascimento, 'YYYY-MM-DD') || '.');
        END IF;

        v_idade := TRUNC(MONTHS_BETWEEN(SYSDATE, p_dt_nascimento) / 12);

        RETURN v_idade;

    EXCEPTION
        WHEN e_data_nula THEN
            v_msg := 'Data de nascimento nula. | ' || SQLERRM;
            pkg_log_erro.prc_registrar('fnc_calcular_idade', -20120, v_msg);
            RAISE;
        WHEN e_data_futura THEN
            v_msg := 'Data de nascimento futura: ' || TO_CHAR(p_dt_nascimento, 'YYYY-MM-DD') || ' | ' || SQLERRM;
            pkg_log_erro.prc_registrar('fnc_calcular_idade', -20121, v_msg);
            RAISE;
        WHEN OTHERS THEN
            v_cod := SQLCODE;
            v_msg := SQLERRM;
            pkg_log_erro.prc_registrar('fnc_calcular_idade', v_cod, v_msg);
            RAISE;
    END fnc_calcular_idade;

END pkg_pet;
/

-- 6. PKG_RELATORIO_CUSTOS
-- Procedimento 2: subtotais por clinica e total geral, calculados manualmente
-- (sem ROLLUP/CUBE/GROUPING SETS). O resultado fica em TB_RELATORIO_CUSTOS_CLINICA,
-- o que permite a aplicacao Java ler o relatorio depois da execucao.

CREATE OR REPLACE PACKAGE pkg_relatorio_custos AS
    PROCEDURE prc_resumo_custos_clinica_tipo (
        p_id_clinica IN TB_CLINICA.id_clinica%TYPE DEFAULT NULL
    );
END pkg_relatorio_custos;
/

CREATE OR REPLACE PACKAGE BODY pkg_relatorio_custos AS

    PROCEDURE prc_resumo_custos_clinica_tipo (
        p_id_clinica IN TB_CLINICA.id_clinica%TYPE DEFAULT NULL
    ) IS

        e_sem_dados      EXCEPTION; PRAGMA EXCEPTION_INIT(e_sem_dados,      -20130);
        e_custo_negativo EXCEPTION; PRAGMA EXCEPTION_INIT(e_custo_negativo, -20131);

        CURSOR c_custos IS
            SELECT
                c.nm_clinica,
                te.nm_tipo_evento,
                es.vl_custo
            FROM TB_EVENTO_SAUDE es
            JOIN TB_VETERINARIO v ON es.id_veterinario = v.id_veterinario
            JOIN TB_CLINICA     c ON v.id_clinica       = c.id_clinica
            JOIN TB_TIPO_EVENTO te ON es.id_tipo_evento = te.id_tipo_evento
            WHERE (p_id_clinica IS NULL OR c.id_clinica = p_id_clinica)
            ORDER BY c.nm_clinica, te.nm_tipo_evento;

        v_total_linhas    NUMBER := 0;

        v_clinica_atual    TB_CLINICA.nm_clinica%TYPE;
        v_tipo_atual       TB_TIPO_EVENTO.nm_tipo_evento%TYPE;
        v_soma_tipo        NUMBER := 0;
        v_subtotal_clinica NUMBER := 0;
        v_total_geral      NUMBER := 0;

        v_mensagem VARCHAR2(500);
        v_cod      NUMBER;

    BEGIN
        DELETE FROM TB_RELATORIO_CUSTOS_CLINICA;

        DBMS_OUTPUT.PUT_LINE(RPAD('Clinica', 28) || RPAD('Tipo Evento', 26) || LPAD('Valor', 12));
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 28, '-') || RPAD('-', 26, '-') || LPAD('-', 12, '-'));

        SELECT COUNT(*) INTO v_total_linhas
        FROM TB_EVENTO_SAUDE es
        JOIN TB_VETERINARIO v ON es.id_veterinario = v.id_veterinario
        JOIN TB_CLINICA     c ON v.id_clinica       = c.id_clinica
        JOIN TB_TIPO_EVENTO te ON es.id_tipo_evento = te.id_tipo_evento
        WHERE (p_id_clinica IS NULL OR c.id_clinica = p_id_clinica);

        IF v_total_linhas = 0 THEN
            RAISE_APPLICATION_ERROR(-20130, 'Nenhum evento de saude encontrado para gerar o resumo de custos (clinica filtrada: '
                || NVL(TO_CHAR(p_id_clinica), 'TODAS') || ').');
        END IF;

        FOR r_custo IN c_custos LOOP

            IF r_custo.vl_custo < 0 THEN
                RAISE_APPLICATION_ERROR(-20131, 'Custo negativo encontrado para clinica '
                    || r_custo.nm_clinica || ', tipo ' || r_custo.nm_tipo_evento || '.');
            END IF;

            IF v_clinica_atual IS NULL OR r_custo.nm_clinica <> v_clinica_atual THEN
                IF v_tipo_atual IS NOT NULL THEN
                    INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
                    VALUES (v_clinica_atual, v_tipo_atual, v_soma_tipo, 'DETALHE');
                    DBMS_OUTPUT.PUT_LINE(RPAD(v_clinica_atual, 28) || RPAD(v_tipo_atual, 26) || LPAD(TO_CHAR(v_soma_tipo, 'FM999999990.00'), 12));
                END IF;
                IF v_clinica_atual IS NOT NULL THEN
                    INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
                    VALUES (v_clinica_atual, NULL, v_subtotal_clinica, 'SUBTOTAL');
                    DBMS_OUTPUT.PUT_LINE(RPAD('Sub Total ' || v_clinica_atual, 54) || LPAD(TO_CHAR(v_subtotal_clinica, 'FM999999990.00'), 12));
                END IF;

                v_clinica_atual    := r_custo.nm_clinica;
                v_subtotal_clinica := 0;
                v_tipo_atual       := r_custo.nm_tipo_evento;
                v_soma_tipo        := 0;

            ELSIF r_custo.nm_tipo_evento <> v_tipo_atual THEN
                INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
                VALUES (v_clinica_atual, v_tipo_atual, v_soma_tipo, 'DETALHE');
                DBMS_OUTPUT.PUT_LINE(RPAD(v_clinica_atual, 28) || RPAD(v_tipo_atual, 26) || LPAD(TO_CHAR(v_soma_tipo, 'FM999999990.00'), 12));

                v_tipo_atual := r_custo.nm_tipo_evento;
                v_soma_tipo  := 0;
            END IF;

            v_soma_tipo        := v_soma_tipo + r_custo.vl_custo;
            v_subtotal_clinica := v_subtotal_clinica + r_custo.vl_custo;
            v_total_geral       := v_total_geral + r_custo.vl_custo;

        END LOOP;

        IF v_tipo_atual IS NOT NULL THEN
            INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
            VALUES (v_clinica_atual, v_tipo_atual, v_soma_tipo, 'DETALHE');
            DBMS_OUTPUT.PUT_LINE(RPAD(v_clinica_atual, 28) || RPAD(v_tipo_atual, 26) || LPAD(TO_CHAR(v_soma_tipo, 'FM999999990.00'), 12));
        END IF;
        IF v_clinica_atual IS NOT NULL THEN
            INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
            VALUES (v_clinica_atual, NULL, v_subtotal_clinica, 'SUBTOTAL');
            DBMS_OUTPUT.PUT_LINE(RPAD('Sub Total ' || v_clinica_atual, 54) || LPAD(TO_CHAR(v_subtotal_clinica, 'FM999999990.00'), 12));
        END IF;

        INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
        VALUES (NULL, NULL, v_total_geral, 'TOTAL');

        DBMS_OUTPUT.PUT_LINE(RPAD('-', 28, '-') || RPAD('-', 26, '-') || LPAD('-', 12, '-'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Total Geral', 54) || LPAD(TO_CHAR(v_total_geral, 'FM999999990.00'), 12));

        COMMIT;

    EXCEPTION
        WHEN e_sem_dados THEN
            v_mensagem := 'Nenhum evento encontrado (clinica filtrada: ' || NVL(TO_CHAR(p_id_clinica), 'TODAS') || '). | ' || SQLERRM;
            pkg_log_erro.prc_registrar('prc_resumo_custos_clinica_tipo', -20130, v_mensagem);
            RAISE;
        WHEN e_custo_negativo THEN
            v_mensagem := 'Custo negativo detectado. | ' || SQLERRM;
            pkg_log_erro.prc_registrar('prc_resumo_custos_clinica_tipo', -20131, v_mensagem);
            RAISE;
        WHEN OTHERS THEN
            v_cod := SQLCODE;
            v_mensagem := SQLERRM;
            pkg_log_erro.prc_registrar('prc_resumo_custos_clinica_tipo', v_cod, v_mensagem);
            RAISE;
    END prc_resumo_custos_clinica_tipo;

END pkg_relatorio_custos;
/

-- 7. PKG_AUDITORIA_EVENTO
-- Rotinas de apoio do gatilho de auditoria. Evita repetir a montagem do texto
-- de valores (:OLD/:NEW) tres vezes dentro do gatilho.

CREATE OR REPLACE PACKAGE pkg_auditoria_evento AS

    -- Monta o texto "campo=valor" que descreve uma linha de TB_EVENTO_SAUDE.
    FUNCTION fnc_descrever_evento (
        p_id_pet         IN NUMBER,
        p_id_tipo_evento IN NUMBER,
        p_id_veterinario IN NUMBER,
        p_dt_evento      IN DATE,
        p_vl_custo       IN NUMBER,
        p_ds_status      IN VARCHAR2
    ) RETURN VARCHAR2;

    -- Grava uma linha em TB_AUDITORIA_EVENTO (mesma transacao do DML auditado).
    PROCEDURE prc_registrar (
        p_ds_operacao       IN VARCHAR2,
        p_id_evento_afetado IN NUMBER,
        p_valores_antigos   IN VARCHAR2,
        p_valores_novos     IN VARCHAR2
    );

END pkg_auditoria_evento;
/

CREATE OR REPLACE PACKAGE BODY pkg_auditoria_evento AS

    FUNCTION fnc_descrever_evento (
        p_id_pet         IN NUMBER,
        p_id_tipo_evento IN NUMBER,
        p_id_veterinario IN NUMBER,
        p_dt_evento      IN DATE,
        p_vl_custo       IN NUMBER,
        p_ds_status      IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN 'id_pet=' || p_id_pet
            || ', id_tipo_evento=' || p_id_tipo_evento
            || ', id_veterinario=' || p_id_veterinario
            || ', dt_evento=' || TO_CHAR(p_dt_evento, 'YYYY-MM-DD')
            || ', vl_custo=' || p_vl_custo
            || ', ds_status=' || p_ds_status;
    END fnc_descrever_evento;

    PROCEDURE prc_registrar (
        p_ds_operacao       IN VARCHAR2,
        p_id_evento_afetado IN NUMBER,
        p_valores_antigos   IN VARCHAR2,
        p_valores_novos     IN VARCHAR2
    ) IS
        e_operacao_invalida EXCEPTION; PRAGMA EXCEPTION_INIT(e_operacao_invalida, -20140);
        e_evento_nulo       EXCEPTION; PRAGMA EXCEPTION_INIT(e_evento_nulo,       -20141);
        v_msg VARCHAR2(500);
    BEGIN
        IF p_ds_operacao IS NULL OR p_ds_operacao NOT IN ('INSERT', 'UPDATE', 'DELETE') THEN
            RAISE_APPLICATION_ERROR(-20140, 'Operacao de auditoria invalida: ' || NVL(p_ds_operacao, 'NULL') || '.');
        END IF;

        IF p_id_evento_afetado IS NULL THEN
            RAISE_APPLICATION_ERROR(-20141, 'Evento afetado nulo, auditoria nao registrada.');
        END IF;

        INSERT INTO TB_AUDITORIA_EVENTO (ds_operacao, id_evento_afetado, ds_valores_antigos, ds_valores_novos)
        VALUES (p_ds_operacao, p_id_evento_afetado, p_valores_antigos, p_valores_novos);

    EXCEPTION
        WHEN e_operacao_invalida THEN
            v_msg := 'Operacao invalida. | ' || SQLERRM;
            pkg_log_erro.prc_registrar('pkg_auditoria_evento.prc_registrar', -20140, v_msg);
            RAISE;
        WHEN e_evento_nulo THEN
            v_msg := 'Evento nulo. | ' || SQLERRM;
            pkg_log_erro.prc_registrar('pkg_auditoria_evento.prc_registrar', -20141, v_msg);
            RAISE;
        WHEN OTHERS THEN
            v_msg := SQLERRM;
            pkg_log_erro.prc_registrar('pkg_auditoria_evento.prc_registrar', SQLCODE, v_msg);
            RAISE;
    END prc_registrar;

END pkg_auditoria_evento;
/

-- 8. TRIGGER - TRG_AUDITORIA_EVENTO_SAUDE
-- Gatilho nao pode ficar dentro de pacote; ele apenas delega ao PKG_AUDITORIA_EVENTO.

CREATE OR REPLACE TRIGGER trg_auditoria_evento_saude
AFTER INSERT OR UPDATE OR DELETE ON TB_EVENTO_SAUDE
FOR EACH ROW
DECLARE
    v_operacao VARCHAR2(10);
    v_antigos  VARCHAR2(1000);
    v_novos    VARCHAR2(1000);
BEGIN
    IF INSERTING THEN
        v_operacao := 'INSERT';
        v_novos := pkg_auditoria_evento.fnc_descrever_evento(
            :NEW.id_pet, :NEW.id_tipo_evento, :NEW.id_veterinario,
            :NEW.dt_evento, :NEW.vl_custo, :NEW.ds_status);

    ELSIF UPDATING THEN
        v_operacao := 'UPDATE';
        v_antigos := pkg_auditoria_evento.fnc_descrever_evento(
            :OLD.id_pet, :OLD.id_tipo_evento, :OLD.id_veterinario,
            :OLD.dt_evento, :OLD.vl_custo, :OLD.ds_status);
        v_novos := pkg_auditoria_evento.fnc_descrever_evento(
            :NEW.id_pet, :NEW.id_tipo_evento, :NEW.id_veterinario,
            :NEW.dt_evento, :NEW.vl_custo, :NEW.ds_status);

    ELSIF DELETING THEN
        v_operacao := 'DELETE';
        v_antigos := pkg_auditoria_evento.fnc_descrever_evento(
            :OLD.id_pet, :OLD.id_tipo_evento, :OLD.id_veterinario,
            :OLD.dt_evento, :OLD.vl_custo, :OLD.ds_status);
    END IF;

    pkg_auditoria_evento.prc_registrar(
        v_operacao, NVL(:NEW.id_evento, :OLD.id_evento), v_antigos, v_novos);
END trg_auditoria_evento_saude;
/

-- 9. PKG_EXPORTACAO_JSON
-- Gera o dataset que sera importado no MongoDB: um documento por TUTOR com o
-- ARRAY DE PETS embutido. JSON montado manualmente (sem TO_JSON/JSON_OBJECT).
-- Datas saem em Extended JSON ({"$date": ...}) para o mongoimport criar o tipo Date.
-- Dados sensiveis (CPF, senha) NAO sao exportados.

CREATE OR REPLACE PACKAGE pkg_exportacao_json AS

    -- Retorna o array JSON de tutores (um documento por linha).
    FUNCTION fnc_gerar_json_tutores RETURN CLOB;

    -- Mesma saida via parametro OUT (facil de chamar pela aplicacao Java).
    PROCEDURE prc_exportar_tutores_json (p_json_saida OUT CLOB);

END pkg_exportacao_json;
/

CREATE OR REPLACE PACKAGE BODY pkg_exportacao_json AS

    -- Concatena texto em um CLOB sem estourar limites de VARCHAR2.
    PROCEDURE anexar (p_clob IN OUT NOCOPY CLOB, p_texto IN VARCHAR2) IS
    BEGIN
        IF p_texto IS NOT NULL AND LENGTH(p_texto) > 0 THEN
            DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(p_texto), p_texto);
        END IF;
    END anexar;

    -- JSON de um pet embutido no tutor.
    FUNCTION fnc_json_pet_embutido (
        p_id_pet        IN NUMBER,
        p_nm_pet        IN VARCHAR2,
        p_dt_nascimento IN DATE,
        p_ds_sexo       IN VARCHAR2,
        p_nr_peso_kg    IN NUMBER,
        p_nm_raca       IN VARCHAR2,
        p_nm_especie    IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN '{'
            || '"id_pet":' || p_id_pet
            || ',"nome":"' || pkg_json_pet.fnc_escapar(p_nm_pet) || '"'
            || ',"data_nascimento":{"$date":"' || TO_CHAR(p_dt_nascimento, 'YYYY-MM-DD') || 'T00:00:00Z"}'
            || ',"sexo":' || CASE WHEN p_ds_sexo IS NULL THEN 'null' ELSE '"' || p_ds_sexo || '"' END
            || ',"peso_kg":' || NVL(TO_CHAR(p_nr_peso_kg, 'FM999990D00', 'NLS_NUMERIC_CHARACTERS=''.,'''), 'null')
            || ',"raca":"' || pkg_json_pet.fnc_escapar(p_nm_raca) || '"'
            || ',"especie":"' || pkg_json_pet.fnc_escapar(p_nm_especie) || '"'
            || '}';
    END fnc_json_pet_embutido;

    FUNCTION fnc_gerar_json_tutores RETURN CLOB IS
        e_sem_tutores   EXCEPTION; PRAGMA EXCEPTION_INIT(e_sem_tutores,   -20150);
        e_tutor_invalido EXCEPTION; PRAGMA EXCEPTION_INIT(e_tutor_invalido, -20151);

        CURSOR c_tutores IS
            SELECT id_tutor, nm_tutor, ds_email, nr_telefone, dt_cadastro
            FROM TB_TUTOR
            ORDER BY id_tutor;

        CURSOR c_pets (p_id_tutor IN NUMBER) IS
            SELECT p.id_pet, p.nm_pet, p.dt_nascimento, p.ds_sexo, p.nr_peso_kg,
                   r.nm_raca, esp.nm_especie
            FROM TB_PET p
            JOIN TB_RACA    r   ON p.id_raca     = r.id_raca
            JOIN TB_ESPECIE esp ON r.id_especie  = esp.id_especie
            WHERE p.id_tutor = p_id_tutor
            ORDER BY p.id_pet;

        v_json      CLOB;
        v_total     NUMBER := 0;
        v_primeiro  BOOLEAN := TRUE;
        v_pet_ini   BOOLEAN;
        v_msg       VARCHAR2(500);
    BEGIN
        SELECT COUNT(*) INTO v_total FROM TB_TUTOR;
        IF v_total = 0 THEN
            RAISE_APPLICATION_ERROR(-20150, 'Nenhum tutor cadastrado para exportar.');
        END IF;

        DBMS_LOB.CREATETEMPORARY(v_json, TRUE);
        anexar(v_json, '[');

        FOR r_tutor IN c_tutores LOOP
            IF TRIM(r_tutor.nm_tutor) IS NULL THEN
                RAISE_APPLICATION_ERROR(-20151, 'Tutor id=' || r_tutor.id_tutor || ' com nome vazio.');
            END IF;

            IF v_primeiro THEN
                anexar(v_json, CHR(10));
                v_primeiro := FALSE;
            ELSE
                anexar(v_json, ',' || CHR(10));
            END IF;

            anexar(v_json, '{"_id":' || r_tutor.id_tutor
                || ',"nome":"'     || pkg_json_pet.fnc_escapar(r_tutor.nm_tutor) || '"'
                || ',"email":"'    || pkg_json_pet.fnc_escapar(r_tutor.ds_email) || '"'
                || ',"telefone":'  || CASE WHEN r_tutor.nr_telefone IS NULL THEN 'null'
                                           ELSE '"' || pkg_json_pet.fnc_escapar(r_tutor.nr_telefone) || '"' END
                || ',"data_cadastro":{"$date":"' || TO_CHAR(r_tutor.dt_cadastro, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || '"}'
                || ',"pets":[');

            v_pet_ini := TRUE;
            FOR r_pet IN c_pets(r_tutor.id_tutor) LOOP
                IF NOT v_pet_ini THEN
                    anexar(v_json, ',');
                END IF;
                v_pet_ini := FALSE;
                anexar(v_json, fnc_json_pet_embutido(
                    r_pet.id_pet, r_pet.nm_pet, r_pet.dt_nascimento, r_pet.ds_sexo,
                    r_pet.nr_peso_kg, r_pet.nm_raca, r_pet.nm_especie));
            END LOOP;

            anexar(v_json, ']}');
        END LOOP;

        anexar(v_json, CHR(10) || ']');
        RETURN v_json;

    EXCEPTION
        WHEN e_sem_tutores THEN
            v_msg := 'Sem tutores. | ' || SQLERRM;
            pkg_log_erro.prc_registrar('pkg_exportacao_json.fnc_gerar_json_tutores', -20150, v_msg);
            RAISE;
        WHEN e_tutor_invalido THEN
            v_msg := 'Tutor invalido. | ' || SQLERRM;
            pkg_log_erro.prc_registrar('pkg_exportacao_json.fnc_gerar_json_tutores', -20151, v_msg);
            RAISE;
        WHEN OTHERS THEN
            v_msg := SQLERRM;
            pkg_log_erro.prc_registrar('pkg_exportacao_json.fnc_gerar_json_tutores', SQLCODE, v_msg);
            RAISE;
    END fnc_gerar_json_tutores;

    PROCEDURE prc_exportar_tutores_json (p_json_saida OUT CLOB) IS
    BEGIN
        p_json_saida := fnc_gerar_json_tutores;
        DBMS_OUTPUT.PUT_LINE('JSON de tutores gerado: ' || DBMS_LOB.GETLENGTH(p_json_saida) || ' caracteres.');
    END prc_exportar_tutores_json;

END pkg_exportacao_json;
/
