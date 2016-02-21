assert  = require('assert')
weaver  = require('../lib/weaver.js')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58013
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

(require 'vows')
	.describe('binary')
	.addBatch
		start:
			topic: ->
				# Write config
				write config, JSON.stringify
					path: '../lib'
					tasks:
						base:
							count: 1
							executable: yes
							source: 'bin/borken'

				# Start daemon
				command = "#{daemon} --config #{config}"
				exec command, options, @callback
				return

			code:   (error, stdout, stderr) -> assert not error
			stdout: (error, stdout, stderr) -> assert not stdout
			stderr: (error, stdout, stderr) -> assert not stderr

			status:
				topic: ->
					# Check status
					exec "#{daemon} status --nocolor", options, (args...) =>
						args[1] = args[1]
							.replace(/\n$/, '')
							.split(/\n/)
							.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

						@callback(args...)
					return

				code:   (error, stdout, stderr) -> assert not error
				stderr: (error, stdout, stderr) -> assert not stderr
				stdout: (error, stdout, stderr) -> assert.equal stdout.length, 2
				pid:    (error, stdout, stderr) -> assert.equal stdout[1], 0

				exit:
					topic: ->
						# Remove config file
						unlink config

						# Stop daemon
						command = "#{daemon} exit"
						exec command, options, @callback
						return

					code:   (error, stdout, stderr) -> assert not error
					stdout: (error, stdout, stderr) -> assert not stdout
					stderr: (error, stdout, stderr) -> assert not stderr
	.export(module)
