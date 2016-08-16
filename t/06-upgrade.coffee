assert  = require('assert')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58006
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

(require 'vows')
	.describe('upgrade')
	.addBatch
		start:
			topic: ->
				# Write empty config
				write config, JSON.stringify tasks: {}

				# Start daemon
				exec "#{daemon} --config #{config}", options, @callback
				return

			code:   (error, stdout, stderr) -> assert not error
			stdout: (error, stdout, stderr) -> assert not stdout
			stderr: (error, stdout, stderr) -> assert not stderr

			upgrade:
				topic: ->
					# Write new config
					write config, JSON.stringify
						tasks:
							base:
								count: 1
								executable: yes
								source: 'sleep'
								arguments: [1006]

					# Run upgrade command
					exec "#{daemon} --config #{config} upgrade", options, @callback
					return

				status:
					topic: ->
						# Check status
						exec "#{daemon} status --nocolor", options, @callback
						return

					code:   (error, stdout, stderr) -> assert not error
					stderr: (error, stdout, stderr) -> assert not stderr
					stdout: (error, stdout, stderr) ->
						status = stdout
							.replace(/\n$/, '')
							.split(/\n/)

						assert.equal status.length, 2
						assert.match status[1], /^ *\d+ +W +\d+s +base +sleep 1006/

					upgrade:
						topic: ->
							# Write new config with increased count and updated arguments
							write config, JSON.stringify
								tasks:
									base:
										count: 2
										executable: yes
										source: 'sleep'
										arguments: [2006]
									bonus:
										count: 1
										executable: yes
										source: 'uname'
										arguments: ['-a']

							# Run upgrade command
							exec "#{daemon} --config #{config} upgrade", options, @callback
							return

						status:
							topic: ->
								# Check status
								exec "#{daemon} status --nocolor", options, @callback
								return

							code:   (error, stdout, stderr) -> assert not error
							stderr: (error, stdout, stderr) -> assert not stderr
							stdout: (error, stdout, stderr) ->
								status = stdout
									.replace(/\n$/, '')
									.split(/\n/)

								assert.equal status.length, 4
								assert.match status[1], /^ *(\d+) +W +\d+s +base +sleep 2006/
								pid1 = +RegExp.$1

								assert.match status[2], /^ *(\d+) +W +\d+s +base +sleep 2006/
								pid2 = +RegExp.$1

								assert.match status[3], /^ *(\d+) +D +\d+s +bonus +uname -a/
								pid3 = +RegExp.$1

								assert.notEqual pid1, pid2
								assert.notEqual pid1, pid3
								assert.notEqual pid2, pid3
								assert.equal    pid3, 0

							upgrade:
								topic: ->
									# Write new config without old tasks
									write config, JSON.stringify
										tasks:
											new:
												count: 1
												executable: yes
												source: 'sleep'
												arguments: [1006]

									# Run upgrade command
									exec "#{daemon} --config #{config} upgrade", options, @callback
									return

								status:
									topic: ->
										# Check status
										exec "#{daemon} status --nocolor", options, @callback
										return

									code:   (error, stdout, stderr) -> assert not error
									stderr: (error, stdout, stderr) -> assert not stderr
									stdout: (error, stdout, stderr) ->
										status = stdout
											.replace(/\n$/, '')
											.split(/\n/)

										assert.equal status.length, 5
										assert.match status[1], /^ *(\d+) +W +\d+s +base +sleep 2006/
										pid1 = +RegExp.$1

										assert.match status[2], /^ *(\d+) +W +\d+s +base +sleep 2006/
										pid2 = +RegExp.$1

										assert.match status[3], /^ *(\d+) +D +\d+s +bonus +uname -a/
										pid3 = +RegExp.$1

										assert.match status[4], /^ *(\d+) +W +\d+s +new +sleep 1006/
										pid4 = +RegExp.$1

										assert.notEqual pid1, pid2
										assert.notEqual pid1, pid3
										assert.notEqual pid1, pid4
										assert.notEqual pid2, pid3
										assert.notEqual pid2, pid4
										assert.equal    pid3, 0
										assert.notEqual pid3, pid4

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
