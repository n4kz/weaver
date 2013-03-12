'use strict';

var fs        = require('fs'),
	cp        = require('child_process'),
	assert    = require('assert'),
	dirname   = require('path').dirname,
	resolve   = require('path').resolve,
	Task      = require('./task'),
	Anubseran = null,

	/* Task options format */
	format = {
		count      : 'number',
		source     : 'string',
		cwd        : 'string',
		env        : 'object',
		persistent : 'boolean',
		executable : 'boolean',
		timeout    : 'number',
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
		watch      : true,
		arguments  : true
	};

/**
 * Nerubian Weaver
 * @class Weaver
 * @constructor
 */
function Weaver (file, options) {
	if (Anubseran) {
		return Anubseran;
	}

	if (!(this instanceof Weaver)) {
		return new Weaver(file, options);
	}

	Anubseran = this;

	options = options || {};

	/**
	 * Write something in log
	 * @method log
	 */
	this.log = options.log || this.noop;

	/**
	 * Tasks by name
	 * @property tasks
	 * @type Object
	 */
	this.tasks = Object.create(null);

	/**
	 * Parsed configuration file
	 * @property parameters
	 * @type Object
	 */
	this.parameters = {};

	/**
	 * Configuration filename
	 * @property file
	 * @type String
	 */
	this.file = file;

	/* Hide helpers */
	this.$ = this.noop;
	this._ = this.noop;

	/* Read configuration file for the first time */
	this.config();

	return this;
}

/*
 * Helpers
 */
(function (Emitter) {
	var proto = new Emitter();

	/**
	 * Extend Weaver.prototype with property or method
	 * @method _
	 * @protected
	 * @param {String} name Property name
	 * @param value Property value
	 * @chainable
	 */
	Weaver._ = function (name, value) {
		assert.ok(!proto.hasOwnProperty(name), 'Property ' + name + 'already exists');

		proto[name] = value;
		return this;
	};

	/**
	 * Bind handler on event
	 * @method $
	 * @protected
	 * @param {String} event Event name
	 * @param {Function} handler Event handler
	 * @chainable
	 */
	Weaver.$ = function (event, handler) {
		proto.on(event, handler);
		return this;
	};

	Weaver.prototype = proto;
}(require('events').EventEmitter));

/*
 * Methods
 */
Weaver
	/**
	 * Send SIGTERM to all processes and exit
	 * @method die
	 * @param {Number} code Exit code
	 * @chainable
	 */
	._('die', function (code) {
		var tasks   = Anubseran.tasks,
			timeout = 100,
			name;

		for (name in tasks) {
			if (tasks[name].timeout > timeout) {
				timeout = tasks[name].timeout;
			}

			tasks[name].persistent = false;
			tasks[name].stop();
		}

		setTimeout(function () {
			process.exit(null == code? 1 : code);
		}, timeout);

		return Anubseran;
	})

	/**
	 * Upgrade current state
	 * @method upgrade
	 * @param {String} data Configuration data
	 */
	._('upgrade', function (data) {
		try {
			/* Try to parse JSON */
			var parameters = JSON.parse(data);

			/* Validate new state */
			validate(parameters);
		} catch (error) {
			error.message = 'Config error: ' + error.message;
			Anubseran.emit('error', error);
		}

		if (parameters) {
			Anubseran.parameters = parameters;
			Anubseran.emit('upgrade');
		}

		return Anubseran;
	})

	._('check', function () {
		Anubseran.emit('upgrade');
		return Anubseran;
	})

	/**
	 * Emit config event
	 * @method config
	 * @chainable
	 */
	._('config', function () {
		Anubseran.emit('config');

		return Anubseran;
	})

	/**
	 * Get status report
	 * @method status
	 * @return {Object} Task groups with subtasks data
	 */
	._('status', function () {
		var tasks  = Anubseran.tasks,
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
					time   : subtask.time
				} : null);
			}
		}

		return result;
	})

	._('restart', function (name) {
		command('restart', name);
		return Anubseran;
	})

	._('stop', function (name) {
		command('stop', name);
		return Anubseran;
	})

	._('kill', function (name, signal) {
		command('kill', name, [signal]);
		return Anubseran;
	})

	/**
	 * Empty function
	 * @method noop
	 * @chainable
	 */
	._('noop', function () { return this; });

/*
 * Events
 */
Weaver
	/**
	 * Fired when error occured
	 * @event error
	 * @param {Error} error Object with error details
	 */
	.$('error', function (error) {
		Anubseran.log(error.message);
	})

	/**
	 * Fired when configuration file should be re-read
	 * @event config
	 */
	.$('config', function () {
		if (Anubseran.file) {
			fs.readFile(Anubseran.file, onRead);
		}
	})

	/**
	 * Fired when tasks should be checked and upgraded
	 * @event upgrade
	 */
	.$('upgrade', function () {
		var tasks = Anubseran.parameters.tasks,
			path  = Anubseran.parameters.path || '',
			name;

		if (path[0] !== '/') {
			path = dirname(Anubseran.file) + '/' + path;
		}

		Anubseran.path = resolve(path);

		for (name in tasks) {
			if (!tasks.hasOwnProperty(name)) {
				continue;
			}

			/* Set cwd for tasks to Anubseran.path */
			tasks[name].cwd = tasks[name].cwd || Anubseran.path;

			Anubseran.tasks[name] = new Task(name, tasks[name]);
		}
	});

function validate (config) {
	var tasks = config.tasks,
		task, name, field, value, type, i, l;

	/* No tasks defined */
	assert.equal(typeof tasks, 'object', 'Tasks object required');
	assert.ok(Object.keys(tasks).length, 'At least one task required');

	if (config.path) {
		assert.equal(typeof config.path, 'string');
	}

	for (name in tasks) {
		if (!tasks.hasOwnProperty(name)) {
			continue;
		}

		task = tasks[name];

		assert.equal(typeof task, 'object', 'Task is not an object');

		for (field in optional) {
			if (!optional.hasOwnProperty(field) || optional[field]) {
				continue;
			}

			assert.ok(task.hasOwnProperty(field), 'Option ' + field + ' required');
		}

		for (field in task) {
			if (!task.hasOwnProperty(field)) {
				continue;
			}

			value = task[field];
			type  = format[field];

			assert.ok(type, 'Unknown option ' + field);

			if (!(type === 'array' && Array.isArray(value))) {
				assert.equal(typeof value, format[field], 'Expected ' + field + ' to be ' + type);
				continue;
			}

			/* Fall here for arrays */
			switch (field) {
				case 'arguments':
					for (i = 0, l = value.length; i < l; i++) {
						switch (typeof value[i]) {
							/* Elementary types */
							case 'string':
							case 'number':
								continue;

							case 'object':
								if (Array.isArray(value[i])) {
									break;
								}

							default:
								throw new Error('Unknown type in options');
						}

						assert.equal(task.count, value[i].length, 'Options array should contain ' + task.count + ' values');
					}

					break;

				case 'watch':
					for (i = 0, l = value.length; i < l; i++) {
						assert.equal(typeof value[i], 'string', 'Watch pattern should be string');
					}
					break;
			}
		}

		task.name = name;
	}
}

function onRead (error, data) {
	var file, watches;

	if (error) {
		Anubseran.emit('error', error);
		return;
	}

	Anubseran.upgrade(data);
}

function command (action, name, options) {
	var tasks = Anubseran.tasks,
		task, fn;

	if (!Array.isArray(options)) {
		options = [];
	}

	if (name === null) {
		fn = Task.prototype[action];

		for (name in tasks) {
			fn.apply(tasks[name], options);
		}

		return;
	}

	task = tasks[name];

	if (task) {
		task[action].apply(task, options);
	}

	if (name.match(/^\d+$/)) {
		command(action, null, options.concat([Number(name)]));
	}
}

module.exports = Weaver;
