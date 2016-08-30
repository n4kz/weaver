test: compile
	node_modules/.bin/vows --spec -i t/*.js
	@echo

compile:
	node_modules/.bin/coffee --compile t/*.coffee

clean:
	rm -f t/*.js
