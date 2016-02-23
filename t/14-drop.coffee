assert  = require('assert')
weaver  = require('../lib/weaver.js')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58014
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

status = []

(require 'vows')
	.describe('drop')
	.addBatch
		start:
			topic: ->
				# Write config
				write config, JSON.stringify
					tasks:
						s1:
							count: 4
							executable: yes
							source: 'sleep'
							arguments: [4014]
						s2:
							count: 2
							executable: yes
							source: 'sleep'
							arguments: [2014]

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
				stdout: (error, stdout, stderr) -> assert.equal stdout.length, 7

				drop:
					topic: (pid) ->
						# Drop second group
						exec "#{daemon} drop s2", options, =>
							# Get configuration dump
							exec "#{daemon} dump --nocolor", options, (args...) =>
								dump = JSON.parse args[1]

								# Check status
								exec "#{daemon} status --nocolor", options, (args...) =>
									@callback(args..., pid, dump)
						return

					code:   (error, stdout, stderr, pid, dump) -> assert not error
					dump:   (error, stdout, stderr, pid, dump) -> assert not dump.hasOwnProperty 's2'
					stderr: (error, stdout, stderr, pid, dump) -> assert not stderr
					stdout: (error, stdout, stderr, pid, dump) ->
						status = stdout
							.replace(/\n$/, '')
							.split(/\n/)
							.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

						assert.equal status.length, 5

						assert.match stdout, /^(?:[\s\S](?!s2))+$/

						assert.equal pid[1], status[1]
						assert.equal pid[2], status[2]
						assert.equal pid[3], status[3]
						assert.equal pid[4], status[4]

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
