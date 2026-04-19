import json
import os
import re

replacements = [
    # (file_path, old_string, new_string, key, en_val, ar_val)

]

for file_path, old_str, new_str, key, en_val, ar_val in replacements:
    path = os.path.join("/Users/user/project/mobile/awals", file_path)
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        if old_str in content:
            content = content.replace(old_str, new_str)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Replaced in {file_path}")

en_file = "/Users/user/project/mobile/awals/assets/lang/lang_en.json"
ar_file = "/Users/user/project/mobile/awals/assets/lang/lang_ar.json"

with open(en_file, "r") as f: en_data = json.load(f)
with open(ar_file, "r") as f: ar_data = json.load(f)

for _, _, _, key, en_val, ar_val in replacements:
    if key != "-":
        en_data[key] = en_val
        ar_data[key] = ar_val

with open(en_file, "w") as f: json.dump(en_data, f, ensure_ascii=False, indent=2)
with open(ar_file, "w") as f: json.dump(ar_data, f, ensure_ascii=False, indent=2)
print("Translations added to JSON files.")
