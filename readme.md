# Weaver

Interactive process management system for node.js

# Usage

    weaver [--port <number>] [--config <path>] [--debug] [start]
    weaver [--port <number>] [--config <path>] upgrade
    weaver [--port <number>] <restart|stop> [[task|pid], ...]
    weaver [--port <number>] kill <signal> [[task|pid], ...]
    weaver [--port <number>] [--nocolor] status
    weaver [--port <number>] exit

# Commands

	start
		Start daemon if it was not started before. Default command

	upgrade
		Change or re-read config file

	restart
		Restart all tasks, task group, task by pid

	stop
		Stop all tasks, task group, task by pid

	kill
		Send signal to task group or task by pid

	status
		Show status for all tasks

	exit
		Stop all tasks and exit

# Options

	--config   Configuration file. Required to start daemon with predefined tasks
	--debug    Do not fork and give additional output. Makes sense only for start  [boolean]
	--nocolor  Do not use colors for output                                        [boolean]
	--help     Show help                                                           [boolean]
	--port     Use specified port                                                  [default: 8092]

# Configuration example

	{
		"path": "..",
		"tasks": {
			"web": {
				"count": 2,
				"source": "lib/main.js",
				"persistent": false,
				"arguments": ["--web", "--port", [8001, 8002]],
				"watch": ["lib/**/*.js", "config/default.js", "config/local.json"],
				"env": {
					"NODE_ENV": "local"
				}
			},

			"worker": {
				"count": 1,
				"timeout": 2000,
				"source": "lib/main.js",
				"persistent": false,
				"arguments": ["--worker"],
				"watch": ["lib/worker/*.js"],
				"env": {
					"NODE_ENV": "local"
				}
			}
		}
	}

With such config file weaver will run three processes and restart them when one of watched files is modified.
Processes are organized in two groups and can be managed by group name. For example to restart web processes you need to say

	weaver restart web

and to stop worker

	weaver stop worker

Processes in web group get different command line arguments but similar environment. By default tasks have access to PATH, NODE_PATH and HOME
environment variables.

Bash commands to start processes manually in same way as weaver does in example above

	NODE_ENV="local" node ../lib/main.js --web --port 8001
	NODE_ENV="local" node ../lib/main.js --web --port 8002
	NODE_ENV="local" node ../lib/main.js --worker

# Configuration file structure

	path
		Path to working directory, relative to configuration file or absolute

	tasks
		Task groups

	count
		Task count for group

	source
		Source file for task group

	persistent
		Restart task on unclean exit. Optional

	arguments
		Arguments for tasks in task group. Nested array should have length equal to task count. Optional

	env
		Environment variables for task group. Optional

	watch
		Restart all tasks in task group when one of watched files was modified. Optional

	timeout
		Timeout between SIGINT and SIGTERM for stop and restart commands. Defaults to 1000ms. Optional
