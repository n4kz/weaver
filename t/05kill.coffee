assert = require 'assert'
Task   = require '../lib/task.js'
sigint = './t/bin/sigint'
plain  = './t/bin/plain'

_ = (name, fn) ->
	return ->
		fn(new Task name)

(vows = require 'vows')
	.describe('kill')
	.addBatch
		'by pid':
			topic: ->
				task = new Task 51,
					count: 2
					source: plain
					timeout: 50

				task._pid1 = task.subtasks[0].pid
				task._pid2 = task.subtasks[1].pid

				setTimeout((->
					task.kill('SIGKILL', task._pid2)
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 51, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 51, (task) ->
				assert.equal task.subtasks[1].pid, 0
				assert.equal task.subtasks[0].pid, task._pid1

			status: _ 51, (task) ->
				assert.equal task.subtasks[1].status, 'S'
				assert.equal task.subtasks[0].status, 'W'

			identifiers: _ 51, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

			signal: _ 51, (task) ->
				assert.isNull task.subtasks[1].code
				assert.equal  task.subtasks[1].signal, 'SIGKILL'

		'all running':
			topic: ->
				task = new Task 52,
					count: 2
					source: plain
					timeout: 50

				setTimeout((->
					task.kill('SIGKILL')
				), 100)

				setTimeout((=>
					@callback()
				), 500)

				undefined

			count: _ 52, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 52, (task) ->
				assert.equal task.subtasks[1].pid, 0
				assert.equal task.subtasks[0].pid, 0

			status: _ 52, (task) ->
				assert.equal task.subtasks[0].status, 'S'
				assert.equal task.subtasks[1].status, 'S'

			identifiers: _ 52, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

			signal: _ 52, (task) ->
				assert.isNull task.subtasks[0].code
				assert.equal  task.subtasks[0].signal, 'SIGKILL'
				assert.isNull task.subtasks[1].code
				assert.equal  task.subtasks[1].signal, 'SIGKILL'

	.export module
