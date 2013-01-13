test: compile
	vows --tap -i t/*.js

compile:
	coffee --lint --compile t/*.coffee

clean:
	rm t/*.js
