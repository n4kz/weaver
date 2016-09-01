assert  = require('assert')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58010
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

configData = JSON.stringify
	tasks:
		base:
			count: 2
			executable: yes
			source: 'sleep'
			watch: [config]
			arguments: [2010]

status = []

(require 'vows')
	.describe('watch')
	.addBatch
		start:
			topic: ->
				# Write config
				write config, configData

				# Start daemon
				exec "#{daemon} --config #{config}", options, @callback
				return

			code:   (error, stdout, stderr) -> assert not error
			stdout: (error, stdout, stderr) -> assert not stdout
			stderr: (error, stdout, stderr) -> assert not stderr

			status:
				topic: ->
					# Check status
					exec "#{daemon} status", options, (args...) =>
						args[1] = args[1]
							.replace(/\n$/, '')
							.split(/\n/)
							.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

						@callback(args...)
					return

				code:   (error, stdout, stderr) -> assert not error
				stderr: (error, stdout, stderr) -> assert not stderr
				stdout: (error, stdout, stderr) -> assert.equal stdout.length, 3

				watch:
					topic: (pid) ->
						# Rewrite config
						write config, configData
						exec "#{daemon} status", options, (args...) => @callback(args..., pid)
						return

					code:   (error, stdout, stderr, pid) -> assert not error
					stderr: (error, stdout, stderr, pid) -> assert not stderr
					stdout: (error, stdout, stderr, pid) ->
						status = stdout
							.replace(/\n$/, '')
							.split(/\n/)
							.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

						assert.equal status.length, pid.length

						assert.notEqual pid[1], status[1]
						assert.notEqual pid[2], status[2]
						assert status[1]
						assert status[2]

					status:
						topic: ->
							# Check status
							exec "#{daemon} status", options, (args...) =>
								args[1] = args[1]
									.replace(/\n$/, '')
									.split(/\n/)
									.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

								@callback(args...)
							return

						code:   (error, stdout, stderr) -> assert not error
						stderr: (error, stdout, stderr) -> assert not stderr
						stdout: (error, stdout, stderr) -> assert.equal stdout.length, 3

						watch:
							topic: (pid) ->
								# Rewrite config
								write config, configData
								exec "#{daemon} status", options, (args...) => @callback(args..., pid)
								return

							code:   (error, stdout, stderr, pid) -> assert not error
							stderr: (error, stdout, stderr, pid) -> assert not stderr
							stdout: (error, stdout, stderr, pid) ->
								status = stdout
									.replace(/\n$/, '')
									.split(/\n/)
									.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

								assert.equal status.length, pid.length

								assert.notEqual pid[1], status[1]
								assert.notEqual pid[2], status[2]
								assert status[1]
								assert status[2]

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
