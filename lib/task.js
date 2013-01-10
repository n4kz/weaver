'use strict';

var fork    = require('child_process').fork,
	resolve = require('path').resolve,
	assert  = require('assert'),
	Watcher = require('./watcher'),
	tasks   = {},
	Anubseran;

/*
 * TODO: public methods to get info on running tasks
 */

/*
 * Task status codes
 * N - new
 * R - restart
 * E - error
 * D - done (clean exit)
 * W - work in progress
 * S - stopped
 */

/**
 * Task singleton (by name)
 * @class Task
 * @constructor
 */
function Task (name, options) {
	if (!Anubseran) {
		Anubseran = new require('./weaver')();
	}

	if (!tasks.hasOwnProperty(name)) {
		tasks[name] = this;

		options = options || {};

		/**
		 * Subtasks count
		 * @property count
		 * @type Number
		 */
		this.count = options.count || 0;

		/**
		 * Array with sub-process related data
		 * @property subtasks
		 * @private
		 * @type Array
		 */
		this.subtasks = [];

		/**
		 * Source to execute in subtask
		 * @property source
		 * @type String
		 */
		this.source = options.source;

		/**
		 * Working directory for subtasks
		 * @property cwd
		 * @type String
		 */
		this.cwd = options.cwd;

		/**
		 * Arguments for subtasks
		 * @property arguments
		 * @type Array
		 */
		this.arguments = options.arguments;

		/**
		 * Array with sub-process related data
		 * @property timeout
		 * @type Number
		 * @default 1000
		 */
		this.timeout = options.timeout || 1000;

		/**
		 * Restart subtask on dirty exit
		 * @property persistent
		 * @type Boolean
		 * @default false
		 */
		this.persistent = options.persistent || false;

		/**
		 * Environment variables for subtasks
		 * @property env
		 * @type Object
		 */
		this.env = options.env || {};

		/* Default environment variables for subtasks */
		this.env.HOME      = this.env.HOME      || process.env.HOME;
		this.env.PATH      = this.env.PATH      || process.env.PATH;
		this.env.NODE_PATH = this.env.NODE_PATH || process.env.NODE_PATH;

		/**
		 * Task name
		 * @property name
		 * @type String
		 */
		this.name = name;

		/**
		 * Watch callback
		 * @property handler
		 * @private
		 * @type Function
		 */
		this.handler = restartall.bind(this);

		/**
		 * Watched patterns
		 * @property watch
		 * @type Array
		 */
		this.watch = [];
	}

	if (!options) {
		return tasks[name];
	}

	return tasks[name].upgrade(options);
}

Task.prototype = {
	upgrade: upgrade,

	kill: function (signal, pid) {
		if (pid === undefined) {
			killall.call(this, signal);
		} else {
			kill.call(this, get.call(this, pid), signal);
		}

		return this;
	},

	restart: function (pid) {
		if (pid === undefined) {
			restartall.call(this);
		} else {
			restart.call(this, get.call(this, pid));
		}

		return this;
	},

	stop: function (pid) {
		if (pid === undefined) {
			stopall.call(this);
		} else {
			stop.call(this, get.call(this, pid));
		}

		return this;
	}
};

module.exports = Task;

function get (pid) {
	var tasks = this.subtasks,
		i, l;

	for (i = 0, l = tasks.length; i < l; i++) {
		if ((tasks[i] || {}).pid === pid) {
			return tasks[i];
		}
	}

	return null;
}

function kill (task, signal) {
	if ((task || {}).pid) {
		try {
			task.process.kill(signal);
		} catch (error) {
			/* TODO: Log kill failure */
		}
	}

	return this;
}

function stop (task) {
	if (task && task.pid) {
		task.process.kill('SIGINT');

		setTimeout(function () {
			if (task.pid) {
				task.process.kill('SIGTERM');
			}
		}, this.timeout);
	}
}

function restart (task) {
	if (task) {
		task.status = 'R';
		stop.call(this, task);
	}
}

function _all (fn, arg) {
	var tasks = this.subtasks,
		task, i, l;

	for (i = 0, l = tasks.length; i < l; i++) {
		fn.call(this, tasks[i], arg);
	}
}

function stopall () { _all.call(this, stop) }
function restartall () { _all.call(this, restart) }
function killall (signal) { _all.call(this, kill, signal) }

function spawn (id) {
	var args = this.arguments,
		subtask = {
			id     : id,
			args   : [],
			status : 'N',
			name   : this.name,
			time   : Date.now()
		},
		i, l;

	for (i = 0, l = args.length; i < l; i++) {
		if (Array.isArray(args[i])) {
			subtask.args.push(args[i][id]);
			continue;
		}

		subtask.args.push(args[i]);
	}

	subtask.process = fork(this.source, subtask.args, {
		cwd : resolve(this.cwd),
		env : this.env
	});

	subtask.pid    = subtask.process.pid;
	subtask.status = 'W';

	Anubseran.log('Task ' + subtask.pid + ' (' + subtask.name + ') spawned');

	subtask.process.once('exit', onExit.bind(this, subtask));

	this.subtasks[id] = subtask;
}

function upgrade (parameters) {
	var i, l, pid, subtask;

	parameters = parameters || {};

	/* Change restart parameter */
	if ('persistent' in parameters) {
		this.persistent = parameters.persistent;
	}

	/* Change count parameter */
	if ('count' in parameters) {
		this.count = parameters.count;
	}

	if (this.persistent) {
		/* Check source */
		if ('source' in parameters && parameters.source !== this.source) {
			this.source = parameters.source;
			this.stop();
		}

		/* Check arguments */
		if ('arguments' in parameters) {
			try {
				assert.deepEqual(parameters.arguments, this.arguments);
			} catch (error) {
				this.arguments = parameters.arguments;
				this.stop();
			}
		}
	}

	/* Check watches */
	if ('watch' in parameters) {
		try {
			assert.deepEqual(parameters.watch, this.watch);
		} catch (error) {
			this.watch = parameters.watch;
			Watcher.stop(this.handler);
			Watcher.start(this.cwd, this.watch, this.handler);
		}
	}

	/* Check count */
	for (i = 0, l = this.count; i < l; i++) {
		subtask = this.subtasks[i];
		if (!subtask || (subtask.status === 'R' && !subtask.pid)) {
			spawn.call(this, i);
		}
	}

	/* Kill redundant */
	i = this.subtasks.length;
	while (i-- > this.count) {
		stop.call(this, this.subtasks.pop());
	}

	return this;
}

function onExit (task, code, signal) {
	Anubseran.log('Task ' + task.pid + ' (' + task.name + ') exited with code ' + code);

	task.pid    = 0;
	task.code   = code;
	task.signal = signal;

	if (task.status !== 'R') {
		if (code) {
			task.status = 'E';
		} else if (signal) {
			task.status = 'S';
		} else {
			task.status = 'D';
		}
	}

	if ((this.persistent && task.status !== 'D') || task.status === 'R') {
		spawn.call(this, task.id);
	}
}
