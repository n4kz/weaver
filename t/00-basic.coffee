assert  = require('assert')
weaver  = require('../lib/weaver.js')
Task    = require('../lib/task.coffee')
Watcher = require('../lib/watcher.coffee')
emitter = require('events').EventEmitter

methods = [
	'define', 'log', 'validate', 'die', 'upgrade',
	'status', 'command'
]

events = ['error', 'upgrade']

(require 'vows')
	.describe('basic')
	.addBatch
		constructor: ->
			assert.instanceOf weaver, weaver.constructor
			assert.instanceOf weaver, emitter

		properties: ->
			# version
			assert.equal weaver.version, require('../package').version

			# start
			assert.isNumber weaver.start
			assert weaver.start <= Date.now()
			assert weaver.start > 0

			# config
			assert.deepEqual weaver.config, {}
			assert.typeOf    weaver.config, 'object'

			assert.isUndefined weaver.config.__proto__

		methods: ->
			for method in methods
				assert.isFunction weaver[method]
				assert not weaver.propertyIsEnumerable method

		define: ->
			noop = ->

			weaver.define 'method', 'noop', noop

			# New method defined
			assert.equal weaver.noop, noop
			assert not weaver.propertyIsEnumerable 'noop'

		events: ->
			for event in events
				assert.equal emitter.listenerCount(weaver, event), 1

		watcher: ->
			assert.isFunction Watcher

			watcher = new Watcher()

			assert.isFunction watcher.stop
			assert.isFunction watcher.start
			assert.instanceOf watcher, Watcher

		task: ->
			assert.isFunction Task
			assert.isFunction Task.create
			assert.isFunction Task.status

			assert.deepEqual Task.tasks, {}
			assert.typeOf    Task.tasks, 'object'

			assert.isUndefined Task.tasks.__proto__

	.export(module)
