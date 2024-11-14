#!/bin/bash
# Encapsulate a set of files for use in LLM prompting.
# Quentin Fennessy 3 Sep 2024 with help from my invisible friends
# Create a simple output file that encapsulates non-binary files in target folders and subfolders.
# Encapsulate using xml tags like this:
#  <main.tf>
#  (Contents of main.tf)
#  </main.tf>

set -e  # Exit immediately if a command exits with a non-zero status.

# Function to display usage
usage() {
    echo "Usage: $0 [--folder <folder_path> ...] [file1 file2 ...]"
    echo
    echo "Options:"
    echo "  --folder <folder_path>  Specify one or more folders to process all files within them"
    echo "  file1 file2 ...         Specify individual files to process"
    echo
    echo "You must provide at least one folder with --folder or at least one file to process."
    echo "The script will create an output file in ~/tmp/output/ with the processed content."
}

# Define excluded files and folders
EXCLUDED_PATTERNS=(
    "*.git*"           # Exclude .git folders and files
    "*.terraform*"     # Exclude .terraform folders and files
    "*.ico"            # Exclude .ico files
    "*.otf"            # Exclude font files
    "*.jpg"            # Exclude .jpg files
    "*.png"            # Exclude .png files
    "*.pdf"            # Exclude .pdf files
    "*.zip"            # Exclude .zip files
    "*.tgz"            # Exclude .compressed tar files
    "*.tar"            # Exclude .tar files
    "*.gz"             # Exclude .gz files
    ".DS_Store"
    "__pycache__/*"
    "package-lock.json"
    "output/*"
    ".venv/*"
    "mypy_cache/
    # Add more patterns here as needed
)

# Ensure output directory exists; create it if not
OUTPUTDIR=~/tmp/output
mkdir -p ${OUTPUTDIR}

# Function to process a single file
process_file() {
    local file="$1"
    # Check if the file is binary
    if file "$file" | grep -q 'binary'; then
        echo "Skipping binary file: $file" >&2
        return
    fi
    # Extract filename without path
    filename=$(basename "$file" | sed 's/[^a-zA-Z0-9._-]/_/g')
    echo "Processing file: $file" >&2
    # Emit XML tags with filename and contents
    echo "<$filename>"
    cat "$file"
    echo "</$filename>"
}

# Check if no arguments are provided
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# Parse command line arguments
folders=()
files=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --folder)
            if [ -z "$2" ] || [[ "$2" == --* ]]; then
                echo "$0: Error: --folder requires a path argument." >&2
                exit 1
            fi
            folders+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            files+=("$1")
            shift
            ;;
    esac
done

# Check if at least one folder or file is provided
if [ ${#folders[@]} -eq 0 ] && [ ${#files[@]} -eq 0 ]; then
    echo "$0:Error: No folders specified and no files provided." >&2
    usage
    exit 1
fi

# Set the search paths
if [ ${#folders[@]} -gt 0 ]; then
    # echo "Number of folders: ${#folders[@]}"
    # echo "Folders: ${folders[@]}"
    for folder in "${folders[@]}"; do
        if [ ! -d "$folder" ]; then
            echo "$0Error: Folder '$folder' not found." >&2
            exit 1
        fi
    done
    # Get the last folder in a more robust way
    last_folder="${folders[${#folders[@]}-1]}"
    if [ -z "$last_folder" ]; then
        echo "$0: Error: Unable to determine the last folder." >&2
        exit 1
    fi
    # echo "Last folder: $last_folder"
    source_path_last=$(basename "$(realpath "$last_folder")")
    # echo "source_path_last: $source_path_last"
else
    source_path_last="command_line_files"
fi

# Get current date in YYYY-MM-DD format
current_date=$(date +%Y-%m-%d)
# Create a sortable timestamp (YYYYMMDD_HHMMSS)
sortable_timestamp=$(date +%Y%m%d_%H%M%S)
# Construct the new output filename
OUTPUTFILE="${sortable_timestamp}_${source_path_last}_${current_date}.txt"

# Process files based on input
{
    if [ ${#folders[@]} -gt 0 ]; then
        for folder in "${folders[@]}"; do
            # Build the exclude pattern for find command
            exclude_pattern=""
            for pattern in "${EXCLUDED_PATTERNS[@]}"; do
                exclude_pattern="${exclude_pattern} -not -path '*/${pattern}'"
                echo "Exclude pattern: $exclude_pattern"
            done

            # Check for .gitignore and add its contents to exclusions
            gitignore_file="${folder}/.gitignore"
            if [ -f "$gitignore_file" ]; then
                echo "Found .gitignore file in $folder. Adding its contents to exclusions."
                while IFS= read -r line || [[ -n "$line" ]]; do
                    # Ignore empty lines and comments
                    if [[ -n "$line" && ! "$line" =~ ^\s*# ]]; then
                        # Remove leading and trailing whitespace
                        line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
                        # Escape special characters for use in find command
                        escaped_line=$(echo "$line" | sed 's/[[\^$.*]/\\&/g')
                        exclude_pattern="${exclude_pattern} -not -path '*/${escaped_line}*'"
                    fi
                done < "$gitignore_file"
            fi

            # Construct and execute the find command
            find_command="find \"$folder\" \\( -type d -name .terraform -prune \\) -o \\( -type f $exclude_pattern \\) -print0"
            echo "Executing command for folder $folder: $find_command"
            
            # Use process substitution to avoid subshell issues with while loop
            while IFS= read -r -d '' file; do
                process_file "$file"
            done < <(eval "$find_command")
        done
    fi

    # Process individual files
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "Warning: File '$file' not found. Skipping." >&2
            continue
        fi
        process_file "$file"
    done
} > "${OUTPUTDIR}/${OUTPUTFILE}"

# Print the output file name on successful completion
echo "Output saved to: ${OUTPUTDIR}/${OUTPUTFILE}"
echo "Number of files processed: $(grep -c '^<' "${OUTPUTDIR}/${OUTPUTFILE}")"
open "${OUTPUTDIR}"
