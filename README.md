 1. launch `generate_json.sh` to parse webidl inside `webidl` folder and generate parsed json

 1. Examine the result inside `json/all/webidl` and move selected jsons to `json/webidl`, then launch

    dart bin/generate.dart json/webidl > html_gen.dart

 1. Replace `html_gen.dart` in `html5` library


