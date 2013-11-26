assert  = require('assert')
weaver  = require('../lib/weaver.js')
emitter = require('events').EventEmitter

name = 'test' + Date.now()

methods = [
	'upgrade', 'upgradeParameter', 'expandEnv', 'get', 'spawn', 'foreach',
	'killSubtask', 'stopSubtask', 'restartSubtask',
	'killPID', 'stopPID', 'restartPID',
	'stopSubtasks', 'killSubtasks', 'restartSubtasks',
	'log', 'exitHandler'
]

weaver.task(name, {})
task = weaver.tasks[name]

(require 'vows')
	.describe('task')
	.addBatch
		require:
			topic: null

		# Check default properties
		properties: ->
			assert.equal name, task.name

			assert.isArray  task.subtasks
			assert.isArray  task.watched
			assert.isArray  task.arguments
			assert.isObject task.env

			assert.equal 1000,          task.timeout
			assert.equal 1000,          task.runtime
			assert.equal 0,             task.count
			assert.equal '',            task.source
			assert.equal false,         task.executable
			assert.equal false,         task.persistent
			assert.equal process.cwd(), task.cwd

		methods: ->
			for method in methods
				assert.isFunction task[method]
				assert not weaver.propertyIsEnumerable task

	.export(module)
