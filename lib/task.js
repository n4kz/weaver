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

		for (var field in options) {
			if (!options.hasOwnProperty(field)) {
				continue;
			}

			this[field] = options[field];
		}

		/**
		 * Array with sub-process related data
		 * @property subtasks
		 * @private
		 * @type Array
		 */
		this.subtasks = [];

		/**
		 * Array with sub-process related data
		 * @property timeout
		 * @type Number
		 * @default 1000
		 */
		this.timeout = this.timeout || 1000;

		/**
		 * Environment variables for subtasks
		 * @property env
		 * @type Object
		 */
		this.env = this.env || {};

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
	upgrade : upgrade,
	refresh : restartall,
	kill    : killall,
	slay    : slayall
};

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

function slay (task) {
	if (task && task.pid) {
		task.process.kill('SIGINT');

		setTimeout(function () {
			if (task.pid) {
				task.process.kill('SIGTERM');
			}
		}, this.timeout);
	}
}

function restart (task, full) {
	var tasks = this.subtasks,
		task, i, l;

	if (full || task.status !== 'D') {
		task.status = 'R';
		slay.call(this, task);
	}

	return this;
}

function _all (fn, arg) {
	var tasks = this.subtasks,
		task, i, l;

	for (i = 0, l = tasks.length; i < l; i++) {
		fn.call(this, tasks[i], arg);
	}

	return this;
}

function slayall () { return _all.call(this, slay) }
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
	var args = this.arguments || [],
		subtask = {
			id     : id,
			args   : [],
			status : 'N',
			time   : Date.now()
		},
		i, l;

	if (this.subtasks[id]) {
		return this;
	}

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
	var i, l, pid;

	parameters = parameters || {};

	/* Change restart parameter */
	if ('restart' in parameters) {
		this.restart = parameters.restart;
	}

	/* Change count parameter */
	if ('count' in parameters) {
		this.count = parameters.count;
	}

	if (this.restart) {
		/* Check source */
		if ('source' in parameters && parameters.source !== this.source) {
			this.source = parameters.source;
			this.slay();
		}

		/* Check options */
		if ('options' in parameters) {
			try {
				assert.deepEqual(parameters.options, this.options);
			} catch (error) {
				this.options = parameters.options;
				this.slay();
			}
		}
	}

	/* Check count */
	for (i = 0, l = this.count; i < l; i++) {
		if (!this.subtasks[i]) {
			spawn.call(this, i);
		}
	}

	/* Kill redundant */
	for (i = this.count, l = this.subtasks.length; i < l; i++) {
		if (this.subtasks[i]) {
			slay.call(this, this.subtasks[i]);
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

	if (this.restart && !task.status.match(/[DS]/) || task.status === 'R') {
		this.subtasks[task.id] = null;

		spawn.call(this, task.id);
	}
}

module.exports = Task;
