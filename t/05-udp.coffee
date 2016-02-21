assert  = require('assert')
weaver  = require('../lib/weaver.js')
exec    = require('child_process').exec
spawn   = require('child_process').spawn
daemon  = '../bin/weaver'
port    = 58005
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

log = ''

monitor = spawn daemon, ['monitor'], options
monitor.stdout.on 'data', (data) -> log = String(data)

(require 'vows')
	.describe('udp')
	.addBatch
		start:
			topic: ->
				exec daemon, options, (args...) =>
					setTimeout((=>
						@callback(args...)
					), 50)

				return

			code:   (error, stdout, stderr) -> assert not error
			stdout: (error, stdout, stderr) -> assert not stdout
			stderr: (error, stdout, stderr) -> assert not stderr
			log:    (error, stdout, stderr) -> assert.match log, /started/i

			exit:
				topic: ->
					command = "#{daemon} exit"
					exec command, options, (args...) =>
						# Wait for message to arrive
						setTimeout((=>
							# Remove zombie
							monitor.kill('SIGTERM')

							# Run tests
							@callback(args...)
						), 50)
					return

				code:   (error, stdout, stderr) -> assert not error
				stdout: (error, stdout, stderr) -> assert not stdout
				stderr: (error, stdout, stderr) -> assert not stderr
				log:    (error, stdout, stderr) -> assert.match log, /terminated/i

	.export(module)
