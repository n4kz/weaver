test: compile
	vows --tap -i t/*.js

compile:
	coffee --compile t/*.coffee

lint:
	jslint --white --node --plusplus --bitwise --nomen lib/*

clean:
	rm t/*.js
