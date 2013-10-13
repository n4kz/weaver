assert  = require('assert')
weaver  = require('../lib/weaver.js')
emitter = require('events').EventEmitter

methods = [
	'define', 'task', 'log', 'validate', 'die', 'upgrade',
	'status', 'command'
]

events = ['error', 'config', 'upgrade']

(require 'vows')
	.describe('basic')
	.addBatch
		require:
			topic: null

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

				# file
				assert.equal weaver.file, ''

			methods: ->
				for method in methods
					assert.isFunction weaver[method]

			events: ->
				for event in events
					assert.equal emitter.listenerCount(weaver, event), 1

	.export(module)
