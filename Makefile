.PHONY: psql
psql:
	docker-compose exec postgres psql -d postgres://tester:tester@localhost/test
