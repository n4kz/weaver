test: compile
	vows t/*.js

compile:
	coffee --compile t/*.coffee

clean:
	rm t/*.js
