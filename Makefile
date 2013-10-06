test: compile
	vows --tap -i t/*.js

compile:
	coffee --compile t/*.coffee

lint:
	jslint lib/*

clean:
	rm t/*.js
