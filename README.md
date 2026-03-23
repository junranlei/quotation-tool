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

**Python 3.11 is required.** The repository includes a `.python-version` file that `pyenv` reads automatically.

#### Option A — pyenv (recommended, works on macOS / Linux / WSL2, reads `.python-version` automatically)

```bash
# Install pyenv
brew install pyenv              # macOS
curl https://pyenv.run | bash   # Linux / WSL2

# Add pyenv to your shell (follow the output of the install command, or add manually):
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Python 3.11 and pin it for this project
# First, update pyenv so its version list is current, then find the latest 3.11.x:
brew upgrade pyenv                                        # macOS
# pyenv update                                           # Linux/WSL2 (if pyenv-update plugin installed)
# cd ~/.pyenv && git pull                                # Linux/WSL2 fallback
pyenv install --list | grep -E "^\s+3\.11\."   # pick the highest number shown
pyenv install 3.11.x        # replace with the version you found above
cd quotation-tool
pyenv local 3.11.x             # writes/confirms the .python-version file (no patch needed)
# From now on, pyenv selects 3.11 automatically whenever you cd into this folder
pyenv version                # confirms: 3.11.x (set by .python-version)
pyenv exec python --version  # should print Python 3.11.x
```

#### Option A — pyenv-win (recommended for Windows, reads `.python-version` automatically)

```powershell
# Install pyenv-win
winget install pyenv-win.pyenv-win
# or: pip install pyenv-win

# Find the latest 3.11.x patch and install it:
# First update pyenv-win so its version list is current:
pyenv update
pyenv install --list | Select-String "  3\.11\."   # pick the highest shown
pyenv install 3.11.x        # replace with the version you found above
cd C:\path\to\quotation-tool
pyenv local 3.11.x            # writes/confirms .python-version (no patch needed)
# Use 'pyenv global 3.11.x' only if you want 3.11.x as your system-wide default
pyenv exec python --version  # should print Python 3.11.x
```

#### Option B — system / installer Python (no pyenv)

```bash
python3 --version   # must show Python 3.11.x
```

On Windows use `py -0` to list installed versions and `py -3.11` instead of `python3`.

---

### First-Time Setup — macOS / Linux

```bash
cd quotation-tool
# If using pyenv, it picks up .python-version automatically:
pyenv exec python -m venv venv
# Without pyenv (ensure python3 is 3.11 first):
# python3 -m venv venv
source venv/bin/activate
```

> **Note:** The next two commands will download around 600MB and will take a while.

```bash
python3 -m pip install -r requirements.txt
python3 -m coreferee install en
```

Install required R packages (run once from within R or RScript):

```R
install.packages(c("readxl", "openxlsx", "tidyr", "dplyr", "stringdist", "lubridate", "readr", "stringr", "progress"), repos="https://cloud.r-project.org")
```

Register the virtual environment as a Jupyter kernel (only required once):

```bash
python3 -m ipykernel install --user --name quotation_tool
```

Launch the notebook:

```bash
jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

---

### First-Time Setup — Windows

Use `py -3.11` (the Python Launcher) instead of `python3`. Open **PowerShell** and run:

```powershell
cd C:\path\to\quotation-tool
# If using pyenv-win (reads .python-version automatically):
pyenv exec python -m venv .venv
# Without pyenv-win:
# py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

> If you see an error about execution policy, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` first.

> **Note:** The next two commands will download around 600MB and will take a while.

```powershell
py -3.11 -m pip install -r requirements.txt
py -3.11 -m coreferee install en
```

Install required R packages (run once from within R or RScript):

```R
install.packages(c("readxl", "openxlsx", "tidyr", "dplyr", "stringdist", "lubridate", "readr", "stringr", "progress"), repos="https://cloud.r-project.org")
```

Register the virtual environment as a Jupyter kernel (only required once):

```powershell
py -3.11 -m ipykernel install --user --name quotation_tool
```

Launch the notebook. The R initialisation cell in the notebook will automatically locate your R installation on Windows — no manual environment variable setup is required for standard R installs (those made via the official R installer). If R cannot be found you will see a clear error message with instructions.

```powershell
py -3.11 -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

---

### First-Time Setup — Windows (Advanced Alternative: WSL2)

For users comfortable with Linux command-line tools, WSL2 (Windows Subsystem for Linux 2) is an alternative to the native Windows setup above. Under WSL2 the standard Linux workflow applies and the Windows R DLL detection issue does not arise, because R is installed as a Linux package found via `PATH`.

**Additional installation steps required before `pip install`:**

```bash
# Install C build tools and R development headers (needed to compile rpy2)
sudo apt update
sudo apt install build-essential r-base r-base-dev software-properties-common

# Install Python 3.11 via pyenv (recommended — no PPA needed)
curl https://pyenv.run | bash
# Add pyenv to your shell init file as shown in the Supported Python version section above, then:
source ~/.bashrc
# Update pyenv so it knows about the latest releases, then install:
brew upgrade pyenv 2>/dev/null || (cd ~/.pyenv && git pull)
pyenv install --list | grep -E "^\s+3\.11\."   # pick the highest shown
pyenv install 3.11.x   # replace with the version you found above
```

> **Alternative:** Install via the deadsnakes PPA instead of pyenv:
> ```bash
> sudo add-apt-repository ppa:deadsnakes/ppa && sudo apt update
> sudo apt install python3.11 python3.11-venv python3.11-dev
> ```

> **Why compilation?** `rpy2-rinterface` (the C extension that links against R) has no pre-built Linux wheels on PyPI. pip compiles it from source, which takes ~5 minutes. Without `build-essential` and `r-base-dev` the install fails with a C compilation error.

Once the above is installed, the setup commands are the same as macOS/Linux (`.python-version` selects 3.11 automatically via pyenv):

```bash
cd ~/projects/quotation-tool
pyenv exec python -m venv venv
source venv/bin/activate
python -m pip install -r requirements.txt
python -m coreferee install en
```

Install R packages as shown in the macOS/Linux section above, then register the kernel and launch:

```bash
python3.11 -m ipykernel install --user --name quotation_tool
jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

WSL2 automatically forwards localhost ports — the Jupyter URL opens directly in your Windows browser. Keep project files under the WSL home directory (`~/`) rather than `/mnt/c/` for best I/O performance.

---

### Subsequent Use — macOS / Linux

```bash
cd ~/quotation-tool
source venv/bin/activate
jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
```

### Subsequent Use — Windows

```powershell
cd C:\path\to\quotation-tool
.\.venv\Scripts\Activate.ps1
py -3.11 -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
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

**Windows: `rpy2` fails to import or cannot find R**
- Run the notebook's Windows R initialisation cell (the first code cell) before any other cell. It detects your R installation automatically.
- If R is still not found, set `R_HOME` in PowerShell before launching Jupyter:
  ```powershell
  $env:R_HOME = "C:\Users\<you>\AppData\Local\Programs\R\R-4.x.x"
  py -3.11 -m jupyter lab quote_extractor_notebook_forcsvfiles.ipynb
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
