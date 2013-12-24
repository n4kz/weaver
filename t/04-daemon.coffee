assert  = require('assert')
weaver  = require('../lib/weaver.js')
exec    = require('child_process').exec
daemon  = '../bin/weaver'
port    = 58004
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

(require 'vows')
	.describe('daemon')
	.addBatch
		version:
			topic: ->
				command = "#{daemon} --version"
				exec command, options, @callback
				return

			code:   (error, stdout, stderr) -> assert not error
			stderr: (error, stdout, stderr) -> assert not stderr
			stdout: (error, stdout, stderr) ->
				assert.include stdout, weaver.version

		help:
			topic: ->
				command = "#{daemon} --help"
				exec command, options, @callback
				return

			code:   (error, stdout, stderr) -> assert not error
			stdout: (error, stdout, stderr) -> assert not stdout
			stderr: (error, stdout, stderr) ->
				assert.include stderr, 'Usage'
				assert.include stderr, 'Commands'
				assert.include stderr, 'Options'

		status:
			topic: ->
				command = "#{daemon} status"
				exec command, options, @callback
				return

			code:   (error, stdout, stderr) -> assert error.code
			stdout: (error, stdout, stderr) -> assert not stdout
			stderr: (error, stdout, stderr) ->
				assert.include stderr, 'Could not connect'
				assert.include stderr, port

		start:
			topic: ->
				exec daemon, options, @callback
				return

			code:   (error, stdout, stderr) -> assert not error
			stdout: (error, stdout, stderr) -> assert not stdout
			stderr: (error, stdout, stderr) -> assert not stderr

			status:
				topic: ->
					command = "#{daemon} status --nocolor"
					exec command, options, @callback
					return

				code:    (error, stdout, stderr) -> assert not error
				stderr:  (error, stdout, stderr) -> assert not stderr
				version: (error, stdout, stderr) -> assert.include stdout, weaver.version
				name:    (error, stdout, stderr) -> assert.include stdout, 'weaver'
				pid:     (error, stdout, stderr) -> assert.match stdout, /^\s*\d+\s/
				memory:  (error, stdout, stderr) -> assert.match stdout, /\s\(\d+K\)/

			stop:
				topic: ->
					command = "#{daemon} exit"
					exec command, options, @callback
					return

				code:   (error, stdout, stderr) -> assert not error
				stdout: (error, stdout, stderr) -> assert not stdout
				stderr: (error, stdout, stderr) -> assert not stderr

				status:
					topic: ->
						command = "#{daemon} status"
						exec command, options, @callback
						return

					code:   (error, stdout, stderr) -> assert error.code
					stdout: (error, stdout, stderr) -> assert not stdout
					stderr: (error, stdout, stderr) ->
						assert.include stderr, 'Could not connect'
						assert.include stderr, port

	.export(module)
