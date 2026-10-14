# Paths

`local/paths.json` holds six private directory roots. The rest of each
path stays in the script, for example:

```sql
LOAD DATA INFILE '{{DATA_ROOT}}/Gold_JAN2026_linked/Gold_2/hes_patient_24_004516.txt'
```

`render_paths.ps1` fills in the roots and saves copies under
`local/rendered/`. MariaDB needs a literal filename for `LOAD DATA INFILE`,
which is why these SQL files need this step before running.

## Setup

For a new checkout:

```powershell
New-Item -ItemType Directory -Path local -Force
Copy-Item config/paths.example.json local/paths.json
```

Set the roots needed by the scripts you plan to run. Use forward slashes
and leave off the trailing slash. The script handles backslashes for the
PowerShell files. The template lists all six roots; unused ones can stay empty.

## Run

From the repository root:

```powershell
# One study folder, including its subfolders
.\render_paths.ps1 -Path oxcprd_002_sql_scripts

# More than one folder
.\render_paths.ps1 -Path aurum_bmi,aurum_smoking

# One script
.\render_paths.ps1 -Path oxcprd_002_sql_scripts/import_alcohol_unit_tables.sql

# Check the roots without writing copies
.\render_paths.ps1 -Path oxcprd_003_sql_scripts -Check
```

Open the copy in `local/rendered/` and run it in the usual SQL client,
R or PowerShell. The subfolders match the source folders. Run PowerShell
files from their rendered subfolder if they use relative file references.

Only the selected files are refreshed. `-Path .` covers the whole repository.
New scripts are included before they have been committed, unless Git ignores
them.

## Changes and commits

Edit the source files, then regenerate the copies when needed. Keep the root
markers in the sources. 
Do not copy paths back over the source files.

The renderer, this note and `config/paths.example.json` are tracked so another
checkout can use the same setup.
