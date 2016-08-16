assert  = require('assert')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58007
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

status = []

(require 'vows')
	.describe('restart')
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
							arguments: [4007]
						s2:
							count: 2
							executable: yes
							source: 'sleep'
							arguments: [2007]

				# Start daemon
				exec "#{daemon} --config #{config}", options, @callback
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

				restart:
					topic: (pid) ->
						# Restart one task from first group by pid
						exec "#{daemon} restart #{pid[3]}", options, =>
							# Restart second group
							exec "#{daemon} restart s2", options, =>
								# Check status
								exec "#{daemon} status --nocolor", options, (args...) =>
									@callback(args..., pid)
						return

					code:   (error, stdout, stderr, pid) -> assert not error
					stderr: (error, stdout, stderr, pid) -> assert not stderr
					stdout: (error, stdout, stderr, pid) ->
						status = stdout
							.replace(/\n$/, '')
							.split(/\n/)
							.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

						assert.equal status.length, pid.length

						assert.equal    pid[1], status[1]
						assert.equal    pid[2], status[2]
						assert.notEqual pid[3], status[3]
						assert.equal    pid[4], status[4]
						assert.notEqual pid[5], status[5]
						assert.notEqual pid[6], status[6]

					exit:
						topic: ->
							# Remove config file
							unlink config

							# Stop daemon
							exec "#{daemon} exit", options, @callback
							return

						code:   (error, stdout, stderr) -> assert not error
						stdout: (error, stdout, stderr) -> assert not stdout
						stderr: (error, stdout, stderr) -> assert not stderr

	.export(module)
