for idl in webidl/*.webidl ; do node parse.js $idl > json/$idl.json ; done
