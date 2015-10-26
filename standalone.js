angular.module('standalone', [])
  .controller('StandaloneBroker', function() {
    var broker = this;
  
    broker.status = function() {
      return "Not connected";
    };
  });