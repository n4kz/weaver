glob = require('glob')
fs   = require('fs')
util = require('util')

watches = Object.create(null)
watcher = Object.create(null)

watchHandler = (file, event) ->
	# TODO: Log changed file

	for callback in watches[file] or []
		callback(null)

	return

watch = (cwd, callback, error, files) ->
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
			watcher[file] = fs.watch(file, watchHandler.bind(undefined, file))

	return

class Watcher
	start: (cwd, patterns, callback) ->
		fn      = watch.bind(undefined, cwd, callback)
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

module.exports = Watcher
