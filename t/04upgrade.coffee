assert = require 'assert'
Task   = require '../lib/task.js'
sigint = './t/bin/sigint'
plain  = './t/bin/plain'

_ = (name, fn) ->
	return ->
		fn(new Task name)

(vows = require 'vows')
	.describe('upgrade')
	.addBatch
		'partial':
			topic: ->
				task = new Task 41,
					count: 1
					source: plain
					timeout: 50

				task._pid = task.subtasks[0].pid

				setTimeout((->
					task.upgrade
						count: 2
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 41, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 41, (task) ->
				assert.equal    task.subtasks[0].pid, task._pid
				assert.notEqual task.subtasks[1].pid, 0
				assert.notEqual task.subtasks[1].pid, task._pid

			status: _ 41, (task) ->
				assert.equal task.subtasks[0].status, 'W'
				assert.equal task.subtasks[1].status, 'W'

			identifiers: _ 41, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

		'full':
			topic: ->
				task = new Task 42,
					count: 2
					source: plain
					timeout: 50

				task._pid1 = task.subtasks[0].pid
				task._pid2 = task.subtasks[1].pid

				setTimeout((->
					task.upgrade
						arguments: [1000]
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 42, (task) ->
				assert.equal task.subtasks.length, 2

			processes: _ 42, (task) ->
				assert.notEqual task.subtasks[0].pid, 0
				assert.notEqual task.subtasks[1].pid, 0
				assert.notEqual task.subtasks[0].pid, task._pid1
				assert.notEqual task.subtasks[0].pid, task._pid2
				assert.notEqual task.subtasks[1].pid, task._pid1
				assert.notEqual task.subtasks[1].pid, task._pid2

			status: _ 42, (task) ->
				assert.equal task.subtasks[0].status, 'W'
				assert.equal task.subtasks[1].status, 'W'

			identifiers: _ 42, (task) ->
				assert.equal task.subtasks[0].id, 0
				assert.equal task.subtasks[1].id, 1

		'with sigterm':
			topic: ->
				task = new Task 43,
					count: 1
					source: sigint
					timeout: 100

				task._pid1 = task.subtasks[0].pid

				setTimeout((->
					task.upgrade
						arguments: [1000]
				), 50)

				setTimeout((=>
					@callback()
				), 200)

				undefined

			count: _ 43, (task) ->
				assert.equal task.subtasks.length, 1

			processes: _ 43, (task) ->
				assert.notEqual task.subtasks[0].pid, 0
				assert.notEqual task.subtasks[0].pid, task._pid1

			status: _ 43, (task) ->
				assert.equal task.subtasks[0].status, 'W'

			identifiers: _ 43, (task) ->
				assert.equal task.subtasks[0].id, 0

	.export module
