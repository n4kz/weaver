'use strict';

var fork    = require('child_process').fork,
	resolve = require('path').resolve,
	tasks   = {};

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
		this.env = this.env || {};

		/* Default environment variables for subtasks */
		this.env.HOME      = process.env.HOME;
		this.env.PATH      = process.env.PATH;
		this.env.NODE_PATH = process.env.NODE_PATH,

		/**
		 * Task name
		 * @property name
		 * @type String
		 */
		this.name = name;
	}

	if (!options) {
		return tasks[name];
	}

	return tasks[name].upgrade(options);
}

Task.prototype = {
	upgrade: upgrade,

	restart: function (pid) {
		if (pid) {
			restart.call(this, get.call(this, pid));
		} else {
			restartall.call(this);
		}
	},

	stop: function (pid) {
		if (pid) {
			stop.call(this, get.call(this, pid));
		} else {
			stopall.call(this);
		}
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

function killpid (pid, signal) {
	var task = get.call(this, pid);

	if (task) {
		task.process.kill(signal);
	}

	return this;
}

function kill (task, signal) {
	if ((task || {}).pid) {
		task.process.kill(signal);
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

		return true;
	}

	return false;
}

function restart (task, full) {
	var tasks = this.subtasks,
		task, i, l;

	if (full || task.status !== 'D') {
		task.status = 'R';
		return stop.call(this, task);
	}

	return false;
}

function _all (fn, arg) {
	var tasks = this.subtasks,
		task, i, l;

	for (i = 0, l = tasks.length; i < l; i++) {
		fn.call(this, tasks[i], arg);
	}

	return this;
}

function stopall () { return _all.call(this, stop) }
function restartall () { return _all.call(this, restart) }
function killall (signal) { return _all.call(this, kill, signal) }

function clean () {
	var tasks = this.subtasks,
		i, l;

	for (i = 0, l = tasks.length; i < l; i++) {
		if ((tasks[i] || {}).pid === 0) {
			tasks[i] = null;
		}
	}

	return this;
}

function spawn (id) {
	var args = this.arguments,
		subtask = {
			id     : id,
			args   : [],
			status : 'N',
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
		cwd : resolve(this.cwd || process.cwd()),
		env : this.env
	});

	subtask.pid    = subtask.process.pid;
	subtask.status = 'W';

	subtask.process.once('exit', onExit.bind(this, subtask));

	this.subtasks[id] = subtask;

	return this;
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

	/* Check count */
	for (i = 0, l = this.count; i < l; i++) {
		subtask = this.subtasks[i];
		if (!subtask || subtask.status === 'R') {
			spawn.call(this, i);
		}
	}

	/* Kill redundant */
	for (i = this.count, l = this.subtasks.length; i < l; i++) {
		if (this.subtasks[i]) {
			stop.call(this, this.subtasks[i]);
		}
	}

	return this;
}

function onExit (task, code, signal) {
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
		this.subtasks[task.id] = null;

		spawn.call(this, task.id);
	}
}
