'use strict';

require('coffee-script/register');

var util    = require('util'),
	events  = require('events'),
	assert  = require('assert'),
	resolve = require('path').resolve,
	zs      = require('z-schema'),
	schema  = require('./schema'),
	Task    = require('./task'),
	sprintf = require('sprintf').sprintf;

var validator = new zs({ strictMode : true });

/**
 * Weaver
 * @class Weaver
 * @constructor
 */
function Weaver () {
	return this;
}

util.inherits(Weaver, events.EventEmitter);

function define (type, name, value, descriptor) {
	descriptor = descriptor || {};
	descriptor.value = value;
	descriptor.enumerable = true;

	var target = descriptor.target || Weaver.prototype;

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
 * Parsed configuration file
 * @property config
 * @type Object
 */
define('property', 'config', Object.create(null), { writable: false });

/**
 * Extend Weaver with property or method
 * @method define
 */
define('method', 'define', define);

/**
 * Write something to log
 * @method log
 */
define('method', 'log', function () {});

/**
 * Validate configuration object
 * @method validate
 * @param  {Object} configuration
 * @return {Object} Valid configuration
 */
define('method', 'validate', function (configuration) {
	var tasks = configuration.tasks;

	/* Validate schema */
	assert.ok(validator.validate(configuration, schema), 'Invalid configuration');

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

	return configuration;
});

/**
 * Send SIGTERM to all processes and exit
 * @method die
 * @param {Number} code Exit code
 */
define('method', 'die', function (code) {
	var that    = this,
		tasks   = Task.tasks,
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
});

/**
 * Upgrade current state
 * @method upgrade
 * @param {String} data Configuration data
 * @param {String} path Configuration path
 */
define('method', 'upgrade', function (data, path) {
	var config = this.config,
		parts  = [path],
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

		Object.keys(params.tasks)
			.forEach(function (name) {
				config[name] = params.tasks[name];
			});

		this.emit('upgrade');
	}
});

/**
 * Get status report
 * @method status
 * @return {Object} Task groups with subtasks data
 */
define('method', 'status', function () {
	return Task.status();
});

/**
 * Execute command with given arguments
 * @method command
 * @param {String} action Action name
 * @param {String|Number} name Task group name or subtask pid
 * @param {Array} args Arguments
 */
define('method', 'command', function (action, name, args) {
	var tasks = Task.tasks,
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
	var config = this.config,
		tasks  = Task.tasks,
		name, task;

	/* Spot dropped tasks */
	for (name in tasks) {
		if (name in config) {
			continue;
		}

		tasks[name].dropSubtasks();
	}

	/* Create or update tasks */
	for (name in config) {
		task = Task.create(name);

		/* Setup logger */
		if (!task.log) {
			task.log = this.log.bind(this);
		}

		/* Setup error handler */
		if (!task.listenerCount('error')) {
			task.on('error', this.emit.bind(this, 'error'));
		}

		task.upgrade(config[name]);
	}
});

module.exports = new Weaver();
