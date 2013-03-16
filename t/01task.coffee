assert = require 'assert'
Task   = require '../lib/task.js'
sigint = './t/bin/sigint'
plain  = './t/bin/plain'

(vows = require 'vows')
	.describe('task')
	.addBatch
		constructor:
			topic:
				new Task 'constructor',
					count: 1
					source: sigint
					timeout: 100

			singleton: (task) ->
				assert.equal    task, new Task('constructor')
				assert.notEqual task, new Task('_constructor')
				assert.equal task.count, 1
				assert.equal task.source, sigint
				assert.isArray task.subtasks

			properties: (task) ->
				subtask = task.subtasks[0]

				assert.isNumber    subtask.pid
				assert.isNumber    subtask.time
				assert.notEqual    subtask.pid, 0
				assert.equal       subtask.id, 0
				assert.equal       subtask.name, 'constructor'
				assert.equal       subtask.status, 'W'
				assert.isObject    subtask.process
				assert.isNotNull   subtask.process
				assert.isUndefined subtask.code
				assert.isUndefined subtask.signal
				assert.notEqual    subtask.process, process
				assert.equal       subtask.pid, subtask.process.pid
				assert.notEqual    subtask.pid, process.pid
				assert.equal       task.subtasks.length, task.count

		parameters:
			topic:
				new Task 'parameters',
					count: 2
					source: sigint
					arguments: [[1000, 2000], '--test', ['--first', '--second']]

			check: (task) ->
				assert.equal     task.subtasks.length, 2
				assert.deepEqual task.subtasks[0].args, [1000, '--test', '--first']
				assert.deepEqual task.subtasks[1].args, [2000, '--test', '--second']

	.export module
