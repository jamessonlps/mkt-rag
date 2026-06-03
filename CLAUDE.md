# CLAUDE.md — DataOps Knowledge Hub

This file is the **contract** between the developer and Claude Code. It defines how the agent must behave, what it knows about this project, and the rules it must follow when implementing changes.

---

## 1. Project Overview

The **DataOps Knowledge Hub** is a production-grade Enterprise RAG system that answers complex cross-domain questions by querying three different data stores through intelligent routing. It is not a toy single-PDF demo: it operates over structured, semi-structured, and unstructured data simultaneously, decomposes user questions into sub-queries, dispatches each to the appropriate engine, and returns validated structured output.

The architecture follows the **Ledger + Memory + Brain** cognitive model:

- **Ledger** → PostgreSQL — factual truth (numbers, transactions, metrics) via Text-to-SQL (`NLSQLTableQueryEngine`).
- **Memory** → Qdrant — historical context (documents, logs, policies) via semantic vector search (`VectorStoreIndex`).
- **Brain** → Neo4j — relationships, lineage, dependencies via graph traversal (`PropertyGraphIndex`).

A `SubQuestionQueryEngine` sits on top, routing sub-queries across domains.

**End goal:** a FastAPI service that exposes the RAG system as REST endpoints and as an MCP (Model Context Protocol) server, so it can be consumed by Claude Code and other agents in production.

---

## 2. Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Orchestration | LlamaIndex | `0.12+` |
| Contracts / Validation | Pydantic | `v2.x` |
| API | FastAPI | `0.115+` |
| Relational DB (Ledger) | PostgreSQL | `16` |
| Vector DB (Memory) | Qdrant | latest |
| Graph DB (Brain) | Neo4j | `5.x` |
| Object Storage (Data Lake) | SeaweedFS | latest |
| Local Infra | Docker Compose | latest |
| Production Deploy | Railway | — |
| Protocol | MCP (Model Context Protocol) | — |
| Language | Python | `3.11+` |

---

## 3. Architecture Rules

These rules are **non-negotiable**. Violating them breaks the contract.

1. **All LLM outputs MUST be validated through Pydantic models.** No raw text leaks past the engine boundary.
2. **Never return raw string responses from LLMs** to API consumers. Wrap everything in a typed `Response` model.
3. **Every query engine must return a typed response.** Use `pydantic_program` / structured output, not free-form text.
4. **Use `SubQuestionQueryEngine` (or `RouterQueryEngine`) for cross-domain queries.** Do not hand-roll routing logic.
5. **Use `IngestionPipeline`** for all data ingestion. Do not manually call `VectorStoreIndex.from_documents` in production paths.
6. **Use semantic chunking (`SemanticSplitterNodeParser`)** over fixed-size chunking. Retrieval quality > simplicity.
7. **All FastAPI endpoints MUST have explicit request and response Pydantic models.** No `dict` or `Any` in signatures.
8. **One engine per domain.** Ledger queries go through the SQL engine, Memory through the vector engine, Brain through the graph engine — never mix.

---

## 4. Code Standards

- **Python 3.11+** (use modern syntax: `match`, `|` unions, `Self`).
- **`async/await` throughout** — FastAPI handlers, LlamaIndex async APIs, DB drivers.
- **Type hints on every function**, including private helpers.
- **Docstrings on all public functions** (Google or NumPy style, consistent across the project).
- **Dependency management via `pyproject.toml`** — do NOT create `requirements.txt`.
- **`src/` layout** — importable package lives under `src/<package_name>/`.
- **Secrets via `.env`** loaded by `pydantic-settings`. Never hardcode API keys, DB URLs, or model names.
- **Logging via `structlog`** (or stdlib `logging` with JSON formatter). No bare `print()`.

---

## 5. Project Structure

The canonical layout (see `sketch/plan.md` for full rationale):

```
mkt-rag/
├── CLAUDE.md                   # this file
├── pyproject.toml
├── docker-compose.yml
├── .env.example
├── README.md
│
├── src/
│   └── knowledge_hub/
│       ├── __init__.py
│       ├── api/                # FastAPI app, routers, dependencies
│       │   ├── main.py
│       │   ├── routes/
│       │   └── schemas/        # Pydantic request/response models
│       ├── engines/            # LlamaIndex query engines
│       │   ├── ledger.py       # NLSQLTableQueryEngine (PostgreSQL)
│       │   ├── memory.py       # VectorStoreIndex (Qdrant)
│       │   ├── brain.py        # PropertyGraphIndex (Neo4j)
│       │   └── router.py       # SubQuestionQueryEngine
│       ├── ingestion/          # IngestionPipeline + readers
│       ├── models/             # Domain Pydantic models
│       ├── mcp/                # MCP server exposing tools
│       ├── settings.py         # pydantic-settings config
│       └── generators/         # Data Generator (Faker)
│
├── tests/                      # pytest + pytest-asyncio
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── infra/                      # init scripts for Postgres, Neo4j, Qdrant
├── prompts/                    # numbered task prompts (01, 02, …)
├── sketch/
│   └── plan.md
└── docs/                       # reference material (PDFs, notes)
```

---

## 6. Naming Conventions

- **Files / modules:** `snake_case.py`
- **Classes:** `PascalCase`
- **Functions / variables:** `snake_case`
- **Constants:** `UPPER_SNAKE_CASE`
- **Pydantic models:** descriptive names ending in `Request`, `Response`, `Config`, or the domain name (e.g. `QueryRequest`, `LedgerResponse`, `PipelineNode`, `QdrantConfig`).
- **API routes:** `/kebab-case` (e.g. `/cross-domain-query`, not `/crossDomainQuery`).
- **Docker services:** `kebab-case` (e.g. `knowledge-hub-api`, `qdrant`, `neo4j`).
- **Environment variables:** `UPPER_SNAKE_CASE` with a domain prefix (e.g. `POSTGRES_DSN`, `QDRANT_URL`, `LLM_MODEL`).

---

## 7. Testing

- **Framework:** `pytest` + `pytest-asyncio` for async tests.
- **Isolation:** test each engine (Ledger, Memory, Brain) independently before wiring them through the router.
- **Fixtures:** use `pytest` fixtures to seed test databases. In-memory vector stores (`SimpleVectorStore`) are allowed in tests **only** — never in production code.
- **End-to-end gate:** a cross-domain query (e.g. *"Which enterprise customers spent over R$50k, had pipeline incidents, and what downstream dashboards would be impacted?"*) MUST return a Pydantic-validated response that includes data sourced from all three stores.
- **Coverage target:** 80%+ on `src/knowledge_hub/engines/` and `src/knowledge_hub/models/`.

---

## 8. Key References

- **`sketch/plan.md`** — single source of truth for architecture, stack versions, data sources, build sequence, and design decisions. **Read this before any non-trivial change.**
- **`docs/`** — reference documentation (PDFs and markdown notes). Consult for domain context.
- **LlamaIndex docs** — https://docs.llamaindex.ai/ for API reference (`IngestionPipeline`, `SubQuestionQueryEngine`, `PropertyGraphIndex`, `NLSQLTableQueryEngine`).
- **Pydantic v2 docs** — https://docs.pydantic.dev/latest/ for structured output and validation patterns.

---

## 9. Workflow

Claude Code operates **one task at a time**, driven by numbered prompts in the `prompts/` folder.

1. **Read the next task** from `prompts/` (files are numbered sequentially, e.g. `01-create-claude-md.md`, `02-scaffold.md`, …).
2. **Execute that task only.** Do not anticipate or pre-implement future tasks.
3. **At the end of the task, summarize what was done** — list created/modified files and any decisions taken.
4. **Stop and wait for confirmation** before moving to the next prompt. Do NOT chain prompts autonomously.
5. If a task is ambiguous, ask before writing code. Don't guess.

---

## 10. Constraints

Hard "do not" list:

- **Do NOT use LangChain** — this project uses LlamaIndex exclusively. No mixing.
- **Do NOT use ChromaDB** — Qdrant is the only vector store.
- **Do NOT use in-memory vector stores in production code.** They are allowed only inside `tests/`.
- **Do NOT hardcode model names** — read them from environment variables via `pydantic-settings`.
- **Do NOT create a frontend or UI.** The deliverable is API + MCP only.
- **Do NOT add `requirements.txt`** — dependencies live in `pyproject.toml`.
- **Do NOT call LLMs synchronously** in request paths — always `await`.
- **Do NOT introduce new top-level dependencies** without updating `pyproject.toml` and noting the rationale in the task summary.
