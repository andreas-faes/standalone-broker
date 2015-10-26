angular.module('standalone', [])
  .controller('StandaloneBroker', function() {
    var broker = this;
	var logStuff = ["Log1", "Log2", "Log3"];
	status = "Not connected";

    broker.status = function() {
      return status;
    };
	
	broker.start = function() {
	    broker.logs.push({text: "Broker status: Starting", level: "DEBUG", time: Date() });
		return "Starting";
	};
	
	broker.stop = function() {
		broker.logs.push({text: "Broker status: Stopping", level: "DEBUG", time: Date() });
		return "Stopping";
	};
	
	broker.logs = [];
  });