# DER — Organizador

Schema: `organizador` (PostgreSQL / Supabase)

`item` é a base de todos os cards. `curso`, `painel` e `vaga` são extensões 1:1
(a PK delas é o próprio `item_id`). Projeto não tem tabela própria: usa `item` + `checklist_item`.

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
        date data_limite_conclusao
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
| `vw_prazos_proximos` | Itens com prazo nos próximos 30 dias ou atrasados (cursos: o que vencer primeiro entre meta e limite) |
| `vw_progresso_checklist` | Total / concluídos / % por item |
| `vw_paineis_alerta_carga` | Em janeiro, lista painéis ativos com o primeiro ano de carga |
