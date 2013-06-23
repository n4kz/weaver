test: compile
	vows --tap -i t/*.js

compile:
	coffee --compile t/*.coffee

clean:
	rm t/*.js
