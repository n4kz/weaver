assert       = require('assert')
resolve      = require('path').resolve
fork         = require('child_process').spawn
EventEmitter = require('events').EventEmitter
Watcher      = require('./watcher')

###*
 #* Status codes
 #* R - restart
 #* E - error
 #* D - done (clean exit)
 #* W - work in progress
 #* S - stopped
###

# Which subtask parameters can be changed without restart
mutable =
	count      : yes
	source     : no
	cwd        : no
	env        : no
	persistent : yes
	executable : no
	timeout    : yes
	runtime    : yes
	watch      : yes
	arguments  : no

class Task extends EventEmitter
	@tasks: Object.create(null)

	@create: (name) ->
		return @tasks[name] ?= new Task(name)

	@destroy: (name) ->
		if name of @tasks
			Watcher.stop(@tasks[name].watchHandler)

			delete @tasks[name]

		return

	@status: ->
		now    = Date.now()
		status = {}

		for name, task of @tasks
			status[name] =
				count    : task.count
				source   : task.source
				restart  : task.restart
				subtasks : task.subtasks.map (subtask) ->
					pid    : subtask.pid
					args   : subtask.args
					status : subtask.status
					uptime : now - subtask.start

		return status

	log: ->
	active: yes

	constructor: (@name) ->
		@subtasks     = []
		@watchHandler = (error) =>
			if error
				@emit('error', error)
			else
				@restartSubtasks()

			return

		@on('exit', @exitHandler)

		return @

	# Upgrade task
	upgrade: (options = {}) ->
		restartRequired = no

		for own key of mutable
			try
				assert.deepEqual(@[key], options[key])
			catch change
				@upgradeParameter(key, options[key])

				# Force restart when one of non-mutable keys gets modified
				restartRequired = restartRequired or not mutable[key]

		# Restart existing
		if restartRequired and @subtasks.length
			@log("Restart required for #{@name} task group")

			@restartSubtasks()

		# Spawn required
		for index in [0...(@count or 0)]
			subtask = @subtasks[index]

			if not subtask or (subtask.status is 'R' and not subtask.pid)
				@spawn(index)

		# Kill redundant
		while @subtasks.length > (@count or 0)
			@stopSubtask(@subtasks.pop())

		return

	# Upgrade task parameter with given value
	upgradeParameter: (key, value) ->
		if value?
			@[key] = value
		else
			delete @[key]

		switch key
			when 'watch'
				Watcher.stop(@watchHandler)
				Watcher.start(@cwd, @watch or [], @watchHandler)

		return

	# Spawn subtask
	spawn: (id) ->
		args    = @arguments or []
		binary  = process.execPath
		subtask =
			id     : id
			status : 'W'
			name   : @name
			start  : Date.now()
			env    : @expandEnv()

		subtask.args = for argument in args
			if Array.isArray(argument) then argument[id] else argument

		eargs = subtask.args.slice()

		if @executable
			binary = @source
		else
			eargs.unshift(@source)

		subtask.process = fork(binary, eargs, {
			stdio : 'pipe'
			cwd   : resolve(@cwd)
			env   : subtask.env
		})

		subtask.pid = subtask.process.pid or 0

		if subtask.pid
			# Setup logger
			subtask.process.stdout.on('data', @logHandler.bind(@, subtask.pid))
			subtask.process.stderr.on('data', @logHandler.bind(@, subtask.pid))

			# Setup exit handler
			subtask.process.once('exit', @emit.bind(@, 'exit', subtask))

			@log("Task #{subtask.pid} (#{@name}) spawned")
		else
			subtask.status = 'E'
			subtask.code   = 255

			subtask.process.once('error', (error) => @emit('error', error))

			@log("Failed to start task (#{@name})")

		@subtasks[id] = subtask

		return

	# Call fn for each subtask
	foreach: (fn, argument) ->
		for subtask in @subtasks
			fn.call(@, subtask, argument)

		return

	# Kill subtask with signal
	killSubtask: (subtask, signal) ->
		if subtask and subtask.pid
			try
				subtask.process.kill(signal)
			catch error
				@log("Failed to kill #{subtask.pid} (#{subtask.name}) with #{signal}")

		return

	# Stop subtask
	stopSubtask: (subtask) ->
		if subtask and subtask.pid
			subtask.process.kill('SIGINT')

			setTimeout((->
				if subtask.pid
					subtask.process.kill('SIGTERM')
			), @timeout or 1000)

	# Restart subtask
	restartSubtask: (subtask) ->
		if subtask
			subtask.status = 'R'

			@stopSubtask(subtask)

		return

	# Get subtask by pid
	getPID: (pid) ->
		for subtask in @subtasks when subtask and subtask.pid is pid
			return subtask

		return

	# Kill subtask by pid with signal
	killPID: (pid, signal) ->
		if pid?
			@killSubtask(@getPID(pid), signal)
		else
			@killSubtasks(signal)

		return

	# Restart subtask by pid
	restartPID: (pid) ->
		if pid?
			@restartSubtask(@getPID(pid))
		else
			@restartSubtasks()

		return

	# Stop subtask by pid
	stopPID: (pid) ->
		if pid?
			@stopSubtask(@getPID(pid))
		else
			@stopSubtasks()

		return

	# Kill all subtasks
	killSubtasks: ->
		@foreach(@killSubtask)

		return

	# Restart all subtasks
	restartSubtasks: ->
		@foreach(@restartSubtask)

		return

	# Stop all subtasks
	stopSubtasks: ->
		@foreach(@stopSubtask)

		return

	# Drop task
	dropSubtasks: ->
		if @active
			@active = no

			unless @activeSubtasks().length
				Task.destroy(@name)
			else
				@stopSubtasks()

		return

	activeSubtasks: ->
		return @subtasks.filter((subtask) -> subtask.pid)

	exitHandler: (subtask, code, signal) ->
		restartRequired = @persistent

		if code is null
			@log("Task #{subtask.pid} (#{@name}) was killed by #{signal}")
		else
			@log("Task #{subtask.pid} (#{@name}) exited with code #{code}")

		subtask.pid    = 0
		subtask.code   = code
		subtask.signal = signal

		delete subtask.process

		if subtask.status isnt 'R'
			if code
				subtask.status = 'E'
			else if signal
				subtask.status = 'S'
			else
				subtask.status = 'D'

		if restartRequired and code
			elapsed = Date.now() - subtask.start

			if elapsed < (@runtime or 1000)
				@log("Restart skipped after #{elapsed}ms (#{@name})")

				restartRequired = no

		# Restart requested
		if subtask.status is 'R'
			restartRequired = yes

		# Task dropped
		unless @active
			restartRequired = no

			unless @activeSubtasks().length
				Task.destroy(@name)

		if restartRequired
			@spawn(subtask.id)

		return

	logHandler: (pid, data) ->
		@log("#{pid} (#{@name}) #{data}")

		return

	expandEnv: ->
		expanded = {}

		expanded.HOME = process.env.HOME
		expanded.PATH = process.env.PATH

		unless @executable
			expanded.NODE_PATH = process.env.NODE_PATH

		for own key, value of @env
			switch value
				when true
					if process.env.hasOwnProperty(key)
						expanded[key] = process.env[key]

				when false
					delete expanded[key]

				else
					expanded[key] = @env[key]

		return expanded

module.exports = Task
