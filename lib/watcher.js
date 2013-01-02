'use strict';

var glob    = require('glob'),
	fs      = require('fs'),
	watches = {},
	watcher = {};

Watcher.prototype = new (require('events').EventEmitter)();

function Watcher () {
	this.start = start;
	this.stop  = stop;

	return this;
}

function watch (cwd, callback, error, files) {
	var cbs, file, i, l;

	if (error) {
		console.warn(error);
		return;
	}

	for (i = 0, l = files.length; i < l; i++) {
		file = files[i];

		if (file[0] !== '/') {
			/* Expand to full path */
			file = cwd + '/' + file;
		}

		cbs = watches[file];

		if (cbs) {
			/* Add callback to watches */
			cbs.push(callback);
		} else {
			/* Start watching file */
			watches[file] = [callback];
			watcher[file] = fs.watch(file, handler.bind(undefined, file));
		}
	}
}

function start (cwd, patterns, callback) {
	var fn = watch.bind(undefined, cwd, callback),
		i, l;

	for (i = 0, l = patterns.length; i < l; i++) {
		glob(patterns[i], {
			cwd     : cwd,
			nomount : true
		}, fn);
	}
}

function stop (callback) {
	var file, i, cbs;

	for (file in watches) {
		if (!watches.hasOwnProperty(file)) {
			continue;
		}

		cbs = watches[file];
		i = cbs.length;
		while (i--) {
			if (cbs[i] === callback) {
				cbs.splice(i, 1);
			}
		}

		if (!cbs.length) {
			/* Stop watching file completely */
			watcher[file].close();
			delete watches[file];
			delete watcher[file];
		}
	}
}

function handler (file, event) {
	var cbs = watches[file] || [],
		i, l;

	for (i = 0, l = cbs.length; i < l; i++) {
		cbs[i]();
	}
}

module.exports = new Watcher();
