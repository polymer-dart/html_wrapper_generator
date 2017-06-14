for idl in webidl/*.webidl ; do node parse.js $idl > json/all/$idl.json ; done
