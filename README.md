# Statement Creation Pipeline with Quotation Tool

<b>Abstract:</b> This notebook documents a complete workflow for constructing statement-level datasets from raw news articles. The pipeline integrates R-based preprocessing with Python-based quote extraction to move from unstructured article text to a structured dataset of direct entity statements, suitable for computational analysis of a range of concepts such as framing, claims, or argumentation dyads. The workflow integrates the Australian-Text-Analytics-Platform (ATAP) Quotation Tool (Asr et al., 2021; Jufri & Sun, 2022).

## Workflow Overview

The pipeline proceeds through five main stages:

### 1. Article Ingestion and Pre-processing (Pre-ATAP)
Raw news articles are imported, cleaned, and standardized using R scripts. This includes:
- Removing formatting artifacts and normalizing dates
- Identifying entities mentioned in articles
- Preparing articles for quote extraction
- **Output**: `articles_with_mentions` dataset containing articles with entity mentions

### 2. Quote Extraction (ATAP QuotationTool)
Direct speech is identified using the ATAP quotation tool, which provides:
- Extracted quotes with speaker identification
- Named entity recognition within quotes
- Quote locations and metadata
- **Output**: CSV files with extracted quotes in the `output` folder

### 3. Speaker Identification and Entity Matching (Post-ATAP)
Extracted quotes are linked to speakers using:
- Named-entity recognition
- Rule-based matching to entity masterlist
- Assignment of quotes to specific entities on the masterlist
- **Output**: Matched quotes with entity identifiers

### 4. Statement Validation and Filtering
Automated assignments are filtered to:
- Remove misattributions and ambiguous speakers
- Validate speaker-entity matches
- Filter non-substantive quotations
- **Output**: High-confidence statement dataset

### 5. Context Enrichment
Each validated quote is enriched with:
- Surrounding paragraph context
- Source article information
- Entity and speaker metadata
- **Output**: Final statement-level dataset (`final_statements.csv`)

## Required Files and Setup

### Directory Structure
```
quotation-tool/
├── proceeding/           # R scripts and data
│   ├── Pre-ATAP.R       # Article preprocessing
│   ├── Post-ATAP.R      # Statement creation from quotes
│   ├── move_and_rename_columns.R  # Data moving and renaming
│   ├── Articles.csv     # Raw article data
│   └── Masterlist.csv   # Entity reference list
├── output/              # Quote extraction outputs
└── quote_extractor_notebook_forcsvfiles.ipynb
```

### Input Requirements

Place both files in the `proceeding/` folder before running the notebook.

- **Articles.csv**: Raw news articles with these column names:
  - `an` — unique identifier for the article
  - `body` — article body text
  - `title` — article title
  - `publication_datetime` — date the article was published (ISO 8601 format recommended, e.g. `2024-03-15` or `2024-03-15 09:30:00`)
  - `outlet` — unique identifier of the publishing outlet (e.g. newspaper name)
- **Masterlist.csv**: Entity reference list with the following column names:
  - `uniqid` — unique identifier for the entity
  - `name` — primary name of the entity (e.g. name of an interest group)
  - Optional: `name_alt1`, `name_alt2`, `name_alt3`, `name_alt4` — alternative name variations
  - Optional: `abbreviation` — abbreviated form of the entity name

## Prerequisites

### R Environment
Requires R to be installed on your system. R packages are installed as part of the First-Time Setup below.

### R-Python Integration
The workflow uses `rpy2` to execute R scripts from Python, enabling seamless integration of preprocessing and analysis stages

## Running the Notebook

### Supported Python version

**Python 3.11 is required.**

#### macOS / Linux — choose one option below

**Option A — pyenv (reads `.python-version` automatically)**

```bash
# Install pyenv
brew install pyenv              # macOS
curl https://pyenv.run | bash   # Linux / WSL2

# Add pyenv to your shell (follow the output of the install command, or add manually):
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Update pyenv so its version list is current, then find the latest 3.11.x:
brew upgrade pyenv                                        # macOS
# pyenv update                                           # Linux/WSL2 (if pyenv-update plugin installed)
# cd ~/.pyenv && git pull                                # Linux/WSL2 fallback
pyenv install --list | grep -E "^\s+3\.11\."   # pick the highest number shown
pyenv install 3.11.x        # replace with the version you found above
cd quotation-tool
pyenv local 3.11.x             # writes/confirms the .python-version file
pyenv exec python --version    # should print Python 3.11.x
```

**Option B — uv (fast, modern — also handles Python install)**

[uv](https://docs.astral.sh/uv/) installs Python, creates virtual environments, and installs packages in one tool. Install it:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # macOS / Linux
# or on macOS with Homebrew:
# brew install uv
```

Close and reopen your terminal. uv will install Python 3.11 automatically during the First-Time Setup below — no separate Python download needed.

#### Windows — choose one option below

**Option 1 — Direct Python installer (recommended, simplest)**

Download and run the **Python 3.11.x** installer from [python.org/downloads](https://www.python.org/downloads/release/python-3119/). During installation, tick **"Add Python to PATH"**.

Verify in PowerShell:
```powershell
py -0                # lists all installed Python versions
py -3.11 --version   # should print Python 3.11.x
```

You can install multiple Python versions (3.9, 3.11, 3.12, etc.) side-by-side and select with `py -3.9`, `py -3.11`, etc. — no pyenv needed.

**Option 2 — uv (fast, modern — also handles Python install)**

[uv](https://docs.astral.sh/uv/) installs Python, creates virtual environments, and installs packages in one tool. Install it in PowerShell:

```powershell
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Close and reopen PowerShell. uv will install Python 3.11 automatically during the First-Time Setup below — no separate Python download needed.

**Option 3 — pyenv-win (only if you need per-directory Python version switching)**

pyenv-win reads the `.python-version` file and switches Python automatically per project. Use this only if you regularly switch Python versions across projects.

Install using the official PowerShell script — run these **two commands separately**:

```powershell
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"
& "./install-pyenv-win.ps1"
```

> If you get an `UnauthorizedAccess` error, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` first.

> **Note:** `winget install pyenv-win.pyenv-win` is **not officially supported** and frequently fails. Use the script above.

If the PS1 script fails, use git clone:

```powershell
git clone https://github.com/pyenv-win/pyenv-win.git "$HOME\.pyenv"
[System.Environment]::SetEnvironmentVariable('PYENV',      "$HOME\.pyenv\pyenv-win\", 'User')
[System.Environment]::SetEnvironmentVariable('PYENV_ROOT', "$HOME\.pyenv\pyenv-win\", 'User')
[System.Environment]::SetEnvironmentVariable('PYENV_HOME', "$HOME\.pyenv\pyenv-win\", 'User')
[System.Environment]::SetEnvironmentVariable('Path', "$HOME\.pyenv\pyenv-win\bin;$HOME\.pyenv\pyenv-win\shims;" + [System.Environment]::GetEnvironmentVariable('Path', 'User'), 'User')
```

Close and reopen PowerShell, then install Python 3.11:

```powershell
pyenv --version   # confirm install succeeded (e.g. pyenv 3.1.1)

# Filter for stable releases only — no 'a', 'b', or 'rc' in the name:
pyenv install --list | Select-String "^\s+3\.11\.\d+\s*$"
# If no output: your pyenv version list is stale — reinstall via git clone above.

pyenv install 3.11.x         # replace with highest stable shown, e.g. 3.11.9
pyenv local 3.11.x           # writes .python-version for this directory
pyenv exec python --version  # should print Python 3.11.x
```

---

### First-Time Setup — macOS / Linux

#### Option A — pyenv

```bash
cd quotation-tool
# pyenv picks up .python-version automatically:
pyenv exec python -m venv venv
# Without pyenv (ensure python3 is 3.11 first):
# python3 -m venv venv
source venv/bin/activate
```

> **Note:** The next two commands will download around 600 MB and will take a few minutes.

```bash
python -m pip install -r requirements.txt
python -m coreferee install en   # downloads the English language model (not a pip install)
```

Install required R packages (run once from within R or RScript):

```R
install.packages(c("readxl", "openxlsx", "tidyr", "dplyr", "stringdist", "lubridate", "readr", "stringr", "progress"), repos="https://cloud.r-project.org")
```

Register the virtual environment as a Jupyter kernel (only required once):

```bash
python -m ipykernel install --user --name quotation_tool
```

Launch the notebook:

```bash
jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

---

#### Option B — uv

```bash
cd quotation-tool
uv python install 3.11
uv venv --python 3.11 venv
source venv/bin/activate
```

> **Note:** The next two commands will download around 600 MB and will take a few minutes.

```bash
uv pip install -r requirements.txt
python -m coreferee install en   # downloads the English language model — uses python, not uv
```

Install required R packages (run once from within R or RScript):

```R
install.packages(c("readxl", "openxlsx", "tidyr", "dplyr", "stringdist", "lubridate", "readr", "stringr", "progress"), repos="https://cloud.r-project.org")
```

Register the virtual environment as a Jupyter kernel (only required once):

```bash
python -m ipykernel install --user --name quotation_tool
```

Launch the notebook:

```bash
jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

---

### First-Time Setup — Windows

> **Where to put the project:** Clone or extract the repository into a folder **inside your user directory**, for example:
> - `C:\Users\<you>\Documents\quotation-tool`
> - `C:\Users\<you>\Projects\quotation-tool`
>
> **Do not place it directly under `C:\`** (e.g. `C:\_repos\quotation-tool`). Root-level directories on `C:\` apply stricter Windows security policies to executables, which causes `[WinError 5] Access is denied` when launching Jupyter from a virtual environment.

> **Run all commands from the project root**, not from a subdirectory such as `output\`.

> If you see an execution policy error at any point, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` first.

---

#### Option 1 — Direct Python installer (recommended)

Use this if you followed **Option 1** (python.org installer) above.

```powershell
cd C:\Users\<you>\Documents\quotation-tool
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

After activation the prompt shows `(.venv)`. Now use `python` (not `py -3.11`) for all remaining commands — using `py -3.11` bypasses the active venv and installs into the system Python instead.

> **Note:** The next two commands download around 600 MB and will take a few minutes.

```powershell
python -m pip install -r requirements.txt
python -m coreferee install en   # downloads the English language model (not a pip install)
```

Install required R packages (run once from within R or RScript):

```R
install.packages(c("readxl", "openxlsx", "tidyr", "dplyr", "stringdist", "lubridate", "readr", "stringr", "progress"), repos="https://cloud.r-project.org")
```

Register the virtual environment as a Jupyter kernel (only required once):

```powershell
python -m ipykernel install --user --name quotation_tool
```

Launch the notebook:

```powershell
$env:JUPYTER_RUNTIME_DIR="$PWD\.jupyter_runtime"
python -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

The R initialisation cell in the notebook automatically locates your R installation — no manual environment variable setup is required for standard R installs.

---

#### Option 2 — uv (fast, modern)

Use this if you followed **Option 2** (uv) above. uv handles Python installation, venv creation, and package installation in one tool.

```powershell
cd C:\Users\<you>\Documents\quotation-tool
uv python install 3.11
uv venv --python 3.11 .venv
.\.venv\Scripts\Activate.ps1
```

> **Note:** The next two commands download around 600 MB and will take a few minutes.

```powershell
uv pip install -r requirements.txt
python -m coreferee install en   # downloads the English language model — uses python, not uv
```

Install required R packages (run once from within R or RScript):

```R
install.packages(c("readxl", "openxlsx", "tidyr", "dplyr", "stringdist", "lubridate", "readr", "stringr", "progress"), repos="https://cloud.r-project.org")
```

Register the virtual environment as a Jupyter kernel (only required once):

```powershell
python -m ipykernel install --user --name quotation_tool
```

Launch the notebook. With uv you can use `uv run` to bypass Windows executable restrictions:

```powershell
$env:JUPYTER_RUNTIME_DIR="$PWD\.jupyter_runtime"
uv run jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

If `uv run` is not available, fall back to:

```powershell
python -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

---

#### Option 3 — pyenv-win

Use this if you followed **Option 3** (pyenv-win) above.

```powershell
cd C:\Users\<you>\Documents\quotation-tool
pyenv exec python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Then follow the same steps as **Option 1** from the `python -m pip install` step onwards.

---

### First-Time Setup — Windows (Advanced Alternative: WSL2)

For users comfortable with Linux command-line tools, WSL2 (Windows Subsystem for Linux 2) is an alternative to the native Windows setup above. Under WSL2 the standard Linux workflow applies and the Windows R DLL detection issue does not arise, because R is installed as a Linux package found via `PATH`.

**Additional installation steps required before `pip install`:**

```bash
# Install C build tools and R development headers (needed to compile rpy2)
sudo apt update
sudo apt install build-essential r-base r-base-dev software-properties-common
```

**Then install Python 3.11 — choose one:**

*Option A — pyenv:*
```bash
curl https://pyenv.run | bash
# Add pyenv to your shell as shown in the Supported Python version section above, then:
source ~/.bashrc
# Update pyenv so it knows about the latest releases:
cd ~/.pyenv && git pull
pyenv install --list | grep -E "^\s+3\.11\."   # pick the highest shown
pyenv install 3.11.x   # replace with the version you found above
```

*Option B — uv:*
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# Close and reopen your terminal, then continue with the First-Time Setup below.
```

> **Alternative (Option A only):** Install via the deadsnakes PPA instead of pyenv:
> ```bash
> sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt update
> sudo apt install python3.11 python3.11-venv python3.11-dev
> ```

> **Why compilation?** `rpy2-rinterface` (the C extension that links against R) has no pre-built Linux wheels on PyPI. pip compiles it from source, which takes ~5 minutes. Without `build-essential` and `r-base-dev` the install fails with a C compilation error.

Once the above is installed, follow the **macOS / Linux First-Time Setup** (Option A or Option B) from the section above — the commands are identical under WSL2:

```bash
cd ~/projects/quotation-tool
# Option A (pyenv):
pyenv exec python -m venv venv
# Option B (uv):
# uv python install 3.11 && uv venv --python 3.11 venv
source venv/bin/activate
python -m pip install -r requirements.txt     # or: uv pip install -r requirements.txt
python -m coreferee install en               # downloads the English language model (not a pip install)
```

Install R packages as shown in the macOS/Linux section above, then register the kernel and launch:

```bash
python -m ipykernel install --user --name quotation_tool
jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

WSL2 automatically forwards localhost ports — the Jupyter URL opens directly in your Windows browser. Keep project files under the WSL home directory (`~/`) rather than `/mnt/c/` for best I/O performance.

---

### Subsequent Use — macOS / Linux

```bash
cd ~/quotation-tool
source venv/bin/activate
jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
# or with uv (Option B): uv run jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

### Subsequent Use — Windows

```powershell
cd C:\Users\<you>\Documents\quotation-tool
.\.venv\Scripts\Activate.ps1
$env:JUPYTER_RUNTIME_DIR="$PWD\.jupyter_runtime"
python -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
# or with uv: uv run jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

> **Note:** `ipykernel install` does not need to be re-run — the kernel registration persists across sessions. Simply activate the virtual environment and launch Jupyter.


## Workflow Execution

### Step 1: Pre-ATAP Processing
The notebook executes `Pre-ATAP.R` which:
- Loads articles from `proceeding/Articles.csv`
- Loads entity masterlist from `proceeding/Masterlist.csv`
- Cleans and preprocesses articles
- Identifies entity mentions in each article
- Creates `articles_with_mentions` dataset

### Step 2: Column Formatting
Executes `move_and_rename_columns.R` to prepare data for quotation tool

### Step 3: Quote Extraction
The ATAP QuotationTool processes files and generates output CSV files containing:
- **text_id/text_name**: Article identifiers
- **quote_id/speaker_id**: Unique quote/speaker identifiers  
- **quote/speaker**: Extracted quote content and speaker
- **verb**: Reporting verb used
- **quote_index/speaker_index/verb_index**: Character positions in text
- **quote_entities/speaker_entities**: Named entities (PERSON, ORG, GPE, etc.)
- **quote_token_count**: Quote length
- **quote_type**: Extraction method used
- **is_floating_quote**: Whether quote is follow-up from same speaker

### Step 4: Post-ATAP Processing
Executes `Post-ATAP.R` which:
1. Loads quote extraction outputs from `output` folder
2. Matches speakers to entities from masterlist
3. Identifies relevant quotes from target entities
4. Extracts paragraph context around each quote
5. Creates final statement dataset

### Final Output
The pipeline produces `output/final_statements.csv` containing:
- **text_name**: Article identifier (title)
- **uniqid**: Entity unique identifier
- **paragraph_context**: Quote(s) with surrounding paragraph text

## Understanding the Output

### Quote Extraction Metadata
The quotation tool uses syntactic and heuristic rules to identify direct speech. For detailed information about the extraction process, see [this document](https://doi.org/10.1371/journal.pone.0245533.s001).

**Named Entity Types:**
- **PERSON**: People, including fictional characters
- **NORP**: Nationalities, religious or political groups
- **FAC**: Buildings, airports, highways
- **ORG**: Companies, agencies, institutions
- **GPE**: Countries, cities, states
- **LOC**: Non-GPE locations, mountain ranges, bodies of water

**Quote Types:**
- Syntactic quotes (e.g., SVC, QVS patterns)
- Heuristic quotes based on quotation marks
- Floating quotes (follow-up statements from same speaker)

### Statement Dataset
The final output (`final_statements.csv`) provides statement-level data where:
- Each row represents quotes from a specific entity in a specific article
- Multiple quotes from the same entity-article are concatenated with " // "
- Paragraph context preserves interpretive meaning for analysis

## Data Processing Notes

### Memory Considerations
Processing large corpora may require significant memory. 
- Large files may cause kernel restarts
- Consider splitting large datasets into smaller batches

### Performance
As a guideline:
- ~26,000 newspaper articles (54MB): ~45 minutes for quote extraction
- Processing time depends on corpus size and complexity
- Pre-ATAP and Post-ATAP stages are typically faster than quote extraction

## Additional Resources

### User Guides
- [Quotation Tool User Guide](documents/quotation_help_pages.pdf)
- [Jupyter Notebook Guide](documents/jupyter-notebook-guide.pdf)
- [CILogon Troubleshooting](documents/cilogon-troubleshooting.pdf)

### Troubleshooting

**Memory Issues:**
- Divide large corpora into smaller batches
- Run locally instead of on Binder for larger datasets
- Use the [ATAP Context Extractor](https://github.com/Australian-Text-Analytics-Platform/atap-context-extractor) to reduce document size

**Missing Columns or Errors:**
- Ensure `Articles.csv` has required columns: `an`, `body`, `title`, `publication_datetime`, `outlet`
- Ensure `Masterlist.csv` has required columns: `uniqid`, `name`, and optional `name_alt1-4`, `abbreviation`
- Check that CSV files are saved as **UTF-8** (without BOM). If you edit them in Excel on Windows, use *Save As → CSV UTF-8 (comma delimited)*. The pipeline handles BOM-damaged headers automatically, but clean UTF-8 is always safest.

**No Statements Generated:**
- Verify entities in `Masterlist.csv` are actually mentioned in articles
- Check that quote extraction found quotes (check `output` folder)
- Review entity name variations in `Masterlist.csv` for better matching

**macOS: `rpy2` warning "Library not loaded: /usr/lib/libpcre2-8.0.dylib"**
- rpy2's API-mode binary expects `libpcre2` at `/usr/lib/` but on macOS with Homebrew R it lives at `/usr/local/lib/`. rpy2 automatically falls back to ABI mode, which still works and the pipeline runs normally — the warning can be safely ignored.
- If you see actual import failures (not just the warning), add the library path before launching Jupyter:
  ```bash
  export DYLD_FALLBACK_LIBRARY_PATH=/usr/local/lib:$DYLD_FALLBACK_LIBRARY_PATH
  jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
  ```
  (Note: `/usr/lib` is SIP-protected on macOS — do not attempt to create a symlink there.)

**Windows: `Error executing Jupyter command 'lab': [WinError 5] Access is denied`**
- Windows is blocking execution of the `jupyter-lab.exe` script inside the virtual environment. This is most commonly caused by Windows security policy, antivirus software, or the venv being created in a restricted directory (e.g. directly under `C:\`).
- **Fix 1 (recommended):** Run PowerShell as Administrator — right-click PowerShell and choose "Run as administrator", then re-activate the venv and launch Jupyter:
  ```powershell
  .\.venv\Scripts\Activate.ps1
  $env:JUPYTER_RUNTIME_DIR="$PWD\.jupyter_runtime"
  python -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
  ```
- **Fix 2:** Call the Jupyter script directly, bypassing the module launcher:
  ```powershell
  $env:JUPYTER_RUNTIME_DIR="$PWD\.jupyter_runtime"
  .\.venv\Scripts\jupyter-lab.exe
  ```
- **Fix 3:** Unblock the venv executables that Windows may have quarantined after download:
  ```powershell
  Get-ChildItem ".\.venv\Scripts\*.exe" | Unblock-File
  ```
  Then retry `python -m jupyter lab`.
- **Fix 4:** On Windows 10 1905 or newer, the built-in Python app alias may intercept the call. Disable it via **Start → Manage App Execution Aliases** and turn off any Python entries.

**Windows: `'sh' is not recognized as an internal or external command`**
- This message appears in the PowerShell window after JupyterLab starts. It comes from `jupyter_lsp`, which checks for language server tools by trying to run `sh` (a Unix shell). `sh` does not exist on Windows.
- This is a cosmetic warning only — it does not affect the notebook's functionality. It can be safely ignored.

**Windows: packages installed into system Python instead of the virtual environment**
- If `pip install` output shows `Requirement already satisfied in C:\Users\...\Python311\Lib\site-packages` (the system path, not `.venv`), the venv was bypassed.
- **Cause:** Using `py -3.11 -m pip` after activating the venv. The `py` launcher ignores the active venv and always targets the system Python.
- **Fix:** After running `.\.venv\Scripts\Activate.ps1`, use `python -m pip` (not `py -3.11 -m pip`) for all commands. Check that your prompt shows `(.venv)` before running install commands.
- If packages are already in the wrong place, deactivate the venv, delete the `.venv` folder, re-create it, activate it, and re-run `python -m pip install -r requirements.txt`.

**Wrong kernel — `ModuleNotFoundError: No module named 'coreferee'` (or other packages)**
- The notebook is running on the system Python instead of the `quotation_tool` virtual environment.
- Check the kernel name shown in the top-right corner of Jupyter. If it is not `quotation_tool`, go to **Kernel → Change Kernel → quotation_tool**, then restart the kernel.
- If `quotation_tool` does not appear in the list, re-run `python -m ipykernel install --user --name quotation_tool` from inside the activated venv and reload the Jupyter page.

**`NameError: name 'r' is not defined` in the Post-ATAP cell**
- This happens after a kernel restart or kernel switch. Restarting the kernel clears all variables, including the `r` object imported from `rpy2`.
- After any kernel restart or change, re-run **all cells from the beginning**: the Windows R initialisation cell first, then the rpy2 import cell (`from rpy2.robjects import r`), and all subsequent cells in order before reaching the Post-ATAP cell.

**Windows: `rpy2` fails to import or cannot find R**
- Run the notebook's Windows R initialisation cell (the first code cell) before any other cell. It detects your R installation automatically.
- If R is still not found, set `R_HOME` in PowerShell before launching Jupyter:
  ```powershell
  $env:R_HOME = "C:\Users\<you>\AppData\Local\Programs\R\R-4.x.x"
  python -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
  ```
- Make sure you are using **Python 3.11**. The stack does not work with Python 3.12+.

**Windows: `pip install` or `python3` not recognised**
- Use `py -3.11 -m pip install ...` (the Python Launcher) instead of `pip` or `python3`.

**Windows: `coreferee install en` fails**
- Run: `py -3.11 -m coreferee install en`

## Reference and Acknowledgments

This workflow integrates:
- The ATAP QuotationTool, adapted (with permission) from the [GenderGapTracker](https://github.com/sfu-discourse-lab/GenderGapTracker/tree/master/nlp/english)
- Custom R-based preprocessing and statement creation pipeline
- The quotation tool's accuracy is evaluated in [this article](https://doi.org/10.1371/journal.pone.0245533)

## Citation

If you use this statement creation pipeline or the Quotation Tool in your research, please cite:

```
Jufri, Sony & Sun, Chao (2022). Quotation Tool. v1.0. 
Australian Text Analytics Platform. Software. 
https://github.com/Australian-Text-Analytics-Platform/quotation-tool
```

For the original GenderGapTracker quote extractor:
```
Asr, Fatemeh Torabi, et al. "The Gender Gap Tracker: Using Natural Language 
Processing to measure gender bias in media." PloS one 16.1 (2021): e0245533.
https://doi.org/10.1371/journal.pone.0245533
```
