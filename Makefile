test: compile
	vows --spec -i t/*.js
	@echo

compile:
	coffee --compile t/*.coffee

clean:
	rm t/*.js
