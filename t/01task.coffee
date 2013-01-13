assert = require 'assert'
http   = require 'http'
vows   = require 'vows'
Task   = require '../lib/task.js'
sigint = './t/bin/sigint'

vows
	.describe('task')
	.addBatch
		constructor:
			topic:
				new Task 'one',
					count: 1
					source: sigint
					timeout: 100

			singleton: (task) ->
				assert task is new Task('one'), 'same reference'
				assert task isnt new Task('1'), 'by name'
				assert task.count is 1,        'one subtask'
				assert task.source is sigint,  'right source'
				assert task.subtasks,          'has subtasks'

			properties: (task) ->
				subtask = task.subtasks[0]

				assert subtask.pid
				assert subtask.time
				assert subtask.id is 0
				assert subtask.name is 'one'
				assert subtask.status is 'W'
				assert subtask.process
				assert subtask.process isnt process
				assert subtask.pid is subtask.process.pid
				assert subtask.pid isnt process.pid
				assert task.subtasks.length is task.count

		parameters:
			topic:
				new Task 'two',
					count: 2
					source: sigint
					arguments: [[1000, 2000], '--test', ['--first', '--second']]

			check: (task) ->
				assert task.subtasks.length is 2,                                     'two subtasks'
				assert.deepEqual task.subtasks[0].args, [1000, '--test', '--first'],  'first has right arguments'
				assert.deepEqual task.subtasks[1].args, [2000, '--test', '--second'], 'second has right arguments'

		upgrade:
			topic: false
			partial:
				topic: ->
					task = new Task '3.1',
						count: 1
						source: sigint
						timeout: 50

					task._pid1 = task.subtasks[0].pid

					task.upgrade
						count: 2

					setTimeout((=>
						@callback()
					), 100)

					undefined

				method: () ->
					task = new Task '3.1'
					assert task.subtasks.length is 2,            'two tasks'
					assert task.subtasks[0].pid,                 'first has pid'
					assert task.subtasks[0].pid is task._pid1,   'first pid was not changed'
					assert task.subtasks[1].pid,                 'second has pid'
					assert task.subtasks[1].pid isnt task._pid1, 'second pid differs'
					assert task.subtasks[0].status is 'W',       'first has right status'
					assert task.subtasks[1].status is 'W',       'second has right status'
					assert task.subtasks[0].id is 0,             'first has right id'
					assert task.subtasks[1].id is 1,             'second has right id'

			full:
				topic: ->
					task = new Task '3.2',
						count: 2
						source: sigint
						timeout: 50


					task._pid1 = task.subtasks[0].pid
					task._pid2 = task.subtasks[1].pid

					task.upgrade
						arguments: [1000]

					setTimeout((=>
						@callback()
					), 100)

					undefined

				method: () ->
					task = new Task '3.2'
					assert task.subtasks.length is 2,            'two tasks'
					assert task.subtasks[0].pid,                 'first has pid'
					assert task.subtasks[0].pid isnt task._pid1, 'first pid isnt old pid 1'
					assert task.subtasks[0].pid isnt task._pid2, 'first pid isnt old pid 2'
					assert task.subtasks[1].pid,                 'second has pid'
					assert task.subtasks[1].pid isnt task._pid1, 'second pid isnt old pid 1'
					assert task.subtasks[1].pid isnt task._pid2, 'second pid isnt old pid 2'
					assert task.subtasks[0].status is 'W',       'first has right status'
					assert task.subtasks[1].status is 'W',       'second has right status'
					assert task.subtasks[0].id is 0,             'first has right id'
					assert task.subtasks[1].id is 1,             'second has right id'

	.export module
