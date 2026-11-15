# KeepUp

Acompanhamento pessoal de projetos, cursos, painéis e vagas.
Spring Boot 3.5 · Java 17 · Thymeleaf · Bootstrap · PostgreSQL/Supabase · Flyway.

## Rodando no IntelliJ

1. **File → Open** e escolha a pasta `organizador` (o IntelliJ reconhece o `pom.xml` e baixa as dependências).
2. Abra a Run Configuration de `OrganizadorApplication` → **Environment variables** e preencha:

   **Postgres local**
   ```
   DB_URL=jdbc:postgresql://localhost:5432/keepup
   DB_USER=postgres
   DB_PASSWORD=sua_senha
   ```
   (crie o banco antes: `CREATE DATABASE keepup;`)

   Em vez de `DB_PASSWORD`, você pode pôr a senha em `src/main/resources/application-local.properties`
   (`spring.datasource.password=...`). Esse arquivo está no `.gitignore`.

   **Supabase** — painel do projeto → **Connect** → **Session pooler** (não use o Transaction pooler):
   ```
   DB_URL=jdbc:postgresql://<host-do-pooler>:5432/postgres?sslmode=require
   DB_USER=postgres.<id-do-projeto>
   DB_PASSWORD=sua_senha_do_banco
   ```
3. Rode `OrganizadorApplication` e acesse http://localhost:8080

Na primeira execução o Flyway cria o schema `keepup` com todas as tabelas e views.
Se você já rodou o DDL na mão, ele só marca como versão 1 e segue.

## Banco

- Migrations: `src/main/resources/db/migration`
- DER: `docs/DER.md` (o IntelliJ mostra o diagrama Mermaid no preview do Markdown)
- Mudou algo no banco? Crie `V2__o_que_mudou.sql`. Não edite o V1.

## Estado atual

| Módulo | Status |
|---|---|
| Visão geral (prazos + alerta de painéis em janeiro) | ✅ |
| Cursos | ✅ CRUD completo |
| Projetos, Painéis, Vagas | entidades e repositórios prontos; telas a fazer |
