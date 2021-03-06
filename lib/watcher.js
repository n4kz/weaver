// Generated by CoffeeScript 1.11.0
var Watcher, fs, glob, util, watcher, watches;

glob = require('glob');

fs = require('fs');

util = require('util');

watches = Object.create(null);

watcher = Object.create(null);

Watcher = (function() {
  function Watcher() {}

  Watcher.prototype.log = function() {};

  Watcher.prototype.start = function(cwd, patterns, callback) {
    var fn, i, len, options, pattern;
    fn = this.watch.bind(this, cwd, callback);
    options = {
      cwd: cwd,
      nomount: true
    };
    for (i = 0, len = patterns.length; i < len; i++) {
      pattern = patterns[i];
      glob(pattern, options, fn);
    }
  };

  Watcher.prototype.stop = function(callback) {
    var file;
    for (file in watches) {
      watches[file] = watches[file].filter(function(item) {
        return item !== callback;
      });
      if (!watches[file]) {
        watcher[file].close();
        delete watches[file];
        delete watcher[file];
      }
    }
  };

  Watcher.prototype.watch = function(cwd, callback, error, files) {
    var callbacks, file, i, len;
    if (error) {
      callback(error);
      return;
    }
    for (i = 0, len = files.length; i < len; i++) {
      file = files[i];
      if (file[0] !== '/') {
        file = cwd + '/' + file;
      }
      callbacks = watches[file];
      if (callbacks) {
        callbacks.push(callback);
      } else {
        watches[file] = [callback];
        watcher[file] = fs.watch(file, {
          persistent: false
        }, this.watchHandler.bind(this, file));
      }
    }
  };

  Watcher.prototype.watchHandler = function(file, event) {
    var callback, i, len, ref;
    if (file in watches) {
      this.log("File " + file + " changed");
      ref = watches[file];
      for (i = 0, len = ref.length; i < len; i++) {
        callback = ref[i];
        callback(null);
      }
    }
  };

  return Watcher;

})();

module.exports = new Watcher();
