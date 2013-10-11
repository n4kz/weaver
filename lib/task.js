'use strict';

var fork    = require('child_process').spawn,
	resolve = require('path').resolve,
	assert  = require('assert'),
	tasks   = Object.create(null),
	Watcher = require('./watcher');

/*
 * Task status codes
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
function Task (weaver, name, options) {
	var key, env;

	if (!tasks[name]) {
		tasks[name] = this;

		options = options || {};

		this.weaver = weaver;

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
		 * Source file is executable
		 * @property executable
		 * @type Boolean
		 */
		this.executable = options.executable || false;

		/**
		 * Working directory for subtasks
		 * @property cwd
		 * @type String
		 */
		this.cwd = options.cwd || process.cwd();

		/**
		 * Arguments for subtasks
		 * @property arguments
		 * @type Array
		 */
		this.arguments = options.arguments;

		/**
		 * Timeout between SIGINT and SIGTERM for stop and restart
		 * @property timeout
		 * @type Number
		 * @default 1000
		 */
		this.timeout = options.timeout || 1000;

		/**
		 * Minimal runtime required for persistent task
		 * to be restarted after unclean exit
		 * @property runtime
		 * @type Number
		 * @default 1000
		 */
		this.runtime = options.runtime || 1000;

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
		env = this.env = options.env || {};

		/* Default environment variables for subtasks */
		if (!env.hasOwnProperty('HOME')) {
			env.HOME = true;
		}

		if (!env.hasOwnProperty('PATH')) {
			env.PATH = true;
		}

		/* NODE_PATH for node.js subtasks */
		if (!env.hasOwnProperty('NODE_PATH') && !this.executable) {
			env.NODE_PATH = true;
		}

		Object.keys(env).forEach(function (key) {
			/* Expand environment variables */
			switch (env[key]) {
				case true:
					env[key] = process.env[key];
					break;

				case false:
					delete env[key];
					break;
			}
		});

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
		this.handler = this.restartAll.bind(this);

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
	get: function (pid) {
		var tasks = this.subtasks,
			i, l;

		for (i = 0, l = tasks.length; i < l; i++) {
			if ((tasks[i] || {}).pid === pid) {
				return tasks[i];
			}
		}

		return null;
	},

	foreach: function (fn, arg) {
		var tasks = this.subtasks,
			task, i, l;

		for (i = 0, l = tasks.length; i < l; i++) {
			fn.call(this, tasks[i], arg);
		}
	},

	killTask: function (task, signal) {
		if ((task || {}).pid) {
			try {
				task.process.kill(signal);
			} catch (error) {
				this.weaver.log('Failed to kill ' + task.pid + ' (' + task.name + ') with ' + signal);
			}
		}

		return this;
	},

	stopTask: function (task) {
		if (task && task.pid) {
			task.process.kill('SIGINT');

			setTimeout(function () {
				if (task.pid) {
					task.process.kill('SIGTERM');
				}
			}, this.timeout);
		}
	},

	restartTask: function (task) {
		if (task) {
			task.status = 'R';
			this.stopTask(task);
		}
	},

	stopAll: function () {
		this.foreach(this.stopTask);
	},

	restartAll: function () {
		this.foreach(this.restartTask);
	},

	killAll: function (signal) {
		this.foreach(this.killTask, signal);
	},

	kill: function (signal, pid) {
		if (pid === undefined) {
			this.killAll(signal);
		} else {
			this.killTask(this.get(pid), signal);
		}

		return this;
	},

	restart: function (pid) {
		if (pid === undefined) {
			this.restartAll();
		} else {
			this.restartTask(this.get(pid));
		}

		return this;
	},

	stop: function (pid) {
		if (pid === undefined) {
			this.stopAll();
		} else {
			this.stopTask(this.get(pid));
		}

		return this;
	},

	upgrade: function (parameters) {
		var task = this,
			restart = false,
			i, l, pid, subtask, key;

		parameters = parameters || {};

		Object.keys(parameters).forEach(function (key) {
			switch (key) {
				/* No restart needed */
				case 'persistent':
				case 'timeout':
				case 'count':
				case 'runtime':
					task[key] = parameters[key];
					break;

				/* Restart required */
				case 'source':
				case 'executable':
				case 'arguments':
				case 'env':
				case 'cwd':
					try {
						assert.deepEqual(task[key], parameters[key]);
					} catch (change) {
						task[key] = parameters[key];
						restart = true;
					}
					break;
			}
		});

		/* Full restart needed */
		if (restart) {
			this.weaver.log('Restart required for ' + this.name + ' task group');
			this.restart();
		}

		/* Check watches */
		if (parameters.watch) {
			try {
				assert.deepEqual(parameters.watch, this.watch);
			} catch (change) {
				this.watch = parameters.watch;
				Watcher.stop(this.handler);
				Watcher.start(this.cwd, this.watch, this.handler);
			}
		}

		/* Check count */
		for (i = 0, l = this.count; i < l; i++) {
			subtask = this.subtasks[i];

			if (!subtask || (subtask.status === 'R' && !subtask.pid)) {
				this.spawn(i);
			}
		}

		/* Kill redundant */
		while (this.subtasks.length > this.count) {
			this.stopTask(this.subtasks.pop());
		}

		return this;
	},

	spawn: function (id) {
		var args    = this.arguments || [],
			binary  = process.execPath,
			subtask = {
				id     : id,
				args   : [],
				status : 'W',
				name   : this.name,
				time   : Date.now()
			}, i, l, p1, p2, eargs;

		for (i = 0, l = args.length; i < l; i++) {
			if (Array.isArray(args[i])) {
				subtask.args.push(args[i][id]);
			} else {
				subtask.args.push(args[i]);
			}
		}

		eargs = subtask.args.slice();

		if (this.executable) {
			binary = this.source;
		} else {
			eargs.unshift(this.source);
		}

		subtask.process = fork(binary, eargs, {
			stdio : 'pipe',
			cwd   : resolve(this.cwd),
			env   : this.env
		});

		subtask.pid = subtask.process.pid;

		subtask.process.stdout.on('data', this.log.bind(this, subtask.pid + ' (' + subtask.name + ') '));
		subtask.process.stderr.on('data', this.log.bind(this, subtask.pid + ' [' + subtask.name + '] '));

		subtask.process.once('exit', this.handler.bind(this, subtask));

		this.weaver.log('Task ' + subtask.pid + ' (' + subtask.name + ') spawned');

		this.subtasks[id] = subtask;
	},

	log: function (prefix, data) {
		var messages = data.toString().split('\n'),
			i, l;

		for (i = 0, l = messages.length; i < l; i++) {
			if (messages[i]) {
				this.weaver.log(prefix + messages[i]);
			}
		}
	},

	handler: function (subtask, code, signal) {
		var elapsed;

		if (code === null) {
			this.weaver.log('Task ' + subtask.pid + ' (' + subtask.name + ') was killed by ' + signal);
		} else {
			this.weaver.log('Task ' + subtask.pid + ' (' + subtask.name + ') exited with code ' + code);
		}

		subtask.pid    = 0;
		subtask.code   = code;
		subtask.signal = signal;

		delete subtask.process;

		if (subtask.status !== 'R') {
			if (code) {
				subtask.status = 'E';
			} else if (signal) {
				subtask.status = 'S';
			} else {
				subtask.status = 'D';
			}
		}

		if (this.persistent && code) {
			elapsed = Date.now() - subtask.time;

			if (elapsed < this.runtime) {
				this.weaver.log('Restart skipped after ' + elapsed + 'ms (' + subtask.name + ')');
				return;
			}
		}

		if (this.persistent || subtask.status === 'R') {
			this.spawn(subtask.id);
		}
	}
};

module.exports = Task;
