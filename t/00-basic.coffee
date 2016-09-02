assert       = require('assert')
Weaver       = require('../lib/weaver.coffee')
Task         = require('../lib/task.coffee')
Watcher      = require('../lib/watcher.coffee')
EventEmitter = require('events').EventEmitter

methods = [
	'log', 'validate', 'die', 'upgrade',
	'status', 'command'
]

events = ['error', 'upgrade']

(require 'vows')
	.describe('basic')
	.addBatch
		constructor: ->
			assert.instanceOf Weaver, Weaver.constructor
			assert.instanceOf Weaver, EventEmitter

		properties: ->
			# version
			assert.equal Weaver.version, require('../package').version

			# start
			assert.isNumber Weaver.start
			assert Weaver.start <= Date.now()
			assert Weaver.start > 0

			# config
			assert.deepEqual Weaver.config, {}
			assert.typeOf    Weaver.config, 'object'

			assert.isUndefined Weaver.config.__proto__

		logger: ->
			assert.isFunction Weaver.constructor.logger

		methods: ->
			for method in methods
				assert.isFunction Weaver[method]

		events: ->
			for event in events
				assert.equal EventEmitter.listenerCount(Weaver, event), 1

		watcher: ->
			assert.instanceOf Watcher, Watcher.constructor

			assert.isFunction Watcher.stop
			assert.isFunction Watcher.start

		task: ->
			assert.isFunction Task
			assert.isFunction Task.create
			assert.isFunction Task.status

			assert.deepEqual Task.tasks, {}
			assert.typeOf    Task.tasks, 'object'

			assert.isUndefined Task.tasks.__proto__

	.export(module)
