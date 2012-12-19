'use strict';

var fs        = require('fs'),
	cp        = require('child_process'),
	assert    = require('assert'),
	Task      = require('./task'),
	ok        = assert.ok,
	Anubseran = null,

	/* Task options format */
	format = {
		count     : 'number',
		source    : 'string',
		restart   : 'boolean',
		timeout   : 'number',
		watch     : 'array',
		arguments : 'array'
	},

	/* Which task parameters are optional */
	optional = {
		count     : false,
		source    : false,
		restart   : true,
		timeout   : true,
		watch     : true,
		arguments : true
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

	ok(file, 'Filename required');

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
	this.tasks = {};

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
	 * Extend Controller.prototype with property or method
	 * @method _
	 * @protected
	 * @param {String} name Property name
	 * @param value Property value
	 * @chainable
	 */
	Weaver._ = function (name, value) {
		if (proto.hasOwnProperty(name)) {
			throw new Error('Property ' + name + 'already exists');
		}

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
		var tasks = Anubseran.tasks,
			task;

		Anubseran.log('');
		Anubseran.log('Weaver dies');

		for (task in tasks) {
			if (!tasks.hasOwnProperty(task)) continue;

			/* FIXME: use another logic for this */
			tasks[task].restart = false;

			tasks[task].killall('SIGTERM');
		}

		setTimeout(function () {
			process.exit(code || 1);
		}, 1000);

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
			Anubseran.emit('error', error);
		}

		if (parameters) {
			Anubseran.parameters = parameters;
			Anubseran.emit('upgrade');
		}

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

	._('noop', function () { return this; });

/*
 * Events
 */
Weaver
	.$('error', function (error) {
		Anubseran.log(error);
	})

	.$('config', function () {
		fs.readFile(Anubseran.file, function (error, data) {
			var file, watches;

			if (error) {
				Anubseran.emit('error', error);
				return;
			}

			Anubseran.log('Weaver reads ' + Anubseran.file);

			Anubseran.upgrade(data);
		});
	})

	.$('upgrade', function () {
		var tasks = this.parameters.tasks,
			task;

		for (task in tasks) {
			if (!tasks.hasOwnProperty(task)) continue;

			Anubseran.log('Upgrading ' + task);
			this.tasks[task] = new Task(task, tasks[task]);
		}
	});

function validate (config) {
	var tasks = config.tasks,
		task, name, field, value, type, i, l;

	/* No tasks defined */
	assert.equal(typeof tasks, 'object', 'Tasks object required');
	ok(Object.keys(tasks).length, 'At least one task required');

	for (name in tasks) {
		if (!tasks.hasOwnProperty(name)) continue;

		task = tasks[name];

		assert.equal(typeof task, 'object', 'Task is not an object');

		for (field in task) {
			if (!task.hasOwnProperty(field)) continue;

			value = task[field];
			type  = format[field];

			switch (typeof value) {
				case 'undefined':
					ok(optional[field], 'Unknown option ' + field);
					continue;

				case 'object':
					if (type === 'array' && Array.isArray(value)) break;

				default:
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
								if (Array.isArray(value[i])) break;

							default:
								throw new Error('Unknown type in options');
						}

						assert.equal(task.count, value[i].length, 'Options array should contain ' + task.count + ' values');
					}

					break;

				case 'watch':
					break;
			}
		}

		task.name = name;
	}
}

module.exports = Weaver;
