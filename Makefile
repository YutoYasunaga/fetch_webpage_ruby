fetch:
	docker run -it -v "$(shell pwd)":/app fetch_page ruby fetch.rb $(filter-out $@,$(MAKECMDGOALS))

%:
	@:
