webidl = require('webidl2');
fs = require('fs');

fs.readFile(process.argv[2], 'utf8', function(err, data) {
	if (err) {
		return;
	}
	res = webidl.parse(data);
	s = JSON.stringify(res);
	console.log(s);

});
