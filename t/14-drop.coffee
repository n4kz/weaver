assert  = require('assert')
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
						s3:
							count: 1
							executable: yes
							source: 'uname'
							arguments: ['-a']

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
				stdout: (error, stdout, stderr) -> assert.equal stdout.length, 8

				drop:
					topic: (pid) ->
						# Drop second group
						exec "#{daemon} drop s2", options, =>
							# Get configuration dump
							exec "#{daemon} dump", options, (args...) =>
								dump = JSON.parse args[1]

								# Check status
								exec "#{daemon} status", options, (args...) =>
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

						assert.equal status.length, 6

						assert.match stdout, /^(?:[\s\S](?!s2))+$/

						assert.equal pid[1], status[1]
						assert.equal pid[2], status[2]
						assert.equal pid[3], status[3]
						assert.equal pid[4], status[4]
						assert.equal      0, status[5]

					drop:
						topic: (stdout, stderr, pid) ->
							# Drop finished task
							exec "#{daemon} drop s3", options, =>
								# Check status
								exec "#{daemon} status", options, (args...) =>
									@callback(args..., pid)

							return

						code:   (error, stdout, stderr, pid) -> assert not error
						stderr: (error, stdout, stderr, pid) -> assert not stderr
						stdout: (error, stdout, stderr, pid) ->
							status = stdout
								.replace(/\n$/, '')
								.split(/\n/)
								.map(($_) -> +/^\s*(\d+)/.exec($_)[1])

							assert.equal status.length, 5
							assert.match stdout, /^(?:[\s\S](?!s[23]))+$/

							assert.equal pid[1], status[1]
							assert.equal pid[2], status[2]
							assert.equal pid[3], status[3]
							assert.equal pid[4], status[4]

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
