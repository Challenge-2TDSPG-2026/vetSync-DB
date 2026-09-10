-- CLYVOVET / VETSYNC - Mastering Relational and Non-Relational Database
-- Sprint 3 - Script de entrega consolidado
--
-- Equipe: Arthur Brito da Silva (RM562085)
-- Pedro Henrique Brum Lopes (RM561780)
-- Luiz Felipe Flosi dos Santos (RM563197)

-- Este script e AUTOCONTIDO: cria do zero todas as tabelas usadas pelos
-- objetos desta sprint (apenas as tabelas realmente referenciadas pelas 2
-- procedures, 2 functions e 1 trigger abaixo) e popula com dados
-- de exemplo (minimo 5 registros por tabela envolvida no JOIN) e cria os
-- objetos PL/SQL exigidos na Sprint 3.
--
-- Estrutura deste arquivo:
--   0. Limpeza (idempotente - roda sem erro mesmo em schema vazio)
--   1. CREATE TABLE (ordem de dependencia: espec/tutor/clinica -> raca/vet
--      -> pet -> evento_saude -> auditoria/log/relatorio)
--   2. INSERT INTO (dados de exemplo)
--   3. PRC_LOG_ERRO (utilitario de log com transacao autonoma)
--   4. FUNCAO 1 - FNC_MONTAR_JSON_PET (conversao manual para JSON)
--   5. PROCEDIMENTO 1 - PRC_LISTAR_PETS_TUTORES_JSON (JOIN + JSON)
--   6. FUNCAO 2 - FNC_CALCULAR_IDADE (regra de negocio)
--   7. PROCEDIMENTO 2 - PRC_RESUMO_CUSTOS_CLINICA_TIPO (subtotais manuais)
--   8. TRIGGER - TRG_AUDITORIA_EVENTO_SAUDE (auditoria de INSERT/UPDATE/DELETE)

SET SERVEROUTPUT ON;

-- 0. LIMPEZA (idempotente)

BEGIN
    FOR t IN (
        SELECT table_name FROM user_tables
        WHERE table_name IN (
            'TB_AUDITORIA', 'TB_RELATORIO_CUSTOS_CLINICA', 'TB_EVENTO_SAUDE',
            'TB_TIPO_EVENTO', 'TB_VETERINARIO', 'TB_CLINICA', 'TB_PET',
            'TB_RACA', 'TB_ESPECIE', 'TB_TUTOR', 'TB_LOG_ERROS'
        )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
END;
/

BEGIN
    FOR p IN (
        SELECT object_name, object_type FROM user_objects
        WHERE object_type IN ('PROCEDURE', 'FUNCTION')
          AND object_name IN (
            'PRC_LOG_ERRO', 'FNC_MONTAR_JSON_PET', 'PRC_LISTAR_PETS_TUTORES_JSON',
            'FNC_CALCULAR_IDADE', 'PRC_RESUMO_CUSTOS_CLINICA_TIPO'
        )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP ' || p.object_type || ' ' || p.object_name;
    END LOOP;
END;
/


-- 1. CREATE TABLE (apenas as tabelas usadas pelos objetos desta sprint)

CREATE TABLE TB_LOG_ERROS (
    id_log         NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_procedure   VARCHAR2(100),
    nm_usuario     VARCHAR2(100) DEFAULT USER,
    dt_ocorrencia  TIMESTAMP     DEFAULT SYSTIMESTAMP,
    nr_codigo_erro NUMBER(10),
    ds_mensagem    VARCHAR2(500)
);

CREATE TABLE TB_TUTOR (
    id_tutor    NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_tutor    VARCHAR2(100) NOT NULL,
    ds_email    VARCHAR2(150) NOT NULL UNIQUE,
    nr_telefone VARCHAR2(20),
    ds_cpf      CHAR(11)      NOT NULL UNIQUE,
    ds_senha    VARCHAR2(255) NOT NULL,
    dt_cadastro DATE          DEFAULT SYSDATE NOT NULL
);

CREATE TABLE TB_ESPECIE (
    id_especie NUMBER(5)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_especie VARCHAR2(50) NOT NULL UNIQUE
);

CREATE TABLE TB_RACA (
    id_raca    NUMBER(5)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_raca    VARCHAR2(80) NOT NULL,
    id_especie NUMBER(5)    NOT NULL,
    CONSTRAINT fk_raca_especie FOREIGN KEY (id_especie) REFERENCES TB_ESPECIE(id_especie)
);

CREATE TABLE TB_PET (
    id_pet        NUMBER(10)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_pet        VARCHAR2(80) NOT NULL,
    dt_nascimento DATE         NOT NULL,
    ds_sexo       CHAR(1)      CHECK (ds_sexo IN ('M','F')),
    nr_peso_kg    NUMBER(5,2),
    id_tutor      NUMBER(10)   NOT NULL,
    id_raca       NUMBER(5)    NOT NULL,
    CONSTRAINT fk_pet_tutor FOREIGN KEY (id_tutor) REFERENCES TB_TUTOR(id_tutor),
    CONSTRAINT fk_pet_raca  FOREIGN KEY (id_raca)  REFERENCES TB_RACA(id_raca)
);

CREATE TABLE TB_CLINICA (
    id_clinica NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_clinica VARCHAR2(150) NOT NULL,
    ds_cnpj    CHAR(14)      NOT NULL UNIQUE,
    ds_cidade  VARCHAR2(80),
    ds_uf      CHAR(2)
);

CREATE TABLE TB_VETERINARIO (
    id_veterinario NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_veterinario VARCHAR2(100) NOT NULL,
    nr_crmv        VARCHAR2(20)  NOT NULL UNIQUE,
    ds_email       VARCHAR2(150) NOT NULL UNIQUE,
    ds_senha       VARCHAR2(255) NOT NULL,
    id_clinica     NUMBER(10)    NOT NULL,
    CONSTRAINT fk_vet_clinica FOREIGN KEY (id_clinica) REFERENCES TB_CLINICA(id_clinica)
);

CREATE TABLE TB_TIPO_EVENTO (
    id_tipo_evento NUMBER(5)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_tipo_evento VARCHAR2(80) NOT NULL,
    ds_categoria   VARCHAR2(30) CHECK (ds_categoria IN ('PREVENTIVO','TERAPEUTICO','BEM_ESTAR','EMERGENCIA')),
    nr_pontos      NUMBER(5)    DEFAULT 0 NOT NULL
);

CREATE TABLE TB_EVENTO_SAUDE (
    id_evento              NUMBER(10)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pet                 NUMBER(10)   NOT NULL,
    id_tipo_evento         NUMBER(5)    NOT NULL,
    id_veterinario         NUMBER(10),
    dt_evento              DATE         NOT NULL,
    ds_observacao          VARCHAR2(500),
    vl_custo               NUMBER(10,2) DEFAULT 0,
    ds_status              VARCHAR2(20) DEFAULT 'AGENDADO' NOT NULL,
    ds_motivo_cancelamento VARCHAR2(300),
    CONSTRAINT fk_ev_pet    FOREIGN KEY (id_pet)         REFERENCES TB_PET(id_pet),
    CONSTRAINT fk_ev_tipo   FOREIGN KEY (id_tipo_evento) REFERENCES TB_TIPO_EVENTO(id_tipo_evento),
    CONSTRAINT fk_ev_vet    FOREIGN KEY (id_veterinario) REFERENCES TB_VETERINARIO(id_veterinario),
    CONSTRAINT ck_evento_status CHECK (ds_status IN ('AGENDADO','CONCLUIDO','CANCELADO'))
);

CREATE TABLE TB_RELATORIO_CUSTOS_CLINICA (
    id_linha       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_clinica     VARCHAR2(150),
    nm_tipo_evento VARCHAR2(80),
    vl_total       NUMBER(12,2),
    ds_tipo_linha  VARCHAR2(20) -- 'DETALHE', 'SUBTOTAL' ou 'TOTAL'
);

CREATE TABLE TB_AUDITORIA (
    id_auditoria       NUMBER        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_usuario         VARCHAR2(100) DEFAULT USER NOT NULL,
    ds_operacao        VARCHAR2(10)  NOT NULL,
    dt_operacao        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    id_evento_afetado  NUMBER,
    ds_valores_antigos VARCHAR2(1000),
    ds_valores_novos   VARCHAR2(1000),
    CONSTRAINT ck_auditoria_operacao CHECK (ds_operacao IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- 2. INSERT INTO (dados de exemplo - minimo 5 registros por tabela usada
-- nos JOINs dos Procedimentos 1 e 2)

-- 5 TUTORES
INSERT INTO TB_TUTOR (nm_tutor, ds_email, nr_telefone, ds_cpf, ds_senha) VALUES
    ('Maria Silva', 'maria@email.com', '11999990001', '11111111111', 'SENHA_HASH_1');
INSERT INTO TB_TUTOR (nm_tutor, ds_email, nr_telefone, ds_cpf, ds_senha) VALUES
    ('Joao Souza', 'joao@email.com', '11999990002', '22222222222', 'SENHA_HASH_2');
INSERT INTO TB_TUTOR (nm_tutor, ds_email, nr_telefone, ds_cpf, ds_senha) VALUES
    ('Ana Paula Ferreira', 'ana.ferreira@email.com', '11988887777', '12345678901', 'SENHA_HASH_3');
INSERT INTO TB_TUTOR (nm_tutor, ds_email, nr_telefone, ds_cpf, ds_senha) VALUES
    ('Carlos Mendes', 'carlos.mendes@email.com', '11977776666', '98765432100', 'SENHA_HASH_4');
INSERT INTO TB_TUTOR (nm_tutor, ds_email, nr_telefone, ds_cpf, ds_senha) VALUES
    ('Beatriz Torres', 'beatriz.torres@email.com', '11966665555', '11122233344', 'SENHA_HASH_5');

-- 5 ESPECIES
INSERT INTO TB_ESPECIE (nm_especie) VALUES ('Cachorro');
INSERT INTO TB_ESPECIE (nm_especie) VALUES ('Gato');
INSERT INTO TB_ESPECIE (nm_especie) VALUES ('Ave');
INSERT INTO TB_ESPECIE (nm_especie) VALUES ('Roedor');
INSERT INTO TB_ESPECIE (nm_especie) VALUES ('Reptil');

-- 5 RACAS (referenciando as especies acima pelo nome, via subquery)
INSERT INTO TB_RACA (nm_raca, id_especie)
    SELECT 'Golden Retriever', id_especie FROM TB_ESPECIE WHERE nm_especie = 'Cachorro';
INSERT INTO TB_RACA (nm_raca, id_especie)
    SELECT 'Siames', id_especie FROM TB_ESPECIE WHERE nm_especie = 'Gato';
INSERT INTO TB_RACA (nm_raca, id_especie)
    SELECT 'Pastor Alemao', id_especie FROM TB_ESPECIE WHERE nm_especie = 'Cachorro';
INSERT INTO TB_RACA (nm_raca, id_especie)
    SELECT 'Poodle', id_especie FROM TB_ESPECIE WHERE nm_especie = 'Cachorro';
INSERT INTO TB_RACA (nm_raca, id_especie)
    SELECT 'Persa', id_especie FROM TB_ESPECIE WHERE nm_especie = 'Gato';

-- 5 PETS
INSERT INTO TB_PET (nm_pet, dt_nascimento, ds_sexo, nr_peso_kg, id_tutor, id_raca)
    SELECT 'Buddy', DATE '2026-06-02', 'M', 5.0,
           (SELECT id_tutor FROM TB_TUTOR WHERE ds_email = 'maria@email.com'),
           (SELECT id_raca FROM TB_RACA WHERE nm_raca = 'Golden Retriever') FROM dual;
INSERT INTO TB_PET (nm_pet, dt_nascimento, ds_sexo, nr_peso_kg, id_tutor, id_raca)
    SELECT 'Luna', DATE '2022-09-02', 'F', 3.5,
           (SELECT id_tutor FROM TB_TUTOR WHERE ds_email = 'maria@email.com'),
           (SELECT id_raca FROM TB_RACA WHERE nm_raca = 'Siames') FROM dual;
INSERT INTO TB_PET (nm_pet, dt_nascimento, ds_sexo, nr_peso_kg, id_tutor, id_raca)
    SELECT 'Rex', DATE '2024-09-02', 'M', 28.0,
           (SELECT id_tutor FROM TB_TUTOR WHERE ds_email = 'joao@email.com'),
           (SELECT id_raca FROM TB_RACA WHERE nm_raca = 'Pastor Alemao') FROM dual;
INSERT INTO TB_PET (nm_pet, dt_nascimento, ds_sexo, nr_peso_kg, id_tutor, id_raca)
    SELECT 'Mel', DATE '2021-03-10', 'F', 4.2,
           (SELECT id_tutor FROM TB_TUTOR WHERE ds_email = 'ana.ferreira@email.com'),
           (SELECT id_raca FROM TB_RACA WHERE nm_raca = 'Poodle') FROM dual;
INSERT INTO TB_PET (nm_pet, dt_nascimento, ds_sexo, nr_peso_kg, id_tutor, id_raca)
    SELECT 'Simba', DATE '2022-08-22', 'M', 3.8,
           (SELECT id_tutor FROM TB_TUTOR WHERE ds_email = 'carlos.mendes@email.com'),
           (SELECT id_raca FROM TB_RACA WHERE nm_raca = 'Persa') FROM dual;

-- 3 CLINICAS
INSERT INTO TB_CLINICA (nm_clinica, ds_cnpj, ds_cidade, ds_uf) VALUES
    ('Clyvo Vet', '12345678000199', 'Sao Paulo', 'SP');
INSERT INTO TB_CLINICA (nm_clinica, ds_cnpj, ds_cidade, ds_uf) VALUES
    ('VetCare Centro Sprint3', '30303030000199', 'Sao Paulo', 'SP');
INSERT INTO TB_CLINICA (nm_clinica, ds_cnpj, ds_cidade, ds_uf) VALUES
    ('AnimalLife Sul Sprint3', '40404040000188', 'Curitiba', 'PR');

-- 3 VETERINARIOS (um por clinica)
INSERT INTO TB_VETERINARIO (nm_veterinario, nr_crmv, ds_email, ds_senha, id_clinica)
    SELECT 'Dra. Ana Costa', 'SP-12345', 'ana.vet@clyvovet.com', 'SENHA_HASH_VET1',
           (SELECT id_clinica FROM TB_CLINICA WHERE nm_clinica = 'Clyvo Vet') FROM dual;
INSERT INTO TB_VETERINARIO (nm_veterinario, nr_crmv, ds_email, ds_senha, id_clinica)
    SELECT 'Dr. Marcos Alves', 'SP-90001', 'marcos.alves@clyvovet.com', 'SENHA_HASH_VET2',
           (SELECT id_clinica FROM TB_CLINICA WHERE nm_clinica = 'VetCare Centro Sprint3') FROM dual;
INSERT INTO TB_VETERINARIO (nm_veterinario, nr_crmv, ds_email, ds_senha, id_clinica)
    SELECT 'Dra. Fernanda Rocha', 'PR-90002', 'fernanda.rocha@clyvovet.com', 'SENHA_HASH_VET3',
           (SELECT id_clinica FROM TB_CLINICA WHERE nm_clinica = 'AnimalLife Sul Sprint3') FROM dual;

-- 3 TIPOS DE EVENTO
INSERT INTO TB_TIPO_EVENTO (nm_tipo_evento, ds_categoria, nr_pontos) VALUES
    ('Vacina', 'PREVENTIVO', 20);
INSERT INTO TB_TIPO_EVENTO (nm_tipo_evento, ds_categoria, nr_pontos) VALUES
    ('Consulta de rotina', 'PREVENTIVO', 15);
INSERT INTO TB_TIPO_EVENTO (nm_tipo_evento, ds_categoria, nr_pontos) VALUES
    ('Banho e tosa', 'BEM_ESTAR', 5);

-- 9 EVENTOS DE SAUDE (3 clinicas x 3 tipos, para o Procedimento 2 mostrar
-- subtotal por clinica em um cenario com mais de uma clinica)
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Buddy'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Banho e tosa'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'ana.vet@clyvovet.com'),
           SYSDATE - 10, 'Banho e tosa de rotina', 80, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Luna'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Consulta de rotina'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'ana.vet@clyvovet.com'),
           SYSDATE - 30, 'Consulta de rotina, tudo normal', 150, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Rex'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Vacina'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'ana.vet@clyvovet.com'),
           SYSDATE - 5, 'Vacina antirrabica anual', 120, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Luna'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Vacina'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'marcos.alves@clyvovet.com'),
           SYSDATE - 20, 'Vacina anual', 200, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Rex'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Consulta de rotina'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'marcos.alves@clyvovet.com'),
           SYSDATE - 15, 'Consulta de retorno', 180, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Rex'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Banho e tosa'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'marcos.alves@clyvovet.com'),
           SYSDATE - 10, 'Banho e tosa', 70, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Mel'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Banho e tosa'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'fernanda.rocha@clyvovet.com'),
           SYSDATE - 25, 'Banho e tosa', 90, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Simba'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Vacina'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'fernanda.rocha@clyvovet.com'),
           SYSDATE - 18, 'Vacina anual', 210, 'CONCLUIDO' FROM dual;
INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo, ds_status)
    SELECT (SELECT id_pet FROM TB_PET WHERE nm_pet = 'Buddy'),
           (SELECT id_tipo_evento FROM TB_TIPO_EVENTO WHERE nm_tipo_evento = 'Consulta de rotina'),
           (SELECT id_veterinario FROM TB_VETERINARIO WHERE ds_email = 'fernanda.rocha@clyvovet.com'),
           SYSDATE - 12, 'Consulta de retorno', 160, 'CONCLUIDO' FROM dual;

COMMIT;

-- 3. UTILITARIO - PRC_LOG_ERRO

CREATE OR REPLACE PROCEDURE prc_log_erro (
    p_nm_procedure   IN TB_LOG_ERROS.nm_procedure%TYPE,
    p_nr_codigo_erro IN TB_LOG_ERROS.nr_codigo_erro%TYPE,
    p_ds_mensagem    IN TB_LOG_ERROS.ds_mensagem%TYPE
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
    VALUES (p_nm_procedure, p_nr_codigo_erro, p_ds_mensagem);
    COMMIT;
END prc_log_erro;
/

-- 4. FUNCAO 1 - FNC_MONTAR_JSON_PET

CREATE OR REPLACE FUNCTION fnc_montar_json_pet (
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

    FUNCTION escapar(p_texto IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF p_texto IS NULL THEN
            RETURN '';
        END IF;
        RETURN REPLACE(REPLACE(p_texto, '\', '\\'), '"', '\"');
    END escapar;

BEGIN
    IF p_id_pet IS NULL OR p_id_pet <= 0 THEN
        RAISE_APPLICATION_ERROR(-20101, 'ID do pet invalido para geracao de JSON.');
    END IF;

    IF TRIM(p_nm_pet) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20102, 'Nome do pet vazio, nao e possivel montar o JSON.');
    END IF;

    v_json := '{'
        || '"id_pet":' || p_id_pet
        || ',"nome":"' || escapar(p_nm_pet) || '"'
        || ',"data_nascimento":"' || TO_CHAR(p_dt_nascimento, 'YYYY-MM-DD') || '"'
        || ',"peso_kg":' || NVL(TO_CHAR(p_nr_peso_kg, 'FM999990D00', 'NLS_NUMERIC_CHARACTERS=''.,'''), 'null')
        || ',"raca":"' || escapar(p_nm_raca) || '"'
        || ',"especie":"' || escapar(p_nm_especie) || '"'
        || ',"tutor":"' || escapar(p_nm_tutor) || '"'
        || '}';

    RETURN v_json;

EXCEPTION
    WHEN e_id_invalido THEN
        v_msg := 'ID de pet invalido: ' || NVL(TO_CHAR(p_id_pet), 'NULL') || ' | ' || SQLERRM;
        prc_log_erro('fnc_montar_json_pet', -20101, v_msg);
        RAISE;
    WHEN e_nome_vazio THEN
        v_msg := 'Nome vazio para pet id=' || NVL(TO_CHAR(p_id_pet), 'NULL') || ' | ' || SQLERRM;
        prc_log_erro('fnc_montar_json_pet', -20102, v_msg);
        RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        prc_log_erro('fnc_montar_json_pet', v_cod, v_msg);
        RAISE;
END fnc_montar_json_pet;
/


-- 5. PROCEDIMENTO 1 - PRC_LISTAR_PETS_TUTORES_JSON

CREATE OR REPLACE PROCEDURE prc_listar_pets_tutores_json (
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
        prc_log_erro('prc_listar_pets_tutores_json', -20110, v_msg);
        RAISE;
    WHEN e_json_grande THEN
        v_msg := 'JSON excedeu tamanho maximo (' || C_TAMANHO_MAXIMO || ' chars). | ' || SQLERRM;
        prc_log_erro('prc_listar_pets_tutores_json', -20112, v_msg);
        RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        prc_log_erro('prc_listar_pets_tutores_json', v_cod, v_msg);
        RAISE;
END prc_listar_pets_tutores_json;
/

-- 6. FUNCAO 2 - FNC_CALCULAR_IDADE

CREATE OR REPLACE FUNCTION fnc_calcular_idade (
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
        prc_log_erro('fnc_calcular_idade', -20120, v_msg);
        RAISE;
    WHEN e_data_futura THEN
        v_msg := 'Data de nascimento futura: ' || TO_CHAR(p_dt_nascimento, 'YYYY-MM-DD') || ' | ' || SQLERRM;
        prc_log_erro('fnc_calcular_idade', -20121, v_msg);
        RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        prc_log_erro('fnc_calcular_idade', v_cod, v_msg);
        RAISE;
END fnc_calcular_idade;
/


-- 7. PROCEDIMENTO 2 - PRC_RESUMO_CUSTOS_CLINICA_TIPO

CREATE OR REPLACE PROCEDURE prc_resumo_custos_clinica_tipo (
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
            END IF;
            IF v_clinica_atual IS NOT NULL THEN
                INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
                VALUES (v_clinica_atual, NULL, v_subtotal_clinica, 'SUBTOTAL');
            END IF;

            v_clinica_atual    := r_custo.nm_clinica;
            v_subtotal_clinica := 0;
            v_tipo_atual       := r_custo.nm_tipo_evento;
            v_soma_tipo        := 0;

        ELSIF r_custo.nm_tipo_evento <> v_tipo_atual THEN
            INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
            VALUES (v_clinica_atual, v_tipo_atual, v_soma_tipo, 'DETALHE');

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
    END IF;
    IF v_clinica_atual IS NOT NULL THEN
        INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
        VALUES (v_clinica_atual, NULL, v_subtotal_clinica, 'SUBTOTAL');
    END IF;

    INSERT INTO TB_RELATORIO_CUSTOS_CLINICA (nm_clinica, nm_tipo_evento, vl_total, ds_tipo_linha)
    VALUES (NULL, NULL, v_total_geral, 'TOTAL');

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Resumo de custos gerado com sucesso. Total geral: ' || v_total_geral);

EXCEPTION
    WHEN e_sem_dados THEN
        v_mensagem := 'Nenhum evento encontrado (clinica filtrada: ' || NVL(TO_CHAR(p_id_clinica), 'TODAS') || '). | ' || SQLERRM;
        prc_log_erro('prc_resumo_custos_clinica_tipo', -20130, v_mensagem);
        RAISE;
    WHEN e_custo_negativo THEN
        v_mensagem := 'Custo negativo detectado. | ' || SQLERRM;
        prc_log_erro('prc_resumo_custos_clinica_tipo', -20131, v_mensagem);
        RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_mensagem := SQLERRM;
        prc_log_erro('prc_resumo_custos_clinica_tipo', v_cod, v_mensagem);
        RAISE;
END prc_resumo_custos_clinica_tipo;
/

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
        v_antigos  := NULL;
        v_novos    := 'id_pet=' || :NEW.id_pet
                    || ', id_tipo_evento=' || :NEW.id_tipo_evento
                    || ', id_veterinario=' || :NEW.id_veterinario
                    || ', dt_evento=' || TO_CHAR(:NEW.dt_evento, 'YYYY-MM-DD')
                    || ', vl_custo=' || :NEW.vl_custo
                    || ', ds_status=' || :NEW.ds_status;

    ELSIF UPDATING THEN
        v_operacao := 'UPDATE';
        v_antigos  := 'id_pet=' || :OLD.id_pet
                    || ', id_tipo_evento=' || :OLD.id_tipo_evento
                    || ', id_veterinario=' || :OLD.id_veterinario
                    || ', dt_evento=' || TO_CHAR(:OLD.dt_evento, 'YYYY-MM-DD')
                    || ', vl_custo=' || :OLD.vl_custo
                    || ', ds_status=' || :OLD.ds_status;
        v_novos    := 'id_pet=' || :NEW.id_pet
                    || ', id_tipo_evento=' || :NEW.id_tipo_evento
                    || ', id_veterinario=' || :NEW.id_veterinario
                    || ', dt_evento=' || TO_CHAR(:NEW.dt_evento, 'YYYY-MM-DD')
                    || ', vl_custo=' || :NEW.vl_custo
                    || ', ds_status=' || :NEW.ds_status;

    ELSIF DELETING THEN
        v_operacao := 'DELETE';
        v_antigos  := 'id_pet=' || :OLD.id_pet
                    || ', id_tipo_evento=' || :OLD.id_tipo_evento
                    || ', id_veterinario=' || :OLD.id_veterinario
                    || ', dt_evento=' || TO_CHAR(:OLD.dt_evento, 'YYYY-MM-DD')
                    || ', vl_custo=' || :OLD.vl_custo
                    || ', ds_status=' || :OLD.ds_status;
        v_novos    := NULL;
    END IF;

    INSERT INTO TB_AUDITORIA (ds_operacao, id_evento_afetado, ds_valores_antigos, ds_valores_novos)
    VALUES (v_operacao, NVL(:NEW.id_evento, :OLD.id_evento), v_antigos, v_novos);

END trg_auditoria_evento_saude;
/