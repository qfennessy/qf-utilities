# XML Wrapper

This bash script encapsulates a set of files for use in LLM (Language Model) prompting.

## Description

The XML Wrapper is a bash script that creates a simple output file containing the contents of non-binary files from a specified folder and its subfolders. Each file's content is encapsulated within XML-like tags using the filename.

## Features

- Encapsulates non-binary files in a target folder and subfolders
- Skips binary files, .git folders, .terraform folders, and other specified file types
- Respects .gitignore rules if present in the target directory
- Creates a unique output file for each run
- Allows specifying a target folder or defaults to the current directory
- Handles filenames with spaces and special characters

## Usage

```bash
./xml-wrapper.sh [folder_name]
```

If no folder name is provided, the script will process files in the current directory.

## Output

The script creates an output file in the `~/tmp/output/` directory. The filename includes a unique timestamp.

Each file's content in the output is wrapped in XML-like tags:

```xml
<filename>
(Contents of the file)
</filename>
```

## Requirements

- Bash shell
- Standard Unix tools: find, file, grep, sed, cat, basename

## Installation

1. Download the script to your local machine.
2. Make the script executable:
   ```bash
   chmod +x xml-wrapper.sh
   ```

## Notes

- The script will create the output directory if it doesn't exist.
- Binary files are automatically skipped.
- Excluded file types and folders: .git, .terraform, .ico, .otf, .jpg, .png, .pdf (configurable in the script)
- Additional exclusions can be added to the `EXCLUDED_PATTERNS` array in the script.
- The script respects .gitignore rules if a .gitignore file is present in the target directory.
- Filenames in the output are sanitized to replace non-alphanumeric characters (except ., _ and -) with underscores to avoid XML parsing issues.

## Error Handling

- If a specified folder doesn't exist, the script will output an error message and exit.
- The script uses `set -e` to exit immediately if any command fails.

## Output Location

The encapsulated files are saved in:

```
~/tmp/output/output_[timestamp].txt
```

Where `[timestamp]` is a unique identifier based on the current date and time.

## Debugging

- The script prints the constructed `find` command before execution for debugging purposes.
- It provides information about skipped binary files and processed files.

## Performance

- The script uses optimizations to handle large directories efficiently, such as pruning .terraform directories.

## Author

Quentin Fennessy (3 Sep 2024)

## Modifications

- Added support for .gitignore rules
- Improved handling of filenames with spaces and special characters
- Enhanced error checking and verbose output
- Optimized for performance with large directories