--  0. LIMPEZA
BEGIN
    FOR t IN (
        SELECT table_name FROM user_tables
        WHERE table_name IN (
            'TB_PRESCRICAO','TB_EVENTO_SAUDE','TB_MEDICAMENTO',
            'TB_TIPO_EVENTO','TB_VETERINARIO','TB_CLINICA',
            'TB_PET','TB_RACA','TB_ESPECIE','TB_TUTOR','TB_LOG_ERROS'
        )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
END;
/

BEGIN
    FOR p IN (
        SELECT object_name FROM user_objects
        WHERE object_type = 'PROCEDURE'
          AND object_name IN (
            'PRC_INSERIR_TUTOR','PRC_INSERIR_ESPECIE','PRC_INSERIR_RACA',
            'PRC_INSERIR_PET','PRC_INSERIR_CLINICA','PRC_INSERIR_VETERINARIO',
            'PRC_INSERIR_TIPO_EVENTO','PRC_INSERIR_EVENTO_SAUDE',
            'PRC_INSERIR_MEDICAMENTO','PRC_INSERIR_PRESCRICAO'
        )
    ) LOOP
        EXECUTE IMMEDIATE 'DROP PROCEDURE ' || p.object_name;
    END LOOP;
END;
/


--  1. TABELAS

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
    id_clinica     NUMBER(10)    NOT NULL,
    CONSTRAINT fk_vet_clinica FOREIGN KEY (id_clinica) REFERENCES TB_CLINICA(id_clinica)
);

CREATE TABLE TB_TIPO_EVENTO (
    id_tipo_evento NUMBER(5)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_tipo_evento VARCHAR2(80) NOT NULL,
    ds_categoria   VARCHAR2(30) CHECK (ds_categoria IN ('PREVENTIVO','TERAPEUTICO','BEM_ESTAR','EMERGENCIA'))
);

CREATE TABLE TB_EVENTO_SAUDE (
    id_evento      NUMBER(10)   GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pet         NUMBER(10)   NOT NULL,
    id_tipo_evento NUMBER(5)    NOT NULL,
    id_veterinario NUMBER(10),
    dt_evento      DATE         NOT NULL,
    ds_observacao  VARCHAR2(500),
    vl_custo       NUMBER(10,2) DEFAULT 0,
    CONSTRAINT fk_ev_pet  FOREIGN KEY (id_pet)         REFERENCES TB_PET(id_pet),
    CONSTRAINT fk_ev_tipo FOREIGN KEY (id_tipo_evento) REFERENCES TB_TIPO_EVENTO(id_tipo_evento),
    CONSTRAINT fk_ev_vet  FOREIGN KEY (id_veterinario) REFERENCES TB_VETERINARIO(id_veterinario)
);

CREATE TABLE TB_MEDICAMENTO (
    id_medicamento NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nm_medicamento VARCHAR2(100) NOT NULL,
    ds_principio   VARCHAR2(100),
    vl_preco_ref   NUMBER(10,2)
);

CREATE TABLE TB_PRESCRICAO (
    id_prescricao  NUMBER(10)    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_evento      NUMBER(10)    NOT NULL,
    id_medicamento NUMBER(10)    NOT NULL,
    ds_posologia   VARCHAR2(200) NOT NULL,
    dt_inicio      DATE          NOT NULL,
    dt_fim         DATE,
    qt_doses_dia   NUMBER(3),
    CONSTRAINT fk_presc_evento FOREIGN KEY (id_evento)      REFERENCES TB_EVENTO_SAUDE(id_evento),
    CONSTRAINT fk_presc_med    FOREIGN KEY (id_medicamento) REFERENCES TB_MEDICAMENTO(id_medicamento)
);


--  2. PROCEDURES (CORRIGIDAS)

CREATE OR REPLACE PROCEDURE prc_inserir_tutor (
    p_nm_tutor    IN TB_TUTOR.nm_tutor%TYPE,
    p_ds_email    IN TB_TUTOR.ds_email%TYPE,
    p_nr_telefone IN TB_TUTOR.nr_telefone%TYPE,
    p_ds_cpf      IN TB_TUTOR.ds_cpf%TYPE
) IS
    e_cpf   EXCEPTION; PRAGMA EXCEPTION_INIT(e_cpf,   -20001);
    e_email EXCEPTION; PRAGMA EXCEPTION_INIT(e_email, -20002);
    v_msg   VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF LENGTH(p_ds_cpf) <> 11 OR REGEXP_INSTR(p_ds_cpf,'[^0-9]') > 0 THEN
        RAISE_APPLICATION_ERROR(-20001,'CPF invalido.');
    END IF;
    IF INSTR(p_ds_email,'@') = 0 THEN
        RAISE_APPLICATION_ERROR(-20002,'Email invalido.');
    END IF;
    INSERT INTO TB_TUTOR (nm_tutor, ds_email, nr_telefone, ds_cpf)
    VALUES (p_nm_tutor, p_ds_email, p_nr_telefone, p_ds_cpf);
    COMMIT;
EXCEPTION
    WHEN e_cpf THEN
        v_msg := 'CPF invalido: ' || p_nm_tutor || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_tutor', -20001, v_msg);
        COMMIT; RAISE;
    WHEN e_email THEN
        v_msg := 'Email invalido: ' || p_nm_tutor || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_tutor', -20002, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_tutor', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_tutor;
/

CREATE OR REPLACE PROCEDURE prc_inserir_especie (
    p_nm_especie IN TB_ESPECIE.nm_especie%TYPE
) IS
    e_vazio EXCEPTION; PRAGMA EXCEPTION_INIT(e_vazio, -20010);
    v_msg   VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF TRIM(p_nm_especie) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010,'Nome da especie vazio.');
    END IF;
    INSERT INTO TB_ESPECIE (nm_especie) VALUES (UPPER(TRIM(p_nm_especie)));
    COMMIT;
EXCEPTION
    WHEN e_vazio THEN
        v_msg := 'Nome vazio. | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_especie', -20010, v_msg);
        COMMIT; RAISE;
    WHEN DUP_VAL_ON_INDEX THEN
        v_msg := 'Especie duplicada: ' || p_nm_especie || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_especie', -1, v_msg);
        COMMIT;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_especie', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_especie;
/

CREATE OR REPLACE PROCEDURE prc_inserir_raca (
    p_nm_raca    IN TB_RACA.nm_raca%TYPE,
    p_id_especie IN TB_RACA.id_especie%TYPE
) IS
    e_especie EXCEPTION; PRAGMA EXCEPTION_INIT(e_especie, -20020);
    e_vazio   EXCEPTION; PRAGMA EXCEPTION_INIT(e_vazio,   -20021);
    v         NUMBER;
    v_msg     VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF TRIM(p_nm_raca) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20021,'Nome da raca vazio.');
    END IF;
    SELECT COUNT(*) INTO v FROM TB_ESPECIE WHERE id_especie = p_id_especie;
    IF v = 0 THEN
        RAISE_APPLICATION_ERROR(-20020,'Especie nao encontrada.');
    END IF;
    INSERT INTO TB_RACA (nm_raca, id_especie) VALUES (p_nm_raca, p_id_especie);
    COMMIT;
EXCEPTION
    WHEN e_vazio THEN
        v_msg := 'Nome vazio. | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_raca', -20021, v_msg);
        COMMIT; RAISE;
    WHEN e_especie THEN
        v_msg := 'Especie nao encontrada: ' || p_id_especie || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_raca', -20020, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_raca', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_raca;
/

CREATE OR REPLACE PROCEDURE prc_inserir_pet (
    p_nm_pet        IN TB_PET.nm_pet%TYPE,
    p_dt_nascimento IN TB_PET.dt_nascimento%TYPE,
    p_ds_sexo       IN TB_PET.ds_sexo%TYPE,
    p_nr_peso_kg    IN TB_PET.nr_peso_kg%TYPE,
    p_id_tutor      IN TB_PET.id_tutor%TYPE,
    p_id_raca       IN TB_PET.id_raca%TYPE
) IS
    e_sexo EXCEPTION; PRAGMA EXCEPTION_INIT(e_sexo, -20030);
    e_peso EXCEPTION; PRAGMA EXCEPTION_INIT(e_peso, -20031);
    v_msg  VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF p_ds_sexo NOT IN ('M','F') THEN
        RAISE_APPLICATION_ERROR(-20030,'Sexo invalido.');
    END IF;
    IF p_nr_peso_kg IS NOT NULL AND p_nr_peso_kg <= 0 THEN
        RAISE_APPLICATION_ERROR(-20031,'Peso invalido.');
    END IF;
    INSERT INTO TB_PET (nm_pet, dt_nascimento, ds_sexo, nr_peso_kg, id_tutor, id_raca)
    VALUES (p_nm_pet, p_dt_nascimento, p_ds_sexo, p_nr_peso_kg, p_id_tutor, p_id_raca);
    COMMIT;
EXCEPTION
    WHEN e_sexo THEN
        v_msg := 'Sexo invalido: ' || p_nm_pet || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_pet', -20030, v_msg);
        COMMIT; RAISE;
    WHEN e_peso THEN
        v_msg := 'Peso invalido: ' || p_nm_pet || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_pet', -20031, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_pet', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_pet;
/

CREATE OR REPLACE PROCEDURE prc_inserir_clinica (
    p_nm_clinica IN TB_CLINICA.nm_clinica%TYPE,
    p_ds_cnpj    IN TB_CLINICA.ds_cnpj%TYPE,
    p_ds_cidade  IN TB_CLINICA.ds_cidade%TYPE,
    p_ds_uf      IN TB_CLINICA.ds_uf%TYPE
) IS
    e_cnpj EXCEPTION; PRAGMA EXCEPTION_INIT(e_cnpj, -20040);
    e_uf   EXCEPTION; PRAGMA EXCEPTION_INIT(e_uf,   -20041);
    v_msg  VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF LENGTH(p_ds_cnpj) <> 14 OR REGEXP_INSTR(p_ds_cnpj,'[^0-9]') > 0 THEN
        RAISE_APPLICATION_ERROR(-20040,'CNPJ invalido.');
    END IF;
    IF LENGTH(p_ds_uf) <> 2 THEN
        RAISE_APPLICATION_ERROR(-20041,'UF invalida.');
    END IF;
    INSERT INTO TB_CLINICA (nm_clinica, ds_cnpj, ds_cidade, ds_uf)
    VALUES (p_nm_clinica, p_ds_cnpj, p_ds_cidade, UPPER(p_ds_uf));
    COMMIT;
EXCEPTION
    WHEN e_cnpj THEN
        v_msg := 'CNPJ invalido: ' || p_nm_clinica || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_clinica', -20040, v_msg);
        COMMIT; RAISE;
    WHEN e_uf THEN
        v_msg := 'UF invalida: ' || p_nm_clinica || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_clinica', -20041, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_clinica', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_clinica;
/

CREATE OR REPLACE PROCEDURE prc_inserir_veterinario (
    p_nm_veterinario IN TB_VETERINARIO.nm_veterinario%TYPE,
    p_nr_crmv        IN TB_VETERINARIO.nr_crmv%TYPE,
    p_id_clinica     IN TB_VETERINARIO.id_clinica%TYPE
) IS
    e_crmv    EXCEPTION; PRAGMA EXCEPTION_INIT(e_crmv,    -20050);
    e_clinica EXCEPTION; PRAGMA EXCEPTION_INIT(e_clinica, -20051);
    v         NUMBER;
    v_msg     VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF TRIM(p_nr_crmv) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20050,'CRMV vazio.');
    END IF;
    SELECT COUNT(*) INTO v FROM TB_CLINICA WHERE id_clinica = p_id_clinica;
    IF v = 0 THEN
        RAISE_APPLICATION_ERROR(-20051,'Clinica nao encontrada.');
    END IF;
    INSERT INTO TB_VETERINARIO (nm_veterinario, nr_crmv, id_clinica)
    VALUES (p_nm_veterinario, p_nr_crmv, p_id_clinica);
    COMMIT;
EXCEPTION
    WHEN e_crmv THEN
        v_msg := 'CRMV vazio: ' || p_nm_veterinario || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_veterinario', -20050, v_msg);
        COMMIT; RAISE;
    WHEN e_clinica THEN
        v_msg := 'Clinica nao encontrada: ' || p_id_clinica || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_veterinario', -20051, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_veterinario', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_veterinario;
/

CREATE OR REPLACE PROCEDURE prc_inserir_tipo_evento (
    p_nm_tipo_evento IN TB_TIPO_EVENTO.nm_tipo_evento%TYPE,
    p_ds_categoria   IN TB_TIPO_EVENTO.ds_categoria%TYPE
) IS
    e_cat  EXCEPTION; PRAGMA EXCEPTION_INIT(e_cat,  -20060);
    e_nome EXCEPTION; PRAGMA EXCEPTION_INIT(e_nome, -20061);
    v_msg  VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF TRIM(p_nm_tipo_evento) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20061,'Nome do tipo vazio.');
    END IF;
    IF p_ds_categoria NOT IN ('PREVENTIVO','TERAPEUTICO','BEM_ESTAR','EMERGENCIA') THEN
        RAISE_APPLICATION_ERROR(-20060,'Categoria invalida: ' || p_ds_categoria);
    END IF;
    INSERT INTO TB_TIPO_EVENTO (nm_tipo_evento, ds_categoria)
    VALUES (p_nm_tipo_evento, p_ds_categoria);
    COMMIT;
EXCEPTION
    WHEN e_nome THEN
        v_msg := 'Nome vazio. | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_tipo_evento', -20061, v_msg);
        COMMIT; RAISE;
    WHEN e_cat THEN
        v_msg := 'Categoria invalida: ' || p_ds_categoria || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_tipo_evento', -20060, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_tipo_evento', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_tipo_evento;
/

CREATE OR REPLACE PROCEDURE prc_inserir_evento_saude (
    p_id_pet         IN TB_EVENTO_SAUDE.id_pet%TYPE,
    p_id_tipo_evento IN TB_EVENTO_SAUDE.id_tipo_evento%TYPE,
    p_id_veterinario IN TB_EVENTO_SAUDE.id_veterinario%TYPE,
    p_dt_evento      IN TB_EVENTO_SAUDE.dt_evento%TYPE,
    p_ds_observacao  IN TB_EVENTO_SAUDE.ds_observacao%TYPE,
    p_vl_custo       IN TB_EVENTO_SAUDE.vl_custo%TYPE
) IS
    e_data  EXCEPTION; PRAGMA EXCEPTION_INIT(e_data,  -20070);
    e_custo EXCEPTION; PRAGMA EXCEPTION_INIT(e_custo, -20071);
    v_msg   VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF p_dt_evento > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20070,'Data futura nao permitida.');
    END IF;
    IF p_vl_custo < 0 THEN
        RAISE_APPLICATION_ERROR(-20071,'Custo negativo.');
    END IF;
    INSERT INTO TB_EVENTO_SAUDE (id_pet, id_tipo_evento, id_veterinario, dt_evento, ds_observacao, vl_custo)
    VALUES (p_id_pet, p_id_tipo_evento, p_id_veterinario, p_dt_evento, p_ds_observacao, p_vl_custo);
    COMMIT;
EXCEPTION
    WHEN e_data THEN
        v_msg := 'Data futura pet id=' || p_id_pet || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_evento_saude', -20070, v_msg);
        COMMIT; RAISE;
    WHEN e_custo THEN
        v_msg := 'Custo negativo pet id=' || p_id_pet || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_evento_saude', -20071, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_evento_saude', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_evento_saude;
/

CREATE OR REPLACE PROCEDURE prc_inserir_medicamento (
    p_nm_medicamento IN TB_MEDICAMENTO.nm_medicamento%TYPE,
    p_ds_principio   IN TB_MEDICAMENTO.ds_principio%TYPE,
    p_vl_preco_ref   IN TB_MEDICAMENTO.vl_preco_ref%TYPE
) IS
    e_preco EXCEPTION; PRAGMA EXCEPTION_INIT(e_preco, -20080);
    e_nome  EXCEPTION; PRAGMA EXCEPTION_INIT(e_nome,  -20081);
    v_msg   VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF TRIM(p_nm_medicamento) IS NULL THEN
        RAISE_APPLICATION_ERROR(-20081,'Nome do medicamento vazio.');
    END IF;
    IF p_vl_preco_ref IS NOT NULL AND p_vl_preco_ref < 0 THEN
        RAISE_APPLICATION_ERROR(-20080,'Preco negativo.');
    END IF;
    INSERT INTO TB_MEDICAMENTO (nm_medicamento, ds_principio, vl_preco_ref)
    VALUES (p_nm_medicamento, p_ds_principio, p_vl_preco_ref);
    COMMIT;
EXCEPTION
    WHEN e_preco THEN
        v_msg := 'Preco negativo: ' || p_nm_medicamento || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_medicamento', -20080, v_msg);
        COMMIT; RAISE;
    WHEN e_nome THEN
        v_msg := 'Nome vazio. | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_medicamento', -20081, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_medicamento', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_medicamento;
/

CREATE OR REPLACE PROCEDURE prc_inserir_prescricao (
    p_id_evento      IN TB_PRESCRICAO.id_evento%TYPE,
    p_id_medicamento IN TB_PRESCRICAO.id_medicamento%TYPE,
    p_ds_posologia   IN TB_PRESCRICAO.ds_posologia%TYPE,
    p_dt_inicio      IN TB_PRESCRICAO.dt_inicio%TYPE,
    p_dt_fim         IN TB_PRESCRICAO.dt_fim%TYPE,
    p_qt_doses_dia   IN TB_PRESCRICAO.qt_doses_dia%TYPE
) IS
    e_datas EXCEPTION; PRAGMA EXCEPTION_INIT(e_datas, -20090);
    e_doses EXCEPTION; PRAGMA EXCEPTION_INIT(e_doses, -20091);
    v_msg   VARCHAR2(500);
    v_cod   NUMBER;
BEGIN
    IF p_dt_fim IS NOT NULL AND p_dt_fim < p_dt_inicio THEN
        RAISE_APPLICATION_ERROR(-20090,'Dt_fim anterior ao inicio.');
    END IF;
    IF p_qt_doses_dia IS NOT NULL AND p_qt_doses_dia <= 0 THEN
        RAISE_APPLICATION_ERROR(-20091,'Doses invalidas.');
    END IF;
    INSERT INTO TB_PRESCRICAO (id_evento, id_medicamento, ds_posologia, dt_inicio, dt_fim, qt_doses_dia)
    VALUES (p_id_evento, p_id_medicamento, p_ds_posologia, p_dt_inicio, p_dt_fim, p_qt_doses_dia);
    COMMIT;
EXCEPTION
    WHEN e_datas THEN
        v_msg := 'Datas invalidas evento id=' || p_id_evento || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_prescricao', -20090, v_msg);
        COMMIT; RAISE;
    WHEN e_doses THEN
        v_msg := 'Doses invalidas evento id=' || p_id_evento || ' | ' || SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_prescricao', -20091, v_msg);
        COMMIT; RAISE;
    WHEN OTHERS THEN
        v_cod := SQLCODE;
        v_msg := SQLERRM;
        INSERT INTO TB_LOG_ERROS (nm_procedure, nr_codigo_erro, ds_mensagem)
        VALUES ('prc_inserir_prescricao', v_cod, v_msg);
        COMMIT; RAISE;
END prc_inserir_prescricao;
/


--  3. CARGA DE DADOS
-- Especies
BEGIN
    prc_inserir_especie('Cao');
    prc_inserir_especie('Gato');
    prc_inserir_especie('Ave');
    prc_inserir_especie('Roedor');
END;
/

-- Racas
BEGIN
    prc_inserir_raca('Golden Retriever', 1);
    prc_inserir_raca('Labrador',         1);
    prc_inserir_raca('Bulldog Frances',  1);
    prc_inserir_raca('Poodle',           1);
    prc_inserir_raca('Vira-lata',        1);
    prc_inserir_raca('Persa',            2);
    prc_inserir_raca('Siames',           2);
    prc_inserir_raca('Maine Coon',       2);
    prc_inserir_raca('Calopsita',        3);
    prc_inserir_raca('Hamster Sirio',    4);
END;
/

-- Tutores
BEGIN
    prc_inserir_tutor('Ana Paula Ferreira',  'ana.ferreira@email.com',   '11988887777', '12345678901');
    prc_inserir_tutor('Bruno Souza Lima',    'bruno.lima@email.com',     '11977776666', '98765432100');
    prc_inserir_tutor('Carla Mendes Costa',  'carla.costa@email.com',    '11966665555', '11122233344');
    prc_inserir_tutor('Diego Oliveira',      'diego.oliveira@email.com', '11955554444', '55566677788');
    prc_inserir_tutor('Elaine Torres',       'elaine.torres@email.com',  '11944443333', '99988877766');
    prc_inserir_tutor('Felipe Nascimento',   'felipe.nasc@email.com',    '11933332222', '33344455511');
END;
/

-- Pets
BEGIN
    prc_inserir_pet('Rex',    DATE '2020-03-15', 'M', 28.5, 1, 1);
    prc_inserir_pet('Mia',    DATE '2019-07-20', 'F',  4.2, 2, 6);
    prc_inserir_pet('Bob',    DATE '2021-01-10', 'M', 14.0, 3, 3);
    prc_inserir_pet('Luna',   DATE '2022-06-05', 'F',  7.8, 4, 4);
    prc_inserir_pet('Thor',   DATE '2018-11-30', 'M', 32.0, 5, 2);
    prc_inserir_pet('Bella',  DATE '2023-02-14', 'F',  3.1, 1, 7);
    prc_inserir_pet('Pipoca', DATE '2022-09-01', 'F',  0.3, 6, 10);
    prc_inserir_pet('Piu',    DATE '2021-04-22', 'M',  0.1, 3,  9);
END;
/

-- Clinicas
BEGIN
    prc_inserir_clinica('VetCare Centro',   '12345678000195', 'Sao Paulo',      'SP');
    prc_inserir_clinica('ClinicaPet Norte', '98765432000188', 'Curitiba',       'PR');
    prc_inserir_clinica('AnimalLife',       '11122233000144', 'Rio de Janeiro', 'RJ');
END;
/

-- Veterinarios
BEGIN
    prc_inserir_veterinario('Dr. Marcos Alves',    'SP-12345', 1);
    prc_inserir_veterinario('Dra. Juliana Lima',   'SP-54321', 1);
    prc_inserir_veterinario('Dr. Carlos Pereira',  'PR-11111', 2);
    prc_inserir_veterinario('Dra. Fernanda Rocha', 'RJ-22222', 3);
END;
/

-- Tipos de Evento
BEGIN
    prc_inserir_tipo_evento('Vacinacao V8/V10',       'PREVENTIVO');
    prc_inserir_tipo_evento('Vacinacao Antirabica',   'PREVENTIVO');
    prc_inserir_tipo_evento('Check-up Anual',         'PREVENTIVO');
    prc_inserir_tipo_evento('Vermifugacao',           'PREVENTIVO');
    prc_inserir_tipo_evento('Consulta Cronica',       'TERAPEUTICO');
    prc_inserir_tipo_evento('Adesao Medicamentosa',   'TERAPEUTICO');
    prc_inserir_tipo_evento('Orientacao Nutricional', 'BEM_ESTAR');
    prc_inserir_tipo_evento('Triagem Emergencial',    'EMERGENCIA');
END;
/

-- Medicamentos
BEGIN
    prc_inserir_medicamento('Frontline Plus',    'Fipronil',            85.90);
    prc_inserir_medicamento('Drontal Plus',      'Pamoato de pirantel', 45.00);
    prc_inserir_medicamento('Prednisolona 5mg',  'Prednisolona',        22.50);
    prc_inserir_medicamento('Amoxicilina 250mg', 'Amoxicilina',         38.00);
    prc_inserir_medicamento('Omeprazol 10mg',    'Omeprazol',           15.00);
END;
/

-- Eventos de Saude
BEGIN
    prc_inserir_evento_saude(1, 1, 1, DATE '2024-03-20', 'Vacinacao V10 anual.',         150.00);
    prc_inserir_evento_saude(1, 3, 1, DATE '2024-03-20', 'Check-up completo.',           200.00);
    prc_inserir_evento_saude(2, 2, 2, DATE '2024-04-15', 'Antirabica aplicada.',          80.00);
    prc_inserir_evento_saude(3, 4, 3, DATE '2024-05-10', 'Vermifugacao semestral.',       60.00);
    prc_inserir_evento_saude(4, 5, 4, DATE '2024-06-01', 'Controle dermatite atopica.',  350.00);
    prc_inserir_evento_saude(5, 1, 3, DATE '2024-07-12', 'V10 + Giardia.',              170.00);
    prc_inserir_evento_saude(6, 7, 2, DATE '2024-08-05', 'Dieta hipocalorica.',          180.00);
    prc_inserir_evento_saude(7, 3, 1, DATE '2024-09-18', 'Check-up roedor.',              90.00);
    prc_inserir_evento_saude(1, 6, 1, DATE '2025-01-10', 'Controle adesao Frontline.',   85.90);
    prc_inserir_evento_saude(4, 8, 4, DATE '2025-02-20', 'Triagem vomito persistente.', 300.00);
END;
/

-- Prescricoes
BEGIN
    prc_inserir_prescricao(9,  1, '1 pipeta na nuca a cada 30 dias', DATE '2025-01-10', DATE '2025-07-10', 1);
    prc_inserir_prescricao(10, 5, '1 comprimido ao dia em jejum',     DATE '2025-02-20', DATE '2025-03-20', 1);
    prc_inserir_prescricao(5,  3, '1 comprimido ao dia com racao',    DATE '2024-06-01', DATE '2024-07-01', 1);
    prc_inserir_prescricao(5,  4, '1 comprimido a cada 12 horas',     DATE '2024-06-01', DATE '2024-06-15', 2);
END;
/


--  4. RELATORIOS / CONSULTAS
-- Relatorio 1: Eventos por categoria e tipo
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== EVENTOS POR CATEGORIA E TIPO ===');
    FOR r IN (
        SELECT te.ds_categoria, te.nm_tipo_evento, COUNT(es.id_evento) AS total
          FROM TB_TIPO_EVENTO te
          LEFT JOIN TB_EVENTO_SAUDE es ON te.id_tipo_evento = es.id_tipo_evento
         GROUP BY te.ds_categoria, te.nm_tipo_evento
         ORDER BY te.ds_categoria, total DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(r.ds_categoria,'N/A'), 14) || ' ' ||
            RPAD(r.nm_tipo_evento, 28)          ||
            LPAD(r.total, 5)
        );
    END LOOP;
END;
/

-- Relatorio 2: Gastos por tutor e pet
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== GASTOS POR TUTOR E PET ===');
    FOR r IN (
        SELECT t.nm_tutor, p.nm_pet, COUNT(es.id_evento) AS qt, SUM(es.vl_custo) AS total
          FROM TB_TUTOR t
          JOIN TB_PET p           ON t.id_tutor = p.id_tutor
          JOIN TB_EVENTO_SAUDE es ON p.id_pet    = es.id_pet
         GROUP BY t.nm_tutor, p.nm_pet
         ORDER BY total DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.nm_tutor, 25) ||
            RPAD(r.nm_pet,   10) ||
            LPAD(r.qt, 5)        ||
            LPAD(TO_CHAR(r.total, 'FM999G990D00'), 12)
        );
    END LOOP;
END;
/

-- Relatorio 3: Atendimentos por clinica e veterinario
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ATENDIMENTOS POR CLINICA E VETERINARIO ===');
    FOR r IN (
        SELECT c.nm_clinica, v.nm_veterinario, COUNT(es.id_evento) AS atend
          FROM TB_CLINICA c
          JOIN TB_VETERINARIO v        ON c.id_clinica      = v.id_clinica
          LEFT JOIN TB_EVENTO_SAUDE es ON v.id_veterinario  = es.id_veterinario
         GROUP BY c.nm_clinica, v.nm_veterinario
         ORDER BY c.nm_clinica, atend DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.nm_clinica,      22) ||
            RPAD(r.nm_veterinario,  22) ||
            LPAD(r.atend, 6)
        );
    END LOOP;
END;
/

-- Relatorio 4: LAG/LEAD — custo anterior e proximo por pet
DECLARE
    CURSOR c IS
        SELECT id_evento, id_pet, dt_evento, vl_custo,
               LAG (vl_custo) OVER (PARTITION BY id_pet ORDER BY dt_evento) AS ant,
               LEAD(vl_custo) OVER (PARTITION BY id_pet ORDER BY dt_evento) AS prx
          FROM TB_EVENTO_SAUDE
         ORDER BY id_pet, dt_evento;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== CUSTO ANTERIOR E PROXIMO POR PET ===');
    DBMS_OUTPUT.PUT_LINE('ID_EV PET  DATA        ATUAL     ANTERIOR  PROXIMO');
    FOR r IN c LOOP
        DBMS_OUTPUT.PUT_LINE(
            LPAD(r.id_evento, 5) || ' ' ||
            LPAD(r.id_pet, 3)    || '  ' ||
            TO_CHAR(r.dt_evento,'DD/MM/YYYY') || '  ' ||
            LPAD(TO_CHAR(r.vl_custo, 'FM999G990D00'), 8) || '  ' ||
            LPAD(NVL(TO_CHAR(r.ant, 'FM999G990D00'), 'Vazio'), 8) || '  ' ||
            LPAD(NVL(TO_CHAR(r.prx, 'FM999G990D00'), 'Vazio'), 8)
        );
    END LOOP;
END;
/

-- Relatorio 5: Pets com classificacao de porte por peso
DECLARE
    CURSOR c IS
        SELECT p.nm_pet, p.nr_peso_kg, e.nm_especie, r.nm_raca, t.nm_tutor
          FROM TB_PET p
          JOIN TB_RACA r    ON p.id_raca    = r.id_raca
          JOIN TB_ESPECIE e ON r.id_especie = e.id_especie
          JOIN TB_TUTOR t   ON p.id_tutor   = t.id_tutor
         ORDER BY e.nm_especie, p.nm_pet;
    v_class VARCHAR2(10);
    v_tot   NUMBER := 0;
    v_qt    NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== CLASSIFICACAO DE PORTE DOS PETS ===');
    DBMS_OUTPUT.PUT_LINE(RPAD('PET',12)||RPAD('ESPECIE',8)||RPAD('RACA',18)||RPAD('TUTOR',20)||'PESO  CLASS.');
    FOR r IN c LOOP
        v_class := CASE
                       WHEN r.nr_peso_kg IS NULL THEN 'N/I'
                       WHEN r.nr_peso_kg < 5     THEN 'Pequeno'
                       WHEN r.nr_peso_kg < 15    THEN 'Medio'
                       ELSE                           'Grande'
                   END;
        v_tot := v_tot + NVL(r.nr_peso_kg, 0);
        v_qt  := v_qt  + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.nm_pet,     12) ||
            RPAD(r.nm_especie,  8) ||
            RPAD(r.nm_raca,    18) ||
            RPAD(r.nm_tutor,   20) ||
            LPAD(TO_CHAR(NVL(r.nr_peso_kg,0),'FM990D0'), 5) || '  ' || v_class
        );
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(
        'Total: ' || v_qt || ' pets | Peso medio: ' ||
        TO_CHAR(v_tot / GREATEST(v_qt,1), 'FM990D00') || ' kg'
    );
END;
/

-- Relatorio 6: Eventos com prescricao e comparacao com media de custo
DECLARE
    CURSOR c IS
        SELECT es.id_evento, p.nm_pet, te.nm_tipo_evento, es.dt_evento, es.vl_custo,
               COUNT(pr.id_prescricao) AS qt_presc
          FROM TB_EVENTO_SAUDE es
          JOIN TB_PET p              ON es.id_pet         = p.id_pet
          JOIN TB_TIPO_EVENTO te     ON es.id_tipo_evento = te.id_tipo_evento
          LEFT JOIN TB_PRESCRICAO pr ON es.id_evento      = pr.id_evento
         GROUP BY es.id_evento, p.nm_pet, te.nm_tipo_evento, es.dt_evento, es.vl_custo
         ORDER BY es.dt_evento;
    v_media NUMBER;
    v_total NUMBER := 0;
    v_qt    NUMBER := 0;
    v_fp    VARCHAR2(15);
    v_fc    VARCHAR2(12);
BEGIN
    SELECT AVG(vl_custo) INTO v_media FROM TB_EVENTO_SAUDE;
    DBMS_OUTPUT.PUT_LINE('=== EVENTOS COM STATUS DE CUSTO E PRESCRICAO ===');
    DBMS_OUTPUT.PUT_LINE(RPAD('PET',9)||RPAD('TIPO',22)||RPAD('DATA',12)||LPAD('CUSTO',9)||' PRESCRICAO     STATUS');
    FOR r IN c LOOP
        v_fp := CASE WHEN r.qt_presc > 0 THEN 'Com prescricao' ELSE 'Sem prescricao' END;
        v_fc := CASE
                    WHEN r.vl_custo > v_media THEN 'Acima media'
                    WHEN r.vl_custo = v_media THEN 'Na media'
                    ELSE                           'Abaixo media'
                END;
        v_total := v_total + r.vl_custo;
        v_qt    := v_qt + 1;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(r.nm_pet,           9) ||
            RPAD(r.nm_tipo_evento,  22) ||
            RPAD(TO_CHAR(r.dt_evento,'DD/MM/YYYY'), 12) ||
            LPAD(TO_CHAR(r.vl_custo,'FM999G990D00'), 9) || ' ' ||
            RPAD(v_fp, 15) || v_fc
        );
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(
        'Total: ' || v_qt || ' | R$ ' ||
        TO_CHAR(v_total,'FM999G990D00') || ' | Media: R$ ' ||
        TO_CHAR(v_media,'FM999G990D00')
    );
END;
/

-- Relatorio 7: Subtotais por clinica e categoria com total geral
DECLARE
    CURSOR c IS
        SELECT c.nm_clinica, te.ds_categoria,
               COUNT(es.id_evento) AS qt,  SUM(es.vl_custo) AS total,
               MIN(es.vl_custo)    AS menor, MAX(es.vl_custo) AS maior
          FROM TB_CLINICA c
          JOIN TB_VETERINARIO v    ON c.id_clinica      = v.id_clinica
          JOIN TB_EVENTO_SAUDE es  ON v.id_veterinario  = es.id_veterinario
          JOIN TB_TIPO_EVENTO te   ON es.id_tipo_evento = te.id_tipo_evento
         GROUP BY c.nm_clinica, te.ds_categoria
         ORDER BY c.nm_clinica, total DESC;
    v_ult   VARCHAR2(150) := '###';
    v_sub   NUMBER := 0;  v_geral NUMBER := 0;
    v_qsub  NUMBER := 0;  v_qtot  NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== RESUMO FINANCEIRO POR CLINICA ===');
    FOR r IN c LOOP
        IF r.nm_clinica <> v_ult THEN
            IF v_ult <> '###' THEN
                DBMS_OUTPUT.PUT_LINE('  Sub-Total: ' || v_qsub || ' eventos | R$ ' || TO_CHAR(v_sub,'FM999G990D00'));
                DBMS_OUTPUT.PUT_LINE(RPAD('-',55,'-'));
            END IF;
            DBMS_OUTPUT.PUT_LINE('CLINICA: ' || r.nm_clinica);
            DBMS_OUTPUT.PUT_LINE('  ' || RPAD('CATEGORIA',14) || LPAD('QT',4) || LPAD('TOTAL',12) || LPAD('MIN',9) || LPAD('MAX',9));
            v_sub := 0; v_qsub := 0; v_ult := r.nm_clinica;
        END IF;
        v_sub   := v_sub   + r.total;  v_qsub := v_qsub + r.qt;
        v_geral := v_geral + r.total;  v_qtot := v_qtot + r.qt;
        DBMS_OUTPUT.PUT_LINE(
            '  ' || RPAD(r.ds_categoria, 14) ||
            LPAD(r.qt, 4) ||
            LPAD(TO_CHAR(r.total, 'FM999G990D00'), 12) ||
            LPAD(TO_CHAR(r.menor, 'FM999G990D00'),  9) ||
            LPAD(TO_CHAR(r.maior, 'FM999G990D00'),  9)
        );
    END LOOP;
    IF v_ult <> '###' THEN
        DBMS_OUTPUT.PUT_LINE('  Sub-Total: ' || v_qsub || ' eventos | R$ ' || TO_CHAR(v_sub,'FM999G990D00'));
    END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD('=',55,'='));
    DBMS_OUTPUT.PUT_LINE('TOTAL GERAL: ' || v_qtot || ' eventos | R$ ' || TO_CHAR(v_geral,'FM999G990D00'));
END;
/