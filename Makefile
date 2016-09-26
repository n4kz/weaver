export PATH := node_modules/.bin:$(PATH)

test: compile
	vows --spec -i t/*.js
	@echo

compile:
	coffee --bare --compile {lib,t}/*.coffee

clean:
	rm -f t/*.js
