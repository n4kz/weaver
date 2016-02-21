assert  = require('assert')
weaver  = require('../lib/weaver.js')
emitter = require('events').EventEmitter

methods = [
	'define', 'task', 'log', 'validate', 'die', 'upgrade',
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

			# tasks
			assert.deepEqual weaver.tasks, {}

			# parameters
			assert.deepEqual weaver.parameters, {}

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

	.export(module)
