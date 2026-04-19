import json
import os
import re
from collections import defaultdict

TOOLS_DIR = os.path.dirname(__file__)
REPO_ROOT = os.path.abspath(os.path.join(TOOLS_DIR, '..'))
PROJECT_ROOT = os.path.join(REPO_ROOT, 'lib')
EN_JSON = os.path.join(REPO_ROOT, 'assets', 'lang', 'en.json')
AR_JSON = os.path.join(REPO_ROOT, 'assets', 'lang', 'ar.json')
OUTPUT_FILE = os.path.join(TOOLS_DIR, 'untranslated_strings.txt')

EXCLUDE_DIRS = {
    'build', 'assets', 'test', 'windows', 'macos', 'linux', 'web',
    'android', 'ios', '.dart_tool', '.idea', '.git', 'localization'
}
EXCLUDE_KEYWORDS = [
    'assets/', 'asset/', 'http://', 'https://', 'services/', 'service/',
    'model/', 'models/'
]
EXCLUDE_FILES = ['api_service', 'service_', 'date', 'firebase_options', 'app_translations']
EXCLUDE_FILE_SUFFIXES = ('.g.dart', '.freezed.dart')
LITERAL_SCAN_EXCLUDE_PATHS = [
    os.path.join('lib', 'core', 'services', 'database_service.dart'),
    os.path.join('lib', 'core', 'services', 'backup_restore_service.dart'),
    os.path.join('lib', 'core', 'services', 'notification_service.dart'),
    os.path.join('lib', 'core', 'services', 'recurring_transaction_service.dart'),
    os.path.join('lib', 'core', 'services', 'app_lock_service.dart'),
    os.path.join('lib', 'core', 'utils', 'url_launcher_utils.dart'),
]
STRING_PATTERN = re.compile(r'(?<![\w.])(["\'])(?:\\.|(?!\1).)*\1')
TR_CALL_PATTERN = re.compile(r'(["\'])([^"\']+)\1\s*\.tr\(')
IMPORT_PATTERN = re.compile(r'^\s*import\s+')
DEBUG_LINE_PATTERN = re.compile(r'\b(print|debugPrint|log)\s*\(')
ASSET_EXT_PATTERN = re.compile(r'\.(png|jpe?g|gif|webp|svg|json|avif|ttf)\b', re.IGNORECASE)
API_PATH_PATTERN = re.compile(r'^\s*/')
DB_FILE_PATTERN = re.compile(r'^[A-Za-z0-9_\-]+\.db$')
DART_FILE_PATTERN = re.compile(r'^[A-Za-z0-9_\-./]+\.dart$')
RESOURCE_REF_PATTERN = re.compile(r'^@[\w/.-]+$')
TOKEN_PATTERN = re.compile(r'^[A-Za-z0-9_\-]{25,}$')
LOWER_IDENTIFIER_PATTERN = re.compile(r'^[a-z0-9_\-/]{2,}$')
INTERPOLATION_TOKEN_PATTERN = re.compile(r'(\$\{[^}]*\}|\$[A-Za-z_]\w*)')
EMAIL_PATTERN = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
MAP_INDEX_ACCESS_PATTERN = re.compile(r'\[\s*(["\'])\w+\1\s*\]')
IDENTIFIER_PATTERN = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
STORAGE_CONTEXT_PATTERN = re.compile(
    r'\b(Hive|GetStorage|SharedPreferences|prefs|pref|storage|box)\b|\.\s*(read|write|remove|delete|put)\s*\(',
    re.IGNORECASE,
)
FONT_CONTEXT_PATTERN = re.compile(r'\bfontFamily\b', re.IGNORECASE)
COUNTRY_CODE_PATTERN = re.compile(r'^[A-Z]{2}$')
CURRENCY_CODE_PATTERN = re.compile(r'^[A-Z]{3,4}$')
TIME_PATTERN = re.compile(r'^\d{1,2}:\d{2}(?:\s*[AP]M)?$', re.IGNORECASE)
DATE_FORMAT_PATTERN = re.compile(r'^[yYMdDEeHhmsaSkK:\/\-\s,\.\u2022]+$')
CAMEL_CASE_PATTERN = re.compile(r'^(?=.*[a-z])(?=.*[A-Z])[A-Za-z0-9]+$')
LOCALIZATION_KEY_PATTERN = re.compile(r'^[a-z]+(?:\.[a-z0-9_]+)+$')
APP_NAME_PATTERN = re.compile(r'^Expensia(?:\s+pro)?$', re.IGNORECASE)
SQL_CONTEXT_PATTERN = re.compile(
    r'\b(rawQuery|rawUpdate|rawInsert|db\.query|db\.update|txn\.query|txn\.update|whereArgs|where:|orderBy:)\b'
)
SQL_TEXT_PATTERN = re.compile(
    r'^(SELECT|UPDATE|INSERT|DELETE|ALTER|CREATE|DROP|PRAGMA|REPLACE|WITH)\b|'
    r'\b(WHERE|ORDER BY|LEFT JOIN|INNER JOIN|VALUES|SET)\b|'
    r'^\w+\s*=\s*\?$',
    re.IGNORECASE,
)


def flatten_translations(data, prefix=''):
    flattened = {}
    for key, value in data.items():
      full_key = f'{prefix}.{key}' if prefix else key
      if isinstance(value, dict):
          flattened.update(flatten_translations(value, full_key))
      else:
          flattened[full_key] = value
    return flattened


def load_translation_keys():
    with open(EN_JSON, encoding='utf-8') as en_file:
        en_data = json.load(en_file)
    with open(AR_JSON, encoding='utf-8') as ar_file:
        ar_data = json.load(ar_file)
    return flatten_translations(en_data), flatten_translations(ar_data)


def find_untranslated_strings():
    results = []
    for root, dirs, files in os.walk(PROJECT_ROOT):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for file in files:
            if (
                not file.endswith('.dart')
                or file.endswith(EXCLUDE_FILE_SUFFIXES)
                or any(ex in file for ex in EXCLUDE_FILES)
            ):
                continue

            file_path = os.path.join(root, file)
            relative_path = os.path.relpath(file_path, REPO_ROOT)
            normalized_relative_path = relative_path.replace('\\', os.sep)
            if any(normalized_relative_path.endswith(path) for path in LITERAL_SCAN_EXCLUDE_PATHS):
                continue
            if f'{os.sep}providers{os.sep}' in normalized_relative_path:
                continue

            with open(file_path, encoding='utf-8') as f:
                in_block_comment = False
                for i, line in enumerate(f, 1):
                    stripped = line.lstrip()
                    if in_block_comment:
                        if '*/' in line:
                            in_block_comment = False
                        continue
                    if stripped.startswith('//'):
                        continue
                    if '/*' in line:
                        if '*/' not in line or line.index('/*') < line.index('*/'):
                            in_block_comment = True
                            continue
                    if IMPORT_PATTERN.match(line):
                        continue
                    if DEBUG_LINE_PATTERN.search(line):
                        continue
                    if FONT_CONTEXT_PATTERN.search(line):
                        continue
                    if SQL_CONTEXT_PATTERN.search(line):
                        continue

                    for match in STRING_PATTERN.finditer(line):
                        text = match.group(0)
                        content = text.strip('"\'')
                        if '.tr(' in line:
                            continue
                        if any(keyword in text for keyword in EXCLUDE_KEYWORDS):
                            continue
                        if ASSET_EXT_PATTERN.search(content):
                            continue
                        if API_PATH_PATTERN.match(content):
                            continue
                        if EMAIL_PATTERN.match(content):
                            continue
                        if DB_FILE_PATTERN.match(content):
                            continue
                        if APP_NAME_PATTERN.match(content):
                            continue
                        if DART_FILE_PATTERN.match(content):
                            continue
                        if RESOURCE_REF_PATTERN.match(content):
                            continue
                        if TOKEN_PATTERN.match(content):
                            continue
                        if COUNTRY_CODE_PATTERN.match(content):
                            continue
                        if CURRENCY_CODE_PATTERN.match(content):
                            continue
                        if TIME_PATTERN.match(content):
                            continue
                        if LOCALIZATION_KEY_PATTERN.match(content):
                            continue
                        if SQL_TEXT_PATTERN.search(content):
                            continue
                        if DATE_FORMAT_PATTERN.match(content) and any(ch.isalpha() for ch in content):
                            continue
                        if 'nameNative' in line:
                            continue
                        if 'currencyNameEn' in line:
                            continue
                        if '_getDaySuffix' in line:
                            continue
                        if '${' in content and 'currencyCode' in content and 'countryCode' in content:
                            continue
                        if content.strip().isdigit():
                            continue
                        if content.count('${') != content.count('}'):
                            continue
                        if MAP_INDEX_ACCESS_PATTERN.search(line):
                            indexed_access = r'\[\s*' + re.escape(text[0]) + re.escape(content) + re.escape(text[0]) + r'\s*\]'
                            if re.search(indexed_access, line):
                                continue
                        if STORAGE_CONTEXT_PATTERN.search(line) and IDENTIFIER_PATTERN.match(content):
                            continue
                        if CAMEL_CASE_PATTERN.match(content):
                            continue
                        if LOWER_IDENTIFIER_PATTERN.match(content) and (
                            '_' in content or '/' in content or '-' in content or content.islower()
                        ):
                            if ' ' not in content:
                                continue
                        if line[match.end():].lstrip().startswith(':'):
                            continue
                        content_without_vars = INTERPOLATION_TOKEN_PATTERN.sub('', content)
                        content_without_vars = re.sub(r'[\s\d\W]+', '', content_without_vars)
                        if content_without_vars == '' or len(content) < 2:
                            continue
                        results.append({'file': file_path, 'line': i, 'text': text})
    return results


def find_translation_key_usages():
    usages = []
    for root, dirs, files in os.walk(PROJECT_ROOT):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for file in files:
            if not file.endswith('.dart'):
                continue

            file_path = os.path.join(root, file)
            with open(file_path, encoding='utf-8') as f:
                for i, line in enumerate(f, 1):
                    for match in TR_CALL_PATTERN.finditer(line):
                        usages.append({
                            'file': file_path,
                            'line': i,
                            'key': match.group(2),
                        })
    return usages


def find_missing_translation_keys():
    en_keys, ar_keys = load_translation_keys()
    key_usages = find_translation_key_usages()
    missing = []

    seen = set()
    for usage in key_usages:
        key = usage['key']
        if key in seen:
            continue
        seen.add(key)

        missing_locales = []
        if key not in en_keys:
            missing_locales.append('en')
        if key not in ar_keys:
            missing_locales.append('ar')

        if missing_locales:
            usage['missing_locales'] = missing_locales
            missing.append(usage)
    return missing


def group_by_file(entries):
    grouped = defaultdict(list)
    for entry in entries:
        grouped[entry['file']].append(entry)
    return dict(sorted(grouped.items()))


def write_report(untranslated, missing_keys):
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as out:
        out.write('Translation Audit Report\n')
        out.write('=' * 80 + '\n\n')

        out.write('Missing translation keys referenced in .tr()\n')
        out.write('-' * 80 + '\n')
        if not missing_keys:
            out.write('None\n\n')
        else:
            for file_path, entries in group_by_file(missing_keys).items():
                out.write(f'{file_path}\n')
                for entry in entries:
                    locales = ', '.join(entry['missing_locales'])
                    out.write(f"  line {entry['line']}: {entry['key']}  [missing in: {locales}]\n")
                out.write('\n')

        out.write('Potential untranslated literal strings in Dart files\n')
        out.write('-' * 80 + '\n')
        if not untranslated:
            out.write('None\n')
        else:
            for file_path, entries in group_by_file(untranslated).items():
                out.write(f'{file_path}\n')
                for entry in entries:
                    out.write(f"  line {entry['line']}: {entry['text']}\n")
                out.write('\n')


def main():
    untranslated = find_untranslated_strings()
    missing_keys = find_missing_translation_keys()
    write_report(untranslated, missing_keys)

    print(f'Report written to {OUTPUT_FILE}')
    print(f'Potential untranslated strings: {len(untranslated)}')
    print(f'Missing translation keys: {len(missing_keys)}')


if __name__ == '__main__':
    main()
