assert  = require('assert')
exec    = require('child_process').exec
spawn   = require('child_process').spawn
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58015
config  = "#{__dirname}/weaver_#{port}.json"
random1 = String(Math.random())
random2 = String(Math.random())
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		RND1: random1
		RND2: random2
		WEAVER_TEST: 1
		WEAVER_PORT: port

log = ''

monitor = spawn daemon, ['monitor'], options
monitor.stdout.on 'data', (data) -> log += String(data)

(require 'vows')
	.describe('env')
	.addBatch
		start:
			topic: ->
				# Write config
				write config, JSON.stringify
					tasks:
						dump:
							count: 1
							executable: yes
							source: 'bin/env'
							env:
								RND2 : yes
								RND3 : yes
								HOME : no
								PORT : String(port)

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

						setTimeout((=>
							@callback(args...)
						), 250)
					return

				code:   (error, stdout, stderr) -> assert not error
				stderr: (error, stdout, stderr) -> assert not stderr
				stdout: (error, stdout, stderr) -> assert.equal stdout.length, 2

				env: (error, stdout, stderr) ->
					if /^(\d+) \(dump\) ({.+})/m.exec(log)
						pid = RegExp.$1
						env = JSON.parse(RegExp.$2)
					else
						assert 0, 'UDP log failed'

					assert.equal env.PORT, port
					assert.equal env.PATH, process.env.PATH
					assert.equal env.$PID, pid
					assert.equal env.RND2, random2
					assert not env.hasOwnProperty 'HOME'
					assert not env.hasOwnProperty 'RND1'
					assert not env.hasOwnProperty 'RND3'

				exit:
					topic: ->
						# Remove config file
						unlink config

						# Stop monitor
						monitor.kill('SIGTERM')

						# Stop daemon
						exec "#{daemon} exit", options, @callback
						return

					code:   (error, stdout, stderr) -> assert not error
					stdout: (error, stdout, stderr) -> assert not stdout
					stderr: (error, stdout, stderr) -> assert not stderr
	.export(module)
