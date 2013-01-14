assert = require 'assert'
http   = require 'http'
vows   = require 'vows'
Task   = require '../lib/task.js'
sigint = './t/bin/sigint'
plain  = './t/bin/plain'


vows
	.describe('task')
	.addBatch
		constructor:
			topic:
				new Task 'constructor',
					count: 1
					source: sigint
					timeout: 100

			singleton: (task) ->
				assert task is new Task('constructor'), 'same reference'
				assert task isnt new Task('cnstrctr'),  'by name'
				assert task.count is 1,        'one subtask'
				assert task.source is sigint,  'right source'
				assert task.subtasks,          'has subtasks'

			properties: (task) ->
				subtask = task.subtasks[0]

				assert subtask.pid
				assert subtask.time
				assert subtask.id is 0
				assert subtask.name is 'constructor'
				assert subtask.status is 'W'
				assert subtask.process
				assert subtask.process isnt process
				assert subtask.pid is subtask.process.pid
				assert subtask.pid isnt process.pid
				assert task.subtasks.length is task.count

		parameters:
			topic:
				new Task 'parameters',
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
					task = new Task 'upgrade partial',
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

				method: ->
					task = new Task 'upgrade partial'
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
					task = new Task 'upgrade full',
						count: 2
						source: sigint
						timeout: 100

					task._pid1 = task.subtasks[0].pid
					task._pid2 = task.subtasks[1].pid

					setTimeout((->
						task.upgrade
							arguments: [1000]
					), 50)

					setTimeout((=>
						@callback()
					), 350)

					undefined

				method: ->
					task = new Task 'upgrade full'
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

		stop:
			topic: false
			simple:
				topic: ->
					task = new Task 'stop simple'
						count: 2
						source: sigint
						timeout: 50

					task._pid1 = task.subtasks[0].pid
					task._pid2 = task.subtasks[1].pid

					setTimeout((->
						task.stop(task._pid1)
					), 50)

					setTimeout((=>
						@callback()
					), 150)

					undefined

				method: ->
					task = new Task 'stop simple'
					assert task.subtasks.length is 2,            'two tasks'
					assert not task.subtasks[0].pid,             'first has no pid'
					assert task.subtasks[1].pid,                 'second has pid'
					assert task.subtasks[1].pid isnt task._pid1, 'second pid isnt old pid 1'
					assert task.subtasks[1].pid is   task._pid2, 'second pid is old pid 2'
					assert task.subtasks[0].status is 'E',       'first has right status'
					assert task.subtasks[1].status is 'W',       'second has right status'
					assert task.subtasks[0].id is 0,             'first has right id'
					assert task.subtasks[1].id is 1,             'second has right id'

			full:
				topic: ->
					task = new Task 'stop full'
						count: 2
						source: plain
						timeout: 100

					setTimeout((->
						task.stop()
					), 50)

					setTimeout((=>
						@callback()
					), 300)

					undefined

				method: ->
					task = new Task 'stop full'
					assert task.subtasks.length is 2,            'two tasks'
					assert not task.subtasks[0].pid,             'first has no pid'
					assert not task.subtasks[1].pid,             'second has no pid'
					assert task.subtasks[0].id is 0,             'first has right id'
					assert task.subtasks[1].id is 1,             'second has right id'
					assert.equal task.subtasks[0].status, 'E',   'first has right status'
					assert.equal task.subtasks[1].status, 'E',   'second has right status'

	.export module
