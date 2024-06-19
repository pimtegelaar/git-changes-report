
# Git Directory Changes Report Script

## Overview

This script generates an HTML report of changes in a Git repository's directories, filtered by a specified file extension and a specified number of months. The report provides a hierarchical view of the directories with color-coded indicators showing the frequency of changes, making it easier to identify heavily modified areas of the codebase.

## Features

- Prompts the user for a file extension and a time period if not provided as arguments.
- Analyzes the Git history to count changes in directories based on the specified file extension.
- Generates an HTML report with a collapsible directory structure.
- Uses color-coding to indicate the number of changes, transitioning from green (few changes) to red (many changes).
- Automatically opens the generated HTML report in the default web browser.

## Prerequisites

- Git must be installed and available in your system's PATH.
- A Unix-like environment (Linux, macOS, or Windows with Git Bash).

## Usage

### 1. Clone the repository or download the script

```bash
git clone https://github.com/pimtegelaar/git-changes-report
cd git-changes-report
```

Alternatively, you can download the script directly and navigate to its directory.

### 2. Make the script executable

```bash
chmod +x git_changes_report.sh
```

### 3. Run the script

You can run the script with or without arguments. 

#### Without Arguments

If you run the script without any arguments, it will prompt you to enter the working directory, file extension and the number of months:

```bash
./git_changes_report.sh
```

You will be prompted to enter:

- **Working directory by** (default: `.`)
- **File extension to filter by** (default: `.java`)
- **Number of months to look back** (default: `6`)

#### With Arguments

You can also provide the file extension and the number of months as arguments:

```bash
./git_changes_report.sh . .py 3
```

In this example, the script will generate a report for `.py` files and look back 3 months in the Git history.

### Output

- **HTML Report**: The script generates an HTML file named `package_changes.html` in the current directory.
- **Automatic Browser Opening**: The script attempts to open the HTML report in the default web browser.

### Note

If the automatic browser opening fails (e.g., unsupported OS), you can manually open the `package_changes.html` file in your web browser.

## License

This script is open source and available under the [MIT License](LICENSE).

## Contributions

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## Contact

For any questions or suggestions, please open an issue in this repository.

