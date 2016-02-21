assert  = require('assert')
weaver  = require('../lib/weaver.js')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58012
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

(require 'vows')
	.describe('path')
	.addBatch
		start:
			topic: ->
				# Write config
				write config, JSON.stringify
					path: '../lib'
					tasks:
						base:
							cwd: '../bin'
							count: 3
							executable: yes
							source: '../t/bin/sleep'
							arguments: [[3999, 4000, 4001]]

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
				stdout: (error, stdout, stderr) -> assert.equal stdout.length, 4

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
