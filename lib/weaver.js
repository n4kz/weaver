'use strict';

var fs      = require('fs'),
	util    = require('util'),
	events  = require('events'),
	assert  = require('assert'),
	resolve = require('path').resolve,
	fork    = require('child_process').spawn,
	zs      = require('z-schema'),
	schema  = require('./schema'),
	Watcher = require('./watcher'),
	sprintf = require('sprintf').sprintf,

	/* Which subtask parameters can be changed without restart */
	mutable = {
		count      : true,
		source     : false,
		cwd        : false,
		env        : false,
		persistent : true,
		executable : false,
		timeout    : true,
		runtime    : true,
		watch      : true,
		arguments  : false
	};

var validator = new zs({ strictMode : true });

/**
 * Weaver
 * @class Weaver
 * @constructor
 */
function Weaver () {}

util.inherits(Weaver, events.EventEmitter);

var weaver
	= module.exports
	= new Weaver();

function define (type, name, value, descriptor) {
	descriptor = descriptor || {};
	descriptor.value = value;
	descriptor.enumerable = true;

	var target = descriptor.target || weaver;

	if (!('writable' in descriptor)) {
		descriptor.writable = true;
	}

	switch (type) {
		case 'handler':
			target.on(name, value);
			return;

		case 'method':
			if (typeof value !== 'function') {
				throw new Error('Method must be a function');
			}

			descriptor.enumerable = false;
			break;

		case 'property':
			break;

		default:
			throw new Error('Unsupported definition type ' + type);
	}

	Object.defineProperty(target, name, descriptor);
}

/**
 * Weaver version
 * @property version
 * @type String
 */
define('property', 'version', require('../package').version, { writable: false });

/**
 * Start timestamp
 * @property start
 * @type Number
 */
define('property', 'start', Date.now(), { writable: false });

/**
 * Tasks by name
 * @property tasks
 * @type Object
 */
define('property', 'tasks', Object.create(null), { writable: false });

/**
 * Parsed configuration file
 * @property parameters
 * @type Object
 */
define('property', 'parameters', {});

/**
 * Extend Weaver with property or method
 * @method define
 */
define('method', 'define', define);

/**
 * Update or create new task group with given options
 * @method task
 * @param {String} name
 * @param {Object} options
 * @chainable
 */
define('method', 'task', Task);

/**
 * Write something to log
 * @method log
 */
define('method', 'log', function () {});

/**
 * Validate configuration object
 * @method validate
 * @param {Object} config
 */
define('method', 'validate', function (config) {
	var tasks = config.tasks;

	/* Validate schema */
	assert.ok(validator.validate(config, schema), 'Invalid configuration');

	/* Perform additional validation */
	Object.keys(tasks).forEach(function (name) {
		var task = tasks[name];

		/* Validate nested arrays for arguments */
		Object.keys(task).forEach(function (key) {
			if (key === 'arguments') {
				task[key].forEach(function (argument) {
					if (Array.isArray(argument)) {
						assert.equal(
							task.count, argument.length,
							'Nested array in arguments should contain ' + task.count + ' values'
						);
					}
				});
			}
		});

		task.name = name;
	});

	return config;
});

/**
 * Send SIGTERM to all processes and exit
 * @method die
 * @param {Number} code Exit code
 * @chainable
 */
define('method', 'die', function (code) {
	var that    = this,
		tasks   = this.tasks,
		timeout = 100,
		name;

	for (name in tasks) {
		if (tasks[name].timeout > timeout) {
			timeout = tasks[name].timeout;
		}

		tasks[name].persistent = false;
		tasks[name].stopSubtasks();
	}

	setTimeout(function () {
		code = null == code? 1 : code;
		that.log(sprintf('Terminated with code %u', code));

		setTimeout(function () {
			process.exit(code);
		}, 100);
	}, timeout);

	return this;
});

/**
 * Upgrade current state
 * @method upgrade
 * @param {String} data Configuration data
 * @param {String} path Configuration path
 * @chainable
 */
define('method', 'upgrade', function (data, path) {
	var parts = [path],
		params;

	try {
		/* Try to parse JSON */
		data = JSON.parse(data);

		/* Validate new state */
		params = this.validate(data);
	} catch (error) {
		error.message = 'Config error: ' + error.message;
		this.emit('error', error);
	}

	if (params) {
		if (params.path) {
			parts.push(params.path);
		}

		Object.keys(params.tasks)
			.map(function (name) {
				return params.tasks[name];
			}).forEach(function (task) {
				task.cwd = resolve.apply(undefined, parts.concat(task.cwd || '.'));
			});


		this.parameters = params;
		this.emit('upgrade');
	}

	return this;
});

/**
 * Get status report
 * @method status
 * @return {Object} Task groups with subtasks data
 */
define('method', 'status', function () {
	var tasks  = this.tasks,
		now    = Date.now(),
		result = {},
		i, l, name, task, subtask, subtasks;

	for (name in tasks) {
		result[name] = task = {
			count    : tasks[name].count,
			source   : tasks[name].source,
			restart  : tasks[name].restart,
			subtasks : []
		};

		subtasks = tasks[name].subtasks;

		for (i = 0, l = subtasks.length; i < l; i++) {
			subtask = subtasks[i];
			task.subtasks.push(subtask? {
				pid    : subtask.pid,
				args   : subtask.args,
				status : subtask.status,
				uptime : now - subtask.start
			} : null);
		}
	}

	return result;
});

/**
 * Execute command with given arguments
 * @method command
 * @param {String} action Action name
 * @param {String|Number} name Task group name or subtask pid
 * @param {Array} args Arguments
 * @chainable
 */
define('method', 'command', function (action, name, args) {
	var tasks = this.tasks,
		fn    = Task.prototype[action + 'PID'],
		task;

	if (!Array.isArray(args)) {
		args = [];
	}

	if (typeof fn !== 'function') {
		throw new Error('Unknown action ' + action);
	}

	/* Execute command for all tasks */
	if (null == name) {
		for (name in tasks) {
			fn.apply(tasks[name], args);
		}
	} else {
		task = tasks[name];

		if (task) {
			if (action === 'kill') {
				args.unshift(null);
			}

			fn.apply(task, args);
		} else if (Number(name) == name) {
			args.unshift(Number(name));

			this.command(action, null, args);
		} else {
			this.log('Task ' + name + ' was not found');
		}
	}

	return this;
});

/**
 * Fired when error occured
 * @event error
 * @param {Error} error Object with error details
 */
define('handler', 'error', function (error) {
	this.log(error.message);
});

/**
 * Fired when tasks should be checked and upgraded
 * @event upgrade
 */
define('handler', 'upgrade', function () {
	var tasks = this.parameters.tasks,
		name;

	for (name in tasks) {
		if (tasks.hasOwnProperty(name)) {
			/* Create or update task */
			this.task(name, tasks[name]);
		}
	}
});

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
function Task (name, options) {
	var env, task;

	if (!(this instanceof Task)) {
		return new Task(name, options);
	}

	task = weaver.tasks[name];

	if (task) {
		task.upgrade(options);
		return task;
	}

	task = weaver.tasks[name] = this;

	/**
	 * Task name
	 * @property name
	 * @type String
	 */
	define('property', 'name', name, {
		writable : false,
		target   : this
	});

	/**
	 * Array with sub-process related data
	 * @property subtasks
	 * @type Array
	 */
	define('property', 'subtasks', [], {
		writable : false,
		target   : this
	});

	/**
	 * Watched patterns
	 * @property watch
	 * @type Array
	 */
	define('property', 'watch', [], { target: this });

	/**
	 * Watch callback
	 * @method watchHandler
	 */
	define('method', 'watchHandler', this.restartSubtasks.bind(this), { target: this });

	if (options) {
		this.upgrade(options);
	}

	return this;
}

/**
 * Timeout between SIGINT and SIGTERM for stop and restart
 * @property timeout
 * @type Number
 * @default 1000
 */
define('property', 'timeout', 1000, { target: Task.prototype });

/**
 * Minimal runtime required for persistent task
 * to be restarted after unclean exit
 * @property runtime
 * @type Number
 * @default 1000
 */
define('property', 'runtime', 1000, { target: Task.prototype });

/**
 * Subtasks count
 * @property count
 * @type Number
 * @default 0
 */
define('property', 'count', 0, { target: Task.prototype });

/**
 * Source to execute in subtask
 * @property source
 * @type String
 */
define('property', 'source', '', { target: Task.prototype });

/**
 * Source file is executable
 * @property executable
 * @type Boolean
 * @default false
 */
define('property', 'executable', false, { target: Task.prototype });

/**
 * Working directory for subtasks
 * @property cwd
 * @type String
 */
define('property', 'cwd', process.cwd(), { target: Task.prototype });

/**
 * Arguments for subtasks
 * @property arguments
 * @type Array
 */
define('property', 'arguments', [], { target: Task.prototype });

/**
 * Restart subtask on dirty exit
 * @property persistent
 * @type Boolean
 * @default false
 */
define('property', 'persistent', false, { target: Task.prototype });

/**
 * Environment variables for subtasks
 * @property env
 * @type Object
 */
define('property', 'env', {}, { target: Task.prototype });

/**
 * Upgrade task group
 * @method upgrade
 * @param {Object} parameters
 * @chainable
 */
define('method', 'upgrade', function (parameters) {
	var restart = false,
		i, l, pid, subtask, key;

	/* Change parameters */
	if (parameters) {
		for (key in mutable) {
			try {
				if (this.hasOwnProperty(key) || key in parameters) {
					assert.deepEqual(this[key], parameters[key]);
				}
			} catch (change) {
				this.upgradeParameter(key, parameters);

				if (!mutable[key]) {
					restart = true;
				}
			}
		}
	}

	/* Restart on demand */
	if (restart && this.subtasks.length) {
		weaver.log(sprintf('Restart required for %s task group', this.name));
		this.restartSubtasks();
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
		this.stopSubtask(this.subtasks.pop());
	}
}, { target: Task.prototype });

/**
 * Upgrade task parameter with value from parameters object
 * @method upgradeParameter
 * @param {String} key
 * @param {Object} parameters
 */
define('method', 'upgradeParameter', function (key, parameters) {
	switch (key) {
		case 'watch':
			this.watch = parameters.watch || [];
			Watcher.stop(this.watchHandler);
			Watcher.start(weaver, this.cwd, this.watch, this.watchHandler);
			break;

		default:
			if (key in parameters) {
				this[key] = parameters[key];
			} else {
				delete this[key];
			}
	}
}, { target: Task.prototype });

/**
 * Expand variables in this.env
 * @method expandEnv
 * @return {Object} Object with expanded env variables
 */
define('method', 'expandEnv', function () {
	var env = {
			HOME: process.env.HOME,
			PATH: process.env.PATH
		}, key;

	if (!this.executable) {
		env.NODE_PATH = process.env.NODE_PATH;
	}

	for (key in this.env) {
		switch (this.env[key]) {
			case true:
				env[key] = process.env[key];
				break;

			case false:
				delete env[key];
				break;

			default:
				env[key] = this.env[key];
		}
	}

	return env;
}, { target: Task.prototype });

/**
 * Get subtask by pid
 * @method get
 * @param {Number} pid
 */
define('method', 'get', function (pid) {
	var subtasks = this.subtasks,
		subtask, i, l;

	for (i = 0, l = subtasks.length; i < l; i++) {
		subtask = subtasks[i];

		if (subtask && subtask.pid === pid) {
			return subtask;
		}
	}
}, { target: Task.prototype });

/**
 * Spawn subtask with given id
 * @method spawn
 * @param {Number} id
 */
define('method', 'spawn', function (id) {
	var args    = this.arguments || [],
		binary  = process.execPath,
		subtask = {
			id     : id,
			args   : [],
			status : 'W',
			name   : this.name,
			start  : Date.now(),
			env    : this.expandEnv()
		}, i, l, p1, p2, eargs;

	/* Prepare arguments */
	for (i = 0, l = args.length; i < l; i++) {
		if (Array.isArray(args[i])) {
			subtask.args.push(args[i][id]);
		} else {
			subtask.args.push(args[i]);
		}
	}

	eargs = subtask.args.slice();

	/* Prepare binary/source */
	if (this.executable) {
		binary = this.source;
	} else {
		eargs.unshift(this.source);
	}

	/* Create new process */
	subtask.process = fork(binary, eargs, {
		stdio : 'pipe',
		cwd   : resolve(this.cwd),
		env   : subtask.env
	});

	/* Get subtask pid */
	subtask.pid = subtask.process.pid || 0;

	if (subtask.pid) {
		p1 = sprintf('%u (%s) ', subtask.pid, subtask.name);
		p2 = sprintf('%u [%s] ', subtask.pid, subtask.name);

		/* Setup logger */
		subtask.process.stdout.on('data', this.log.bind(this, p1));
		subtask.process.stderr.on('data', this.log.bind(this, p2));

		/* Setup exit handler */
		subtask.process.once('exit', this.exitHandler.bind(this, subtask));

		weaver.log(sprintf('Task %u (%s) spawned', subtask.pid, subtask.name));
	} else {
		subtask.status = 'E';
		subtask.code   = 255;

		subtask.process.once('error', function (error) {
			weaver.emit('error', error);
		});

		weaver.log(sprintf('Failed to start task (%s)', subtask.name));
	}

	this.subtasks[id] = subtask;
}, { target: Task.prototype });

/**
 * Do something for each subtask
 * @method foreach
 * @param {Function} fn
 * @param {Number|String} argument
 */
define('method', 'foreach', function (fn, argument) {
	var subtasks = this.subtasks,
		i, l;

	for (i = 0, l = subtasks.length; i < l; i++) {
		fn.call(this, subtasks[i], argument);
	}
}, { target: Task.prototype });

/**
 * Kill given subtask with signal
 * @method killSubtask
 * @param {Object} subtask
 * @param {String} signal
 */
define('method', 'killSubtask', function (subtask, signal) {
	if (subtask && subtask.pid) {
		try {
			subtask.process.kill(signal);
		} catch (error) {
			weaver.log(sprintf(
				'Failed to kill %u (%s) with %s',
				subtask.pid, subtask.name, signal
			));
		}
	}
}, { target: Task.prototype });

/**
 * Stop given subtask
 * @method stopSubtask
 * @param {Object} subtask
 */
define('method', 'stopSubtask', function (subtask) {
	if (subtask && subtask.pid) {
		subtask.process.kill('SIGINT');

		setTimeout(function () {
			if (subtask.pid) {
				subtask.process.kill('SIGTERM');
			}
		}, this.timeout);
	}
}, { target: Task.prototype });

/**
 * Restart given subtask
 * @method restartSubtask
 * @param {Object} subtask
 */
define('method', 'restartSubtask', function (subtask) {
	if (subtask) {
		subtask.status = 'R';
		this.stopSubtask(subtask);
	}
}, { target: Task.prototype });

/**
 * Kill subtask with signal by PID
 * @method killPID
 * @param {Number} pid
 * @param {String} signal
 */
define('method', 'killPID', function (pid, signal) {
	if (null == pid) {
		this.killSubtasks(signal);
	} else {
		this.killSubtask(this.get(pid), signal);
	}
}, { target: Task.prototype });

/**
 * Restart subtask by pid
 * @method restartPID
 * @param {Number} pid
 */
define('method', 'restartPID', function (pid) {
	if (null == pid) {
		this.restartSubtasks();
	} else {
		this.restartSubtask(this.get(pid));
	}
}, { target: Task.prototype });

/**
 * Stop subtask by pid
 * @method restartPID
 * @param {Number} pid
 */
define('method', 'stopPID', function (pid) {
	if (null == pid) {
		this.stopSubtasks();
	} else {
		this.stopSubtask(this.get(pid));
	}
}, { target: Task.prototype });

/**
 * Stop all subtasks
 * @method stopSubtasks
 */
define('method', 'stopSubtasks', function () {
	this.foreach(this.stopSubtask);
}, { target: Task.prototype });

/**
 * Restart all subtasks
 * @method restartSubtasks
 */
define('method', 'restartSubtasks', function () {
	this.foreach(this.restartSubtask);
}, { target: Task.prototype });

/**
 * Kill all subtasks with signal
 * @method killSubtasks
 * @param {String} signal
 */
define('method', 'killSubtasks', function (signal) {
	this.foreach(this.killSubtask, signal);
}, { target: Task.prototype });

/**
 * Output data from buffer to weaver.log
 * @method log
 * @param {String} prefix
 * @param {Buffer} data
 */
define('method', 'log', function (prefix, data) {
	var messages = data.toString().split('\n'),
		i, l;

	for (i = 0, l = messages.length; i < l; i++) {
		if (messages[i]) {
			weaver.log.call(null, prefix + messages[i]);
		}
	}
}, { target: Task.prototype });

/**
 * @method exitHandler
 * @param {Object} subtask
 * @param {Number} code
 * @param {String} signal
 */
define('method', 'exitHandler', function (subtask, code, signal) {
	var restart = this.persistent,
		elapsed;

	if (code === null) {
		weaver.log(sprintf(
			'Task %u (%s) was killed by %s',
			subtask.pid, subtask.name, signal
		));
	} else {
		weaver.log(sprintf(
			'Task %u (%s) exited with code %u',
			subtask.pid, subtask.name, code
		));
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

	if (restart && code) {
		elapsed = Date.now() - subtask.start;

		if (elapsed < this.runtime) {
			weaver.log(sprintf(
				'Restart skipped after %ums (%s)',
				elapsed, subtask.name
			));

			restart = false;
		}
	}

	if (subtask.status === 'R') {
		/* Restart was requested */
		restart = true;
	}

	if (!weaver.parameters.tasks.hasOwnProperty(this.name)) {
		/* Task was dropped */
		restart = false;

		if (!this.subtasks.filter(function (subtask) { return !!subtask.pid }).length) {
			/* All subtasks were stopped */
			delete weaver.tasks[this.name];
		}
	}

	if (restart) {
		this.spawn(subtask.id);
	}
}, { target: Task.prototype });
