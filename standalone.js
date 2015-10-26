angular.module('standalone', [])
  .controller('StandaloneBroker', function() {
    var broker = this;
	var status = "Not connected!";
	
    broker.status = function() {
      return status;
    };
	
	broker.start = function() {
		status = "Started";
	};
	
	broker.stop = function() {
		status = "Stopped";
	};
  });