-- =====================================================================
--  KEEPUP - DDL PostgreSQL
--  Módulos: Projetos | Cursos | Painéis | Vagas
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS keepup;
SET search_path TO keepup;  -- (Flyway já usa este schema; mantido p/ rodar o script na mão também)

-- ---------------------------------------------------------------------
-- Função utilitária: mantém atualizado_em sempre correto
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_atualizado_em()
RETURNS trigger AS $$
BEGIN
    NEW.atualizado_em := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Editar só curso/painel/vaga não gera UPDATE em item; esta função atualiza
-- item.atualizado_em mesmo assim. Schema explícito: o app conecta com o
-- search_path padrão (public), e aqui o nome da tabela é resolvido na execução.
CREATE OR REPLACE FUNCTION fn_tocar_item()
RETURNS trigger AS $$
BEGIN
    UPDATE keepup.item SET atualizado_em = now() WHERE id = NEW.item_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- ITEM: base comum de todos os cards (o que aparece no grid)
-- ---------------------------------------------------------------------
CREATE TABLE item (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo           TEXT        NOT NULL
                   CHECK (tipo IN ('PROJETO', 'CURSO', 'PAINEL', 'VAGA')),
    nome           TEXT        NOT NULL,
    descricao      TEXT,
    link           TEXT,
    status         TEXT        NOT NULL DEFAULT 'NAO_INICIADO'
                   CHECK (status IN ('NAO_INICIADO', 'EM_ANDAMENTO', 'PAUSADO',
                                     'CONCLUIDO', 'CANCELADO')),
    data_inicio    DATE,
    prazo          DATE,
    data_conclusao DATE,
    arquivado      BOOLEAN     NOT NULL DEFAULT false,
    criado_em      TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_item_prazo CHECK (prazo IS NULL OR data_inicio IS NULL OR prazo >= data_inicio),
    CONSTRAINT ck_item_conclusao
        CHECK (data_conclusao IS NULL OR data_inicio IS NULL OR data_conclusao >= data_inicio)
);

CREATE INDEX ix_item_tipo_status ON item (tipo, status) WHERE NOT arquivado;
CREATE INDEX ix_item_prazo       ON item (prazo)        WHERE prazo IS NOT NULL AND NOT arquivado;

CREATE TRIGGER trg_item_atualizado_em
BEFORE UPDATE ON item
FOR EACH ROW EXECUTE FUNCTION fn_set_atualizado_em();

-- ---------------------------------------------------------------------
-- CHECKLIST: pontos/etapas (pensado p/ projetos, mas serve p/ qualquer tipo,
-- ex.: módulos de um curso)
-- ---------------------------------------------------------------------
CREATE TABLE checklist_item (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id      BIGINT      NOT NULL REFERENCES item (id) ON DELETE CASCADE,
    texto        TEXT        NOT NULL,
    concluido    BOOLEAN     NOT NULL DEFAULT false,
    ordem        INTEGER     NOT NULL DEFAULT 0,
    prazo        DATE,
    concluido_em TIMESTAMPTZ,
    criado_em    TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- marcado como concluído <=> tem data de conclusão
    CONSTRAINT ck_checklist_concluido_em CHECK (concluido = (concluido_em IS NOT NULL))
);

CREATE INDEX ix_checklist_item ON checklist_item (item_id, ordem);

-- ---------------------------------------------------------------------
-- CURSO: dados extras de cursos (1:1 com item)
-- Limitação aceita (vale p/ curso, painel e vaga): o banco não garante que
-- item.tipo combine com a tabela de extensão; quem garante é o service.
-- item.prazo = sua meta pessoal | limite da plataforma = data_limite_conclusao
-- OU duração (qtd + unidade) contada a partir de item.data_inicio
-- ---------------------------------------------------------------------
CREATE TABLE curso (
    item_id                BIGINT PRIMARY KEY REFERENCES item (id) ON DELETE CASCADE,
    plataforma             TEXT,                 -- Udemy, Alura, Coursera...
    instrutor              TEXT,
    carga_horaria_h        NUMERIC(6,1) CHECK (carga_horaria_h IS NULL OR carga_horaria_h > 0),
    preco                  NUMERIC(10,2) CHECK (preco IS NULL OR preco >= 0),
    data_limite_conclusao  DATE,                 -- ex.: fim do acesso / prazo do certificado
    duracao_limite_qtd     INTEGER CHECK (duracao_limite_qtd IS NULL OR duracao_limite_qtd > 0),
    duracao_limite_unidade TEXT    CHECK (duracao_limite_unidade IN ('DIAS', 'MESES', 'ANOS')),
    prioridade             TEXT NOT NULL DEFAULT 'MEDIA'
                           CHECK (prioridade IN ('BAIXA', 'MEDIA', 'ALTA')),
    modo                   TEXT CHECK (modo IN ('AO_VIVO', 'GRAVADO')),
    certificado_url        TEXT,
    -- quantidade e unidade andam juntas
    CONSTRAINT ck_curso_duracao_completa
        CHECK ((duracao_limite_qtd IS NULL) = (duracao_limite_unidade IS NULL)),
    -- limite é data OU duração, nunca os dois
    CONSTRAINT ck_curso_limite_data_ou_duracao
        CHECK (data_limite_conclusao IS NULL OR duracao_limite_qtd IS NULL)
);

-- ---------------------------------------------------------------------
-- PAINEL: painéis do trabalho (1:1 com item). Só registro/lembrete:
-- o app NÃO se conecta ao banco do painel.
-- item.id / item.nome / item.descricao cobrem ID, NOME e DESCRICAO.
-- ---------------------------------------------------------------------
CREATE TABLE painel (
    item_id                 BIGINT  PRIMARY KEY REFERENCES item (id) ON DELETE CASCADE,
    data_criacao            DATE,               -- quando o painel foi criado no trabalho
    frequencia_carga        TEXT,               -- ex.: diária, semanal, mensal
    tipo_carga              TEXT    NOT NULL
                            CHECK (tipo_carga IN ('INCREMENTAL', 'SUBSTITUICAO')),
    data_inicial_carga      DATE    NOT NULL,
    validado                BOOLEAN NOT NULL DEFAULT false,
    compartilhado           BOOLEAN NOT NULL DEFAULT false,
    pessoas_compartilhadas  TEXT,
    pentaho                 BOOLEAN NOT NULL DEFAULT false,
    historico               TEXT,               -- anotações livres (ex.: "jan/2027: excluí 2019")
    CONSTRAINT ck_painel_compartilhado
        CHECK (compartilhado OR pessoas_compartilhadas IS NULL)
);

-- ---------------------------------------------------------------------
-- VAGA: dados extras de vagas (1:1 com item). item.nome = cargo.
-- ---------------------------------------------------------------------
CREATE TABLE vaga (
    item_id           BIGINT PRIMARY KEY REFERENCES item (id) ON DELETE CASCADE,
    empresa           TEXT        NOT NULL,
    localidade        TEXT,
    modalidade        TEXT CHECK (modalidade IN ('PRESENCIAL', 'HIBRIDO', 'REMOTO')),
    regime            TEXT CHECK (regime IN ('CLT', 'PJ', 'ESTAGIO', 'TEMPORARIO', 'OUTRO')),
    senioridade       TEXT CHECK (senioridade IN ('ESTAGIO', 'JUNIOR', 'PLENO', 'SENIOR', 'ESPECIALISTA')),
    faixa_salarial    TEXT,
    etapa             TEXT        NOT NULL DEFAULT 'INTERESSE'
                      CHECK (etapa IN ('INTERESSE', 'APLICADA', 'TESTE', 'ENTREVISTA',
                                       'PROPOSTA', 'APROVADA', 'REPROVADA', 'DESISTI')),
    origem            TEXT        NOT NULL DEFAULT 'MANUAL'
                      CHECK (origem IN ('MANUAL', 'BOT')),
    fonte             TEXT,                -- LinkedIn, Gupy, indicação...
    url_origem        TEXT,
    data_publicacao   DATE,
    data_candidatura  DATE,
    contato           TEXT,                -- recrutador(a), e-mail
    CONSTRAINT uq_vaga_url_origem UNIQUE (url_origem)   -- evita duplicata vinda do bot
);

CREATE INDEX ix_vaga_etapa ON vaga (etapa);

-- Mudou a extensão -> atualiza item.atualizado_em (ver fn_tocar_item)
CREATE TRIGGER trg_curso_toca_item  AFTER UPDATE ON curso  FOR EACH ROW EXECUTE FUNCTION fn_tocar_item();
CREATE TRIGGER trg_painel_toca_item AFTER UPDATE ON painel FOR EACH ROW EXECUTE FUNCTION fn_tocar_item();
CREATE TRIGGER trg_vaga_toca_item   AFTER UPDATE ON vaga   FOR EACH ROW EXECUTE FUNCTION fn_tocar_item();

-- ---------------------------------------------------------------------
-- VIEWS de apoio
-- ---------------------------------------------------------------------

-- Visão geral: prazos dos próximos 30 dias + atrasados, de cards e de etapas do checklist
-- (para cursos, considera o que vencer primeiro: sua meta ou o limite da plataforma;
--  limite por duração conta a partir de item.data_inicio)
CREATE OR REPLACE VIEW vw_prazos_proximos AS
WITH prazos AS (
    -- prazo do card
    SELECT i.id, i.tipo, i.nome, i.status,
           LEAST(i.prazo, l.limite) AS prazo
    FROM item i
    LEFT JOIN curso c ON c.item_id = i.id
    CROSS JOIN LATERAL (
        SELECT COALESCE(
                   c.data_limite_conclusao,
                   (i.data_inicio + c.duracao_limite_qtd * CASE c.duracao_limite_unidade
                                                               WHEN 'DIAS'  THEN interval '1 day'
                                                               WHEN 'MESES' THEN interval '1 month'
                                                               WHEN 'ANOS'  THEN interval '1 year'
                                                           END)::date
               ) AS limite
    ) l
    WHERE NOT i.arquivado
      AND i.status NOT IN ('CONCLUIDO', 'CANCELADO')

    UNION ALL

    -- etapas do checklist ainda abertas (id = card dono da etapa)
    SELECT i.id, i.tipo, i.nome || ': ' || ck.texto, i.status,
           ck.prazo
    FROM checklist_item ck
    JOIN item i ON i.id = ck.item_id
    WHERE NOT ck.concluido
      AND ck.prazo IS NOT NULL
      AND NOT i.arquivado
      AND i.status NOT IN ('CONCLUIDO', 'CANCELADO')
)
SELECT id, tipo, nome, status, prazo,
       (prazo - CURRENT_DATE) AS dias_restantes,
       (prazo < CURRENT_DATE)  AS atrasado
FROM prazos
WHERE prazo <= CURRENT_DATE + 30
ORDER BY prazo;

-- Progresso do checklist por item (projetos, vagas, cursos...)
CREATE OR REPLACE VIEW vw_progresso_checklist AS
SELECT c.item_id,
       count(*)                                    AS total,
       count(*) FILTER (WHERE c.concluido)         AS concluidos,
       round(100.0 * count(*) FILTER (WHERE c.concluido) / count(*), 0) AS percentual
FROM checklist_item c
GROUP BY c.item_id;

-- Alerta de início de ano: em janeiro lista os painéis ativos
-- (CONCLUIDO = painel entregue e ainda com cargas, por isso entra; só CANCELADO sai)
-- com o ano em que a carga começa (pra você decidir se exclui o primeiro ano)
CREATE OR REPLACE VIEW vw_paineis_alerta_carga AS
SELECT i.id AS painel_id, i.nome, p.tipo_carga, p.data_inicial_carga,
       EXTRACT(YEAR FROM p.data_inicial_carga)::int AS primeiro_ano_carga
FROM painel p
JOIN item i ON i.id = p.item_id
WHERE NOT i.arquivado
  AND i.status <> 'CANCELADO'
  AND EXTRACT(MONTH FROM CURRENT_DATE) = 1
ORDER BY p.data_inicial_carga;
