# Statement Creation Pipeline with Quotation Tool

<b>Abstract:</b> This notebook documents a complete workflow for constructing statement-level datasets from raw news articles. The pipeline integrates R-based preprocessing with Python-based quote extraction to move from unstructured article text to a structured dataset of direct group statements, suitable for computational analysis of media voice, framing, and public interest advocacy.

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
- Assignment of quotes to specific interest groups
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
- **Articles.csv**: Raw news articles with columns for article ID, body text, title, publication date, and outlet
- **Masterlist.csv**: Entity reference list with unique IDs, names, and alternative name variations

## Prerequisites

### Python Environment
The notebook requires Python packages listed in `requirements.txt`:
```bash
pip install -r requirements.txt
```

### R Environment
Required R packages will be installed automatically via the notebook, or manually:
```R
install.packages(c("readxl", "openxlsx", "tidyr", "dplyr", 
                   "stringdist", "lubridate", "readr", "stringr", "progress"),
                 repos="https://cloud.r-project.org")
```

### R-Python Integration
The workflow uses `rpy2` to execute R scripts from Python, enabling seamless integration of preprocessing and analysis stages

## Running the Notebook

1. Clone the repository
2. Install Python dependencies: `pip install -r requirements.txt`
3. Install R and required packages (see Prerequisites above)
4. Open `quote_extractor_notebook_forcsvfiles.ipynb` in Jupyter


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
- Ensure Articles.csv has required columns: `an`, `body`, `title`, `publication_datetime`, `outlet`
- Ensure Masterlist.csv has required columns: `uniqid`, `name`, and optional `name_alt1-4`, `abbreviation`
- Check that CSV files are properly formatted and encoded (UTF-8)

**No Statements Generated:**
- Verify entities in Masterlist.csv are actually mentioned in articles
- Check that quote extraction found quotes (check `output` folder)
- Review entity name variations in Masterlist.csv for better matching

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
