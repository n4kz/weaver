assert = require 'assert'
Task   = require '../lib/task.js'
sigint = './t/bin/sigint'
plain  = './t/bin/plain'

_ = (name, fn) ->
	return ->
		fn(new Task name)

(vows = require 'vows')
	.describe('restart')
	.addBatch
		'by pid':
			topic: ->
				task = new Task 31,
					count: 2
					source: plain
					timeout: 100

				task._pid1 = task.subtasks[0].pid
				task._pid2 = task.subtasks[1].pid

				setTimeout((->
					task.restart(task._pid1)
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 31, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 31, (task) ->
				assert.notEqual task.subtasks[1].pid, 0
				assert.notEqual task.subtasks[0].pid, 0
				assert.notEqual task.subtasks[0].pid, task._pid1
				assert.notEqual task.subtasks[0].pid, task._pid2
				assert.equal    task.subtasks[1].pid, task._pid2

			status: _ 31, (task) ->
				assert.equal task.subtasks[0].status, 'W'
				assert.equal task.subtasks[1].status, 'W'

			identifiers: _ 31, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

		'all running':
			topic: ->
				task = new Task 32,
					count: 2
					source: plain
					timeout: 100

				setTimeout((->
					task.restart()
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 32, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 32, (task) ->
				assert.notEqual task.subtasks[1].pid, 0
				assert.notEqual task.subtasks[0].pid, 0
				assert.notEqual task.subtasks[0].pid, task._pid1
				assert.notEqual task.subtasks[0].pid, task._pid2
				assert.notEqual task.subtasks[1].pid, task._pid1
				assert.notEqual task.subtasks[1].pid, task._pid2

			status: _ 32, (task) ->
				assert.equal task.subtasks[0].status, 'W'
				assert.equal task.subtasks[1].status, 'W'

			identifiers: _ 32, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

		'with sigterm':
			topic: ->
				task = new Task 33,
					count: 1
					source: sigint
					timeout: 100

				task._pid1 = task.subtasks[0].pid

				setTimeout((->
					task.restart()
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 33, (task) ->
				assert.equal task.subtasks.length, 1

			processes: _ 33, (task) ->
				assert.notEqual task.subtasks[0].pid, 0
				assert.notEqual task.subtasks[0].pid, task._pid1

			status: _ 33, (task) ->
				assert.equal task.subtasks[0].status, 'W'

			identifiers: _ 33, (task) ->
				assert.equal task.subtasks[0].id, 0

	.export module
