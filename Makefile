test: compile
	vows -i t/*.js
	@echo

compile:
	coffee --compile t/*.coffee

clean:
	rm t/*.js
