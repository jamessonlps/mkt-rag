.PHONY: up down logs restart status ingest query test

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

restart:
	docker compose down && docker compose up -d

status:
	docker compose ps

ingest:
	python -m src.ingestion.pipeline

query:
	@read -p "Question: " q; \
	curl -s -X POST http://localhost:8000/query \
		-H "Content-Type: application/json" \
		-d "{\"question\": \"$$q\"}" | python -m json.tool

test:
	pytest tests/ -v
