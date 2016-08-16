assert  = require('assert')
exec    = require('child_process').exec
write   = require('fs').writeFileSync
unlink  = require('fs').unlinkSync
daemon  = '../bin/weaver'
port    = 58011
config  = "#{__dirname}/weaver_#{port}.json"
options =
	cwd: __dirname
	env:
		PATH: process.env.PATH
		WEAVER_TEST: 1
		WEAVER_PORT: port

(require 'vows')
	.describe('cwd')
	.addBatch
		start:
			topic: ->
				# Write config
				write config, JSON.stringify
					tasks:
						base:
							cwd: '..'
							count: 2
							executable: yes
							source: 't/bin/sleep'
							arguments: [[2011, 2111]]

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
				stdout: (error, stdout, stderr) -> assert.equal stdout.length, 3

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
