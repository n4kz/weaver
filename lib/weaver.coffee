assert       = require('assert')
resolve      = require('path').resolve
zs           = require('z-schema')
schema       = require('./schema')
EventEmitter = require('events').EventEmitter
Task         = require('./task')
validator    = new zs(strictMode: true)

class Weaver extends EventEmitter
	version : require('../package').version
	log     : ->

	constructor: ->
		@on('error', @errorHandler)
		@on('upgrade', @upgradeHandler)

		@start  = Date.now()
		@config = Object.create(null)

		return @

	# Validate configuration object
	validate: (configuration) ->
		# Validate schema
		assert.ok(validator.validate(configuration, schema), 'Invalid configuration')

		# Perform additional validation
		for own name, task of configuration.tasks
			# Validate nested arrays for arguments
			for own key of task
				if key is 'arguments'
					for argument in task[key]
						if Array.isArray(argument)
							assert.equal(
								task.count, argument.length,
								"Nested array in arguments should contain #{task.count} values"
							)

			task.name = name

		return configuration

	# Upgrade current state
	upgrade: (data, path) ->
		parts  = [path]
		params = null

		try
			# Try to parse JSON
			data = JSON.parse(data)

			# Validate new state
			params = @validate(data)
		catch error
			error.message = "Config error: #{error.message}"

			@emit('error', error)

		if params
			if params.path
				parts.push(params.path)

			for own name, task of params.tasks
				task.cwd = resolve.apply(undefined, parts.concat(task.cwd or '.'))

				@config[name] = task

			@emit('upgrade')

		return

	# Get status report
	status: ->
		return Task.status()

	# Execute command with given arguments
	command: (action, name, args) ->
		fn = Task::[action + 'PID']

		unless Array.isArray(args)
			args = []

		unless typeof fn is 'function'
			throw new Error('Unknown action ' + action)

		unless name?
			# Execute command for all tasks
			for own name, task of Task.tasks
				fn.apply(task, args)
		else
			task = Task.tasks[name]

			if task
				if action is 'kill'
					args.unshift(null)

				fn.apply(task, args)
			else if `Number(name) == name`
				args.unshift(Number(name))

				@command(action, null, args)
			else
				@log('Task ' + name + ' was not found')

		return

	# Stop all subtasks and exit
	die: (code) ->
		code = if code? then code else 1

		tryExit = =>
			for own name, task of Task.tasks
				for subtask in task.subtasks
					return if subtask.pid

			@emit('exit', code)

			return

		for own name, task of Task.tasks
			if task.timeout > timeout
				timeout = task.timeout

			task.dropSubtasks()
			task.on('exit', tryExit)

		setImmediate(tryExit)

		return

	errorHandler: (error) ->
		@log(error.message)

		return

	upgradeHandler: ->
		# Spot dropped tasks
		for own name, task of Task.tasks
			unless name of @config
				task.dropSubtasks()

		# Create or update tasks
		for own name, options of @config
			task = Task.create(name)

			# Setup logger
			task.log ?= @log.bind(@)

			# Setup error handler
			unless task.listenerCount('error')
				task.on('error', @emit.bind(@, 'error'))

			task.upgrade(options)

		return

module.exports = new Weaver()
