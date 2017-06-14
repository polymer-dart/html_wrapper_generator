 1. Lanciare generate_json.sh per parsare i webidl e generare tutti i json.

 1. Dopo copiare quelli che interessano in webidl.all e langiare 

    dart bin/generate.dart json/webidl.all > html_gen.dart

 1. Infine copiare il file nella lib html5


