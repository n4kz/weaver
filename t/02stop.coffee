assert = require 'assert'
Task   = require '../lib/task.js'
sigint = './t/bin/sigint'
plain  = './t/bin/plain'

_ = (name, fn) ->
	return ->
		fn(new Task name)

(vows = require 'vows')
	.describe('stop')
	.addBatch
		'by pid':
			topic: ->
				task = new Task 21,
					count: 2
					source: plain
					timeout: 50

				task._pid1 = task.subtasks[0].pid
				task._pid2 = task.subtasks[1].pid

				setTimeout((->
					task.stop(task._pid1)
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 21, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 21, (task) ->
				assert.equal task.subtasks[0].pid, 0
				assert.equal task.subtasks[1].pid, task._pid2

			status: _ 21, (task) ->
				assert.equal task.subtasks[0].status, 'E'
				assert.equal task.subtasks[1].status, 'W'

			identifiers: _ 21, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

		'all running':
			topic: ->
				task = new Task 22,
					count: 2
					source: plain
					timeout: 100

				setTimeout((->
					task.stop()
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 22, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 22, (task) ->
				assert.equal task.subtasks[1].pid, 0
				assert.equal task.subtasks[0].pid, 0

			status: _ 22, (task) ->
				assert.equal task.subtasks[0].status, 'E'
				assert.equal task.subtasks[1].status, 'E'

			identifiers: _ 22, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

		'with sigterm':
			topic: ->
				task = new Task 23,
					count: 1
					source: sigint
					timeout: 100

				setTimeout((->
					task.stop()
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 23, (task) ->
				assert.equal task.subtasks.length, 1

			processes: _ 23, (task) ->
				assert.equal task.subtasks[0].pid, 0

			status: _ 23, (task) ->
				assert.equal task.subtasks[0].status, 'E'

			identifiers: _ 23, (task) ->
				assert.equal task.subtasks[0].id, 0

	.export module
