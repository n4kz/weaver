assert  = require('assert')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58009
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

status = []

(require 'vows')
	.describe('kill')
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
							arguments: [4009]
						s2:
							count: 2
							executable: yes
							source: 'sleep'
							arguments: [2009]

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

				kill:
					topic: (pid) ->
						# Kill one task from first group by pid
						exec "#{daemon} kill SIGINT #{pid[2]}", options, =>
							# Kill second group
							exec "#{daemon} kill SIGTERM s2", options, =>
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
						assert.equal stdout.split(' 0 S ').length, 4

						assert.equal pid[1], status[1]
						assert.equal      0, status[2]
						assert.equal pid[3], status[3]
						assert.equal pid[4], status[4]
						assert.equal      0, status[5]
						assert.equal      0, status[6]

					exit:
						topic: ->
							# Remove config file
							unlink(config)

							# Stop daemon
							exec "#{daemon} exit", options, @callback
							return

						code:   (error, stdout, stderr) -> assert not error
						stdout: (error, stdout, stderr) -> assert not stdout
						stderr: (error, stdout, stderr) -> assert not stderr

	.export(module)
