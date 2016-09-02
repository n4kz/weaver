glob = require('glob')
fs   = require('fs')
util = require('util')

watches = Object.create(null)
watcher = Object.create(null)

class Watcher
	log: ->

	start: (cwd, patterns, callback) ->
		fn      = @watch.bind(@, cwd, callback)
		options =
			cwd     : cwd
			nomount : yes

		for pattern in patterns
			glob(pattern, options, fn)

		return

	stop: (callback) ->
		for file of watches
			watches[file] = watches[file]
				.filter (item) -> item isnt callback

			unless watches[file]
				# Stop watching file completely
				watcher[file].close()

				delete watches[file]
				delete watcher[file]

		return

	watch: (cwd, callback, error, files) ->
		if error
			callback(error)
			return

		for file in files
			if file[0] isnt '/'
				# Expand to full path
				file = cwd + '/' + file

			callbacks = watches[file]

			if callbacks
				# Add callback to watches
				callbacks.push(callback)
			else
				# Start watching file
				watches[file] = [callback]
				watcher[file] = fs.watch(file, persistent: no, @watchHandler.bind(@, file))

		return

	watchHandler: (file, event) ->
		if file of watches
			@log("File #{file} changed")

			for callback in watches[file]
				callback(null)

		return

module.exports = new Watcher()
