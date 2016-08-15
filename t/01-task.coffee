assert  = require('assert')
weaver  = require('../lib/weaver.js')
emitter = require('events').EventEmitter

methods = [
	'upgrade', 'upgradeParameter', 'get', 'spawn', 'foreach',
	'killSubtask', 'stopSubtask', 'restartSubtask',
	'killPID', 'stopPID', 'restartPID',
	'stopSubtasks', 'killSubtasks', 'restartSubtasks',
	'log', 'exitHandler'
]

defaultName = 'test' + Date.now()
weaver.task defaultName, {}

(require 'vows')
	.describe('task')
	.addBatch
		# Check default properties
		properties: ->
			name = defaultName
			task = weaver.tasks[name]

			assert.equal name, task.name

			assert.isArray  task.subtasks
			assert.isArray  task.watch
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
			name = defaultName
			task = weaver.tasks[name]

			for method in methods
				assert.isFunction task[method]
				assert not task.propertyIsEnumerable method

		constructor: ->
			name = Math.random()

			task = weaver.task name, {}

			assert.equal task.constructor, weaver.task
			assert.equal task, weaver.tasks[name]
			assert.equal 1000, task.runtime
			assert.equal 1000, task.timeout

			assert.equal task, weaver.task name, runtime: 2000
			assert.equal 2000, task.runtime
			assert.equal task, weaver.task name, timeout: 5000
			assert.equal 5000, task.timeout
			assert.equal task, weaver.tasks[name]

	.export(module)
