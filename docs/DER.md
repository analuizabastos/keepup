# DER — KeepUp

Schema: `keepup` (PostgreSQL / Supabase)

`item` é a base de todos os cards. `curso`, `painel` e `vaga` são extensões 1:1
(a PK delas é o próprio `item_id`). Projeto não tem tabela própria: usa `item` + `checklist_item`.

> Limitação aceita: o banco não garante que `item.tipo` combine com a tabela de extensão
> (ex.: um `curso` apontando para um item `VAGA`). Quem garante é o service, que cria o item com o tipo certo.
>
> Editar só `curso`, `painel` ou `vaga` também atualiza `item.atualizado_em` (trigger `fn_tocar_item`).

```mermaid
erDiagram
    ITEM ||--o{ CHECKLIST_ITEM : "possui"
    ITEM ||--o| CURSO : "tipo = CURSO"
    ITEM ||--o| PAINEL : "tipo = PAINEL"
    ITEM ||--o| VAGA : "tipo = VAGA"

    ITEM {
        bigint id PK
        text tipo "PROJETO | CURSO | PAINEL | VAGA"
        text nome
        text descricao
        text link
        text status "NAO_INICIADO | EM_ANDAMENTO | PAUSADO | CONCLUIDO | CANCELADO"
        date data_inicio
        date prazo
        date data_conclusao
        boolean arquivado
        timestamptz criado_em
        timestamptz atualizado_em
    }

    CHECKLIST_ITEM {
        bigint id PK
        bigint item_id FK
        text texto
        boolean concluido
        integer ordem
        date prazo
        timestamptz concluido_em
        timestamptz criado_em
    }

    CURSO {
        bigint item_id PK,FK
        text plataforma
        text instrutor
        numeric carga_horaria_h
        numeric preco
        date data_limite_conclusao "OU duração abaixo"
        integer duracao_limite_qtd
        text duracao_limite_unidade "DIAS | MESES | ANOS"
        text prioridade "BAIXA | MEDIA | ALTA"
        text modo "AO_VIVO | GRAVADO"
        text certificado_url
    }

    PAINEL {
        bigint item_id PK,FK
        date data_criacao
        text frequencia_carga
        text tipo_carga "INCREMENTAL | SUBSTITUICAO"
        date data_inicial_carga
        boolean validado
        boolean compartilhado
        text pessoas_compartilhadas
        boolean pentaho
        text historico
    }

    VAGA {
        bigint item_id PK,FK
        text empresa
        text localidade
        text modalidade "PRESENCIAL | HIBRIDO | REMOTO"
        text regime "CLT | PJ | ESTAGIO | TEMPORARIO | OUTRO"
        text senioridade
        text faixa_salarial
        text etapa "INTERESSE ... APROVADA | REPROVADA | DESISTI"
        text origem "MANUAL | BOT"
        text fonte
        text url_origem UK
        date data_publicacao
        date data_candidatura
        text contato
    }
```

## Views

| View | Para quê |
|---|---|
| `vw_prazos_proximos` | Cards e etapas abertas do checklist com prazo nos próximos 30 dias ou atrasados (cursos: o que vencer primeiro entre meta e limite; limite por duração conta de `item.data_inicio`). Etapas aparecem como `card: etapa` |
| `vw_progresso_checklist` | Total / concluídos / % por item |
| `vw_paineis_alerta_carga` | Em janeiro, lista painéis não cancelados (inclui `CONCLUIDO`, que ainda tem cargas) com o primeiro ano de carga |
