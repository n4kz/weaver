'use strict';

var fs      = require('fs'),
	assert  = require('assert'),
	util    = require('util'),
	events  = require('events'),
	dirname = require('path').dirname,
	resolve = require('path').resolve,
	Task    = require('./task'),

	/* Task options format */
	format = {
		count      : 'number',
		source     : 'string',
		cwd        : 'string',
		env        : 'object',
		persistent : 'boolean',
		executable : 'boolean',
		timeout    : 'number',
		runtime    : 'number',
		watch      : 'array',
		arguments  : 'array'
	},

	/* Which task parameters are optional */
	optional = {
		count      : false,
		source     : false,
		cwd        : true,
		env        : true,
		persistent : true,
		executable : true,
		timeout    : true,
		runtime    : true,
		watch      : true,
		arguments  : true
	};

/**
 * Weaver
 * @class Weaver
 * @constructor
 */
function Weaver () {
	if (!(this instanceof Weaver)) {
		return new Weaver();
	}

	return this;
}

util.inherits(Weaver, events.EventEmitter);

var weaver
	= module.exports
	= new Weaver();

function define (type, name, value, descriptor) {
	var target = weaver;

	descriptor = descriptor || {};
	descriptor.value = value;
	descriptor.enumerable = true;

	if (!descriptor.hasOwnProperty('writable')) {
		descriptor.writable = true;
	}

	switch (type) {
		case 'handler':
			target.on(name, value);
			return target;

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
	return target;
}

function validate (config) {
	var tasks = config.tasks,
		task, i, l;

	/* No tasks defined */
	assert.equal(typeof tasks, 'object', 'Tasks object required');
	assert.ok(Object.keys(tasks).length, 'At least one task required');

	if (config.hasOwnProperty('path')) {
		assert.equal(typeof config.path, 'string', 'Path should be a string');
	}

	Object.keys(tasks).forEach(function (name) {
		task = tasks[name];

		assert.equal(typeof task, 'object', 'Task is not an object');

		/* Check presence for mandatory arguments */
		Object.keys(optional).forEach(function (key) {
			if (!optional[key]) {
				assert.ok(task.hasOwnProperty(key), 'Option ' + key + ' required');
			}
		});

		Object.keys(task).forEach(function (key) {
			var value = task[key],
				type  = format[key];

			assert.ok(type, 'Unknown option ' + key);

			if (!(type === 'array' && Array.isArray(value))) {
				assert.equal(typeof value, format[key], 'Expected ' + key + ' to be ' + type);

				if (type === 'number') {
					assert.equal(value, ~~value, 'Expected ' + key + ' to be integer');
					assert(value >= 0, 'Expected ' + key + ' to be not negative');
				}

				return;
			}

			/* Fall here for arrays */
			switch (key) {
				case 'arguments':
					value.forEach(function (argument) {
						switch (typeof argument) {
							/* Elementary types */
							case 'string':
							case 'number':
								return;

							case 'object':
								if (Array.isArray(argument)) {
									assert.equal(
										task.count, argument.length,
										'Options array should contain ' + task.count + ' values'
									);

									return;
								}
								break;
						}

						throw new Error('Unknown type in options');
					});
					break;

				case 'watch':
					for (i = 0, l = value.length; i < l; i++) {
						assert.equal(typeof value[i], 'string', 'Watch pattern should be string');
					}
					break;
			}
		});

		task.name = name;
	});

	return config;
}

/**
 * Weaver version
 * @property version
 * @type String
 */
define('property', 'version', require('../package').version, { writable: false });

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
 * Path to configuration file
 * @property file
 * @type String
 */
define('property', 'file', '');

/**
 * Extend Weaver with property or method
 * @method define
 */
define('method', 'define', define);

/**
 * Write something in log
 * @method log
 * @chainable
 */
define('method', 'log', function () { return this; });

/**
 * Send SIGTERM to all processes and exit
 * @method die
 * @param {Number} code Exit code
 * @chainable
 */
define('method', 'die', function (code) {
	var tasks   = this.tasks,
		timeout = 100,
		name;

	Object.keys(tasks).forEach(function (name) {
		if (tasks[name].timeout > timeout) {
			timeout = tasks[name].timeout;
		}

		tasks[name].persistent = false;
		tasks[name].stop();
	});

	setTimeout(function () {
		process.exit(code === undefined? 1 : code);
	}, timeout);

	return this;
});

/**
 * Upgrade current state
 * @method upgrade
 * @param {String} data Configuration data
 */
define('method', 'upgrade', function (data) {
	var parameters;

	try {
		/* Try to parse JSON */
		data = JSON.parse(data);

		/* Validate new state */
		parameters = validate(data);
	} catch (error) {
		error.message = 'Config error: ' + error.message;
		this.emit('error', error);
	}

	if (parameters) {
		this.parameters = parameters;
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
		result = {},
		i, l, name, task, subtask, subtasks;

	Object.keys(tasks).forEach(function (name) {
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
				time   : subtask.time
			} : null);
		}
	});

	return result;
});

/**
 * Execute command with given arguments
 * @method command
 * @chainable
 */
define('method', 'command', function (action, name, options) {
	var tasks = this.tasks,
		task, fn;

	if (!Array.isArray(options)) {
		options = [];
	}

	if (name === null) {
		fn = Task.prototype[action];

		Object.keys(tasks).forEach(function (name) {
			fn.apply(tasks[name], options);
		});

		return this;
	}

	task = tasks[name];

	if (task) {
		task[action].apply(task, options);
	}

	if (name.match(/^\d+$/)) {
		this.command(action, null, options.concat([Number(name)]));
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
 * Fired when configuration file should be re-read
 * @event config
 */
define('handler', 'config', function () {
	var that = this;

	if (this.file) {
		fs.readFile(this.file, function (error, data) {
			if (error) {
				that.emit('error', error);
				return;
			}

			that.upgrade(data);
		});
	}
});

/**
 * Fired when tasks should be checked and upgraded
 * @event upgrade
 */
define('handler', 'upgrade', function () {
	var that  = this,
		tasks = this.parameters.tasks,
		path  = this.parameters.path || '';

	if (path[0] !== '/') {
		path = dirname(this.file) + '/' + path;
	}

	this.path = resolve(path);

	Object.keys(tasks).forEach(function (name) {
		/* Set cwd for tasks */
		tasks[name].cwd = tasks[name].cwd || that.path;

		that.tasks[name] = new Task(that, name, tasks[name]);
	});
});
