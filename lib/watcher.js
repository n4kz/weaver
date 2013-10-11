'use strict';

var glob  = require('glob'),
	fs      = require('fs'),
	util    = require('util'),
	events  = require('events'),
	watches = Object.create(null),
	watcher = Object.create(null);

function handler (file, event) {
	// FIXME: Weaver.log('File ' + file + ' changed');

	(watches[file] || []).forEach(function (callback) {
		callback();
	});
}

function watch (cwd, callback, error, files) {
	var cbs, file, i, l;

	if (error) {
		// FIXME: Weaver.emit('error', error);
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
	Object.keys(watches).forEach(function (file) {
		var cbs = watches[file],
			i   = cbs.length;

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
	});
}

function Watcher () {
	this.start = start;
	this.stop  = stop;

	return this;
}

util.inherits(Watcher, events.EventEmitter);

module.exports = new Watcher();
