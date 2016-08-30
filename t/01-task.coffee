assert  = require('assert')
Task    = require('../lib/task.coffee')

methods = [
	'upgrade', 'upgradeParameter', 'spawn', 'foreach',
	'killSubtask', 'stopSubtask', 'restartSubtask',
	'getPID', 'killPID', 'stopPID', 'restartPID',
	'stopSubtasks', 'killSubtasks', 'restartSubtasks',
	'exitHandler', 'expandEnv'
]

defaultName = 'test' + Date.now()
Task
	.create defaultName
	.upgrade {}

(require 'vows')
	.describe('task')
	.addBatch
		# Check default properties
		properties: ->
			name = defaultName
			task = Task.tasks[name]

			assert.equal name, task.name

			assert.isArray    task.subtasks
			assert.isFunction task.watchHandler

			assert.isUndefined task.timeout
			assert.isUndefined task.runtime
			assert.isUndefined task.count
			assert.isUndefined task.source
			assert.isUndefined task.executable
			assert.isUndefined task.persistent
			assert.isUndefined task.cwd
			assert.isUndefined task.env
			assert.isUndefined task.arguments
			assert.isUndefined task.watch

		methods: ->
			name = defaultName
			task = Task.tasks[name]

			for method in methods
				assert.isFunction task[method]

		constructor: ->
			name = Math.random()

			task = Task.create name

			assert.equal task, Task.tasks[name]

			assert.isUndefined task.runtime
			assert.isUndefined task.timeout

			Task
				.create name
				.upgrade runtime: 2000

			assert.equal 2000, task.runtime
			assert.equal task, Task.tasks[name]

			Task
				.create name
				.upgrade timeout: 5000

			assert.equal 5000, task.timeout
			assert.equal task, Task.tasks[name]

	.export(module)
