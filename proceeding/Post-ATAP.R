# ==============================================================================
# STATEMENT CREATION PIPELINE
# ==============================================================================
# Purpose: Extract and process relevant quotes from news articles mentioning
#          specific organizations/individuals
# ==============================================================================

# Load required packages ----
library(dplyr)
library(tidyr)
library(stringr)
library(openxlsx)
library(readxl)
library(stringdist)
library(progress)
library(lubridate)

# ==============================================================================
# STEP 3: QUOTE EXTRACTION AND PROCESSING
# ==============================================================================

#' Load and combine ATAP quote extraction outputs
#'
#' This function loads quotation tool (ATAP) outputs that have been
#' written to the /output directory after running the pre-ATAP
#' pipeline and the quotation extraction step. All matching files
#' are combined into a single quote-level dataset.
#'
#' @param output_dir Path to the output directory containing ATAP files
#' @param file_stub Base filename used for ATAP quote outputs
#' @return Combined quotes data frame
load_atap_quotes <- function(
  output_dir = "output",
  file_stub  = "articles_with_mentions_quotes"
) {
  
  cat("Loading ATAP quote extractions from /output...\n")
  
  # Identify all matching ATAP files (try both .csv and .xlsx)
  atap_files_csv <- list.files(
    path       = output_dir,
    pattern    = paste0("^", file_stub, ".*\\.csv$"),
    full.names = TRUE
  )
  
  atap_files_xlsx <- list.files(
    path       = output_dir,
    pattern    = paste0("^", file_stub, ".*\\.xlsx$"),
    full.names = TRUE
  )
  
  atap_files <- c(atap_files_csv, atap_files_xlsx)
  
  # Check that files exist
  if (length(atap_files) == 0) {
    stop("No ATAP quote files found in /output matching: ", file_stub)
  }
  
  # Read and combine files based on extension
  quotes_list <- lapply(atap_files, function(file) {
    if (grepl("\\.csv$", file, ignore.case = TRUE)) {
      cat("  Reading CSV:", basename(file), "\n")
      read.csv(file, stringsAsFactors = FALSE)
    } else if (grepl("\\.(xlsx|xls)$", file, ignore.case = TRUE)) {
      cat("  Reading Excel:", basename(file), "\n")
      readxl::read_excel(file)
    } else {
      warning("Skipping unrecognized file format:", file)
      NULL
    }
  })
  
  # Remove NULL entries and combine
  quotes_list <- Filter(Negate(is.null), quotes_list)
  quotes <- dplyr::bind_rows(quotes_list)
  
  # Validate expected columns
  required_quote_cols <- c(
    "text_name",
    "speaker_entities",
    "quote",
    "speaker",
    "speaker_coref"
  )
  validate_columns(quotes, required_quote_cols, "quotes")
  
  cat(
    "Loaded", nrow(quotes), "quotes from",
    length(atap_files), "ATAP file(s)\n"
  )
  
  return(quotes)
}

#' Prepare searchlist with group information
#'
#' This function standardises group names and name variants in the
#' entity searchlist loaded from the /proceeding directory. Only columns
#' that exist in the provided dataset are processed.
#'
#' @param searchlist Entity search list (loaded from /proceeding)
#' @return Processed searchlist
prepare_searchlist <- function(searchlist) {
  
  all_cols <- c(
    "uniqid",
    "name",
    "name_alt1",
    "name_alt2",
    "name_alt3",
    "name_alt4",
    "abbreviation"
  )
  
  existing_cols <- intersect(all_cols, names(searchlist))
  
  searchlist %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(existing_cols),
        ~ tolower(as.character(.x))
      )
    )
}

# ==============================================================================
# STEP 4: ENTITY IDENTIFICATION IN QUOTES
# ==============================================================================

#' Check if a short string is an abbreviation (initials) of a longer name
#' e.g. "NFF" is abbreviation of "National Farmers Federation"
#' @param abbrev Short string to test
#' @param full_name Full name to test against
#' @return TRUE if abbrev matches initials of full_name words
is_abbreviation_of <- function(abbrev, full_name) {
  if (is.na(abbrev) || is.na(full_name) || nchar(abbrev) < 2) return(FALSE)
  # Split on any non-alphanumeric character (POSIX class - works in R's TRE engine)
  words <- unlist(strsplit(full_name, "[^[:alnum:]]+"))
  words <- words[nchar(words) > 1]
  if (length(words) < 2) return(FALSE)
  initials <- toupper(paste(substr(words, 1, 1), collapse = ""))
  toupper(abbrev) == initials
}

#' Extract organization and person entities from quote metadata
#' @param entity_string String containing entity information
#' @param text_name Article identifier
#' @return Data frame with ORG, PERSON, and text_name
extract_org_person_entities <- function(entity_string, text_name) {
  
  # Define extraction patterns
  pattern_org <- "\\('([^']+)', 'ORG'\\)"
  pattern_person <- "\\('([^']+)', 'PERSON'\\)"
  
  # Extract entities
  orgs <- str_extract_all(entity_string, pattern_org) %>%
    unlist() %>%
    sub(pattern_org, "\\1", .)
  
  persons <- str_extract_all(entity_string, pattern_person) %>%
    unlist() %>%
    sub(pattern_person, "\\1", .)
  
  # Handle different combinations
  if (length(orgs) > 0 && length(persons) == 0) {
    return(data.frame(ORG = orgs, PERSON = NA, text_name = text_name))
  }
  
  if (length(orgs) > 0 && length(persons) > 0) {
    return(data.frame(
      ORG = rep(orgs, each = length(persons)),
      PERSON = persons,
      text_name = text_name
    ))
  }
  
  # Return empty if no entities found
  return(data.frame(ORG = character(), PERSON = character(),
                    text_name = character()))
}

#' Process all quotes to extract entity information
#' @param quotes Quotes data frame
#' @param articles_subset Subset of articles with entity information
#' @param searchlist Searchlist with entity information
#' @return Processed entity data frame
process_quote_entities <- function(quotes, articles_subset, searchlist) {
  
  cat("Processing quote entities...\n")
  
  # Validate required columns
  validate_columns(quotes, c("speaker_entities", "text_name"), "quotes")
  validate_columns(articles_subset, c("an"), "articles_subset")
  
  # Extract ORG-PERSON pairs from all quotes
  org_person_pairs <- do.call(rbind, lapply(1:nrow(quotes), function(i) {
    extract_org_person_entities(quotes$speaker_entities[i], quotes$text_name[i])
  }))
  
  # Handle empty results
  if (is.null(org_person_pairs) || nrow(org_person_pairs) == 0) {
    org_person_pairs <- data.frame(ORG = character(), PERSON = character(),
                                   text_name = character())
  }
  
  # Prepare for matching
  org_person_pairs <- org_person_pairs %>%
    mutate(
      ORG = tolower(ORG),
      text_name = tolower(text_name)
    )
  
  articles_subset <- articles_subset %>%
    mutate(an = tolower(an))
  
  # Define columns to check (only use those that exist)
  match_cols <- c("name", "name_alt1", "name_alt2", "name_alt3", "name_alt4", "abbreviation")
  existing_match_cols <- intersect(match_cols, names(articles_subset))
  
  # Join with article information
  joined_data <- org_person_pairs %>%
    left_join(articles_subset, by = c("text_name" = "an"), relationship = "many-to-many")

  # Match each row using a plain loop (avoids get() scoping issues in rowwise)
  matched_name_vec <- character(nrow(joined_data))
  for (i in seq_len(nrow(joined_data))) {
    org_val  <- joined_data$ORG[i]
    name_val <- joined_data$name[i]
    result   <- NA_character_
    for (col in existing_match_cols) {
      col_value <- joined_data[[col]][i]
      if (!is.na(col_value) && col_value != "na" && nchar(col_value) >= 2) {
        org_matches <- (
          org_val == col_value ||
          grepl(col_value, org_val, fixed = TRUE) ||
          grepl(org_val, col_value, fixed = TRUE) ||
          is_abbreviation_of(org_val, col_value)
        )
        if (isTRUE(org_matches)) {
          result <- name_val  # Always return the primary name
          break
        }
      }
    }
    matched_name_vec[i] <- ifelse(is.null(result), NA_character_, result)
  }
  matched_data <- joined_data %>%
    mutate(matched_name = matched_name_vec)
  
  # Create final dataset with matched entities
  final_dataset <- matched_data %>%
    filter(!is.na(matched_name)) %>%
    select(ORG, PERSON, text_name, matched_name) %>%
    mutate(matched_name = tolower(matched_name)) %>%
    left_join(
      searchlist %>% select(name, uniqid),
      by = c("matched_name" = "name")
    ) %>%
    mutate(last_name = sub(".*\\s+", "", PERSON))
  
  cat("Processed", nrow(final_dataset), "entity matches\n")
  return(final_dataset)
}

# ==============================================================================
# STEP 5: QUOTE RELEVANCE IDENTIFICATION
# ==============================================================================

#' Check quote relevance and assign entity IDs
#' @param entity_dataset Processed entity dataset
#' @param quotes Original quotes dataset
#' @param articles_subset Article-entity rows (for fallback speaker matching)
#' @return Updated quotes with relevance flags and entity IDs
identify_relevant_quotes <- function(entity_dataset, quotes, articles_subset = NULL) {
  
  cat("Identifying relevant quotes...\n")
  
  # Validate required columns
  validate_columns(entity_dataset, c("ORG", "PERSON", "last_name", "text_name", "uniqid"),
                   "entity_dataset")
  validate_columns(quotes, c("text_name", "speaker", "speaker_coref"), "quotes")
  
  # Prepare data types
  entity_dataset <- entity_dataset %>%
    mutate(
      across(c(ORG, PERSON, last_name, text_name), as.character),
      text_name = tolower(text_name)
    )
  
  quotes_updated <- quotes %>%
    mutate(
      across(c(speaker, speaker_coref), as.character),
      text_name = tolower(text_name),
      relevant_quote = "NO",
      uniqid = NA_character_
    )
  
  # Check relevance for each quote
  for (i in seq_len(nrow(quotes_updated))) {
    text_name <- quotes_updated$text_name[i]
    speaker <- quotes_updated$speaker[i]
    speaker_coref <- quotes_updated$speaker_coref[i]
    
    # Find matching entities for this article
    matching_entities <- entity_dataset[entity_dataset$text_name == text_name, ]
    
    if (nrow(matching_entities) > 0) {
      for (j in seq_len(nrow(matching_entities))) {
        org <- matching_entities$ORG[j]
        person <- matching_entities$PERSON[j]
        last_name <- matching_entities$last_name[j]
        
        # Check for matches in speaker information
        if (any(c(
          grepl(paste0("\\b", org, "\\b"), speaker, ignore.case = TRUE),
          grepl(paste0("\\b", org, "\\b"), speaker_coref, ignore.case = TRUE),
          grepl(paste0("\\b", person, "\\b"), speaker, ignore.case = TRUE),
          grepl(paste0("\\b", person, "\\b"), speaker_coref, ignore.case = TRUE),
          grepl(paste0("\\b", last_name, "\\b"), speaker, ignore.case = TRUE),
          grepl(paste0("\\b", last_name, "\\b"), speaker_coref, ignore.case = TRUE)
        ), na.rm = TRUE)) {
          quotes_updated$relevant_quote[i] <- "YES"
          quotes_updated$uniqid[i] <- matching_entities$uniqid[j]
          break
        }
      }
    }
    
    # Fallback: if still not matched, check entity name variants directly in
    # speaker / speaker_coref text. Catches cases where the entity was not
    # captured in speaker_entities ORG field by ATAP.
    if (quotes_updated$relevant_quote[i] == "NO" && !is.null(articles_subset)) {
      art_entities <- articles_subset[tolower(articles_subset$an) == text_name, ]
      if (nrow(art_entities) > 0) {
        name_fallback_cols <- intersect(
          c("name", "name_alt1", "name_alt2", "name_alt3", "name_alt4", "abbreviation"),
          names(art_entities)
        )
        found <- FALSE
        for (j in seq_len(nrow(art_entities))) {
          for (ncol in name_fallback_cols) {
            ename <- art_entities[[ncol]][j]
            if (!is.na(ename) && ename != "na" && nchar(ename) >= 3) {
              if (grepl(ename, speaker, ignore.case = TRUE) ||
                  grepl(ename, speaker_coref, ignore.case = TRUE)) {
                quotes_updated$relevant_quote[i] <- "YES"
                quotes_updated$uniqid[i] <- art_entities$uniqid[j]
                found <- TRUE
                break
              }
            }
          }
          if (found) break
        }
      }
    }
  }
  
  relevant_count <- sum(quotes_updated$relevant_quote == "YES")
  cat("Found", relevant_count, "relevant quotes\n")
  
  return(quotes_updated)
}

# ==============================================================================
# STEP 6: CONTEXT PRESERVATION AND STATEMENT CREATION
# ==============================================================================

#' Extract paragraph context around quotes
#' @param text_name Article identifier
#' @param quote Quote text
#' @param articles_lookup Preprocessed articles for lookup
#' @return Paragraph containing the quote
extract_paragraph_context <- function(text_name, quote, articles_lookup) {
  
  # Find matching article
  article_row <- articles_lookup %>%
    filter(lower_text_name == tolower(text_name))
  
  if (nrow(article_row) == 0) return(NULL)
  
  # Extract and clean paragraphs
  paragraphs <- unlist(article_row$paragraphs)
  cleaned_quote <- trimws(quote)
  paragraphs <- sapply(paragraphs, trimws)
  
  # Find paragraph containing quote
  matching_index <- which(sapply(paragraphs, function(p) {
    grepl(cleaned_quote, p, fixed = TRUE)
  }))
  
  if (length(matching_index) == 0) return(NULL)
  
  return(paragraphs[matching_index[1]])
}

#' Create final statements dataset
#' @param relevant_quotes Filtered relevant quotes
#' @param articles_subset Article subset for context lookup
#' @return Final statements dataset with columns: an, name, uniqid, paragraph_context
create_statements_dataset <- function(relevant_quotes, articles_subset) {
  
  cat("Creating statements dataset...\n")
  
  # Accept either 'body' or 'text' as the article content column
  body_col <- if ("body" %in% names(articles_subset)) "body" else "text"
  
  # Validate required columns
  validate_columns(relevant_quotes, c("text_name", "quote", "uniqid"), "relevant_quotes")
  validate_columns(articles_subset, c("an", body_col), "articles_subset")
  
  # Prepare articles for paragraph extraction
  articles_paragraphs <- articles_subset %>%
    mutate(
      an = tolower(an),
      paragraphs = str_split(.data[[body_col]], "\n\n")
    ) %>%
    unnest(paragraphs)
  
  articles_lookup <- articles_paragraphs %>%
    mutate(
      lower_text_name = tolower(an),
      paragraphs = lapply(paragraphs, trimws)
    )
  
  # Initialize progress bar
  pb <- progress_bar$new(
    format = "  Processing [:bar] :percent | ETA: :eta",
    total = nrow(relevant_quotes),
    clear = FALSE,
    width = 60
  )
  
  # Extract context for each quote
  quotes_with_context <- relevant_quotes %>%
    rowwise() %>%
    mutate(
      paragraph_context = list({
        pb$tick()
        extract_paragraph_context(text_name, quote, articles_lookup)
      })
    ) %>%
    ungroup() %>%
    unnest(paragraph_context) %>%
    distinct(paragraph_context, text_name, uniqid, .keep_all = TRUE)
  
  # Build an -> name lookup from articles_subset (has name from searchlist join)
  an_name_map <- articles_subset %>%
    dplyr::mutate(an_lower = tolower(an)) %>%
    dplyr::select(an, an_lower, uniqid, dplyr::any_of("name")) %>%
    dplyr::distinct(an_lower, uniqid, .keep_all = TRUE)
  
  # Create final statements; text_name in quotes IS the 'an' value
  statements <- quotes_with_context %>%
    group_by(text_name, uniqid) %>%
    summarize(
      paragraph_context = str_c(paragraph_context, collapse = " // "),
      .groups = "drop"
    ) %>%
    dplyr::left_join(an_name_map, by = c("text_name" = "an_lower", "uniqid" = "uniqid")) %>%
    dplyr::select(an, dplyr::any_of("name"), uniqid, paragraph_context) %>%
    dplyr::distinct()
  
  cat("Created", nrow(statements), "final statements\n")
  return(statements)
}

# ==============================================================================
# POST-ATAP PIPELINE (AFTER QUOTES HAVE BEEN GENERATED)
# ==============================================================================

#' Complete statement creation pipeline from ATAP quotes
#'
#' This function runs the "after ATAP" part of the pipeline:
#' - loads ATAP quotes
#' - prepares the searchlist
#' - subsets articles to those with extracted quotes
#' - matches entities, flags relevant quotes, and builds statements
#'
#' @param articles_clean Cleaned articles dataset (from \code{prepare_atap_input})
#' @param searchlist Entity searchlist (same as in pre-ATAP step)
#' @return Final statements dataset
create_statements_from_atap <- function(articles_clean, searchlist) {
  
  cat("=== POST-ATAP: BUILDING STATEMENTS FROM QUOTES ===\n\n")
  
  # Basic checks
  if (missing(articles_clean) || is.null(articles_clean)) {
    stop("Cleaned articles dataset is required (from prepare_atap_input).")
  }
  if (missing(searchlist) || is.null(searchlist)) {
    stop("Searchlist is required.")
  }
  
  # Step 3: Load quotes and prepare searchlist
  quotes <- load_atap_quotes()
  searchlist_processed <- prepare_searchlist(searchlist)
  
  # Check if 'an' column exists in articles_clean
  if (!"an" %in% names(articles_clean)) {
    stop("Column 'an' (article name/id) not found in articles dataset")
  }
  
  # Match ATAP quotes to articles by ID:
  # quotes$text_name contains the article ID (same as articles_clean$an)
  articles_clean$an <- as.character(articles_clean$an)
  quotes$text_name  <- as.character(quotes$text_name)

  articles_subset <- articles_clean %>%
    dplyr::filter(an %in% quotes$text_name)
  
  # Check if mentioned_entities column exists
  if ("mentioned_entities" %in% names(articles_subset)) {
    # Split the semicolon-separated uniqids and expand
    articles_subset <- articles_subset %>%
      dplyr::mutate(
        uniqid = strsplit(as.character(mentioned_entities), ";")
      ) %>%
      tidyr::unnest(uniqid) %>%
      dplyr::mutate(uniqid = trimws(as.character(uniqid)))
  } else {
    # If no mentioned_entities column, create rows for all entities in searchlist
    # This allows entity matching to work even without pre-filtering
    cat("  Note: No 'mentioned_entities' column found. Will try all entities.\n")
    articles_with_entities <- articles_subset %>%
      tidyr::crossing(uniqid = searchlist_processed$uniqid)
    articles_subset <- articles_with_entities
  }
  
  # Join with searchlist to get entity names
  articles_subset <- articles_subset %>%
    dplyr::left_join(
      searchlist_processed %>%
        dplyr::select(dplyr::any_of(c(
          "uniqid", "name", "name_alt1", "name_alt2",
          "name_alt3", "name_alt4", "abbreviation"
        ))),
      by = "uniqid"
    )
  
  cat("Post-ATAP summary:\n")
  cat("  n_quotes         =", nrow(quotes), "\n")
  cat("  n_articles_subset =", nrow(articles_subset), "\n\n")
  
  # Step 4: Process entities
  entity_dataset <- process_quote_entities(quotes, articles_subset, searchlist_processed)
  
  # Step 5: Identify relevant quotes (pass articles_subset for fallback matching)
  updated_quotes <- identify_relevant_quotes(entity_dataset, quotes, articles_subset)
  relevant_quotes <- updated_quotes %>% dplyr::filter(relevant_quote == "YES")
  
  # Step 6: Context preservation and create statements
  statements <- create_statements_dataset(relevant_quotes, articles_subset)
  
  cat("\n=== POST-ATAP PIPELINE COMPLETE ===\n")
  cat("Final output:", nrow(statements), "statements created\n")
  
  return(statements)
}


# ==============================================================================
# FULL WORKFLOW
# ==============================================================================

# Load required data
searchlist_path <- "proceeding/Masterlist.csv"
searchlist <- read.csv(searchlist_path, stringsAsFactors = FALSE)

#FILE_PATH_ATAP <- "/output" # Path to folder where ATAP quote extractions will be saved
#quotes_path     <- "output/quotes.xlsx"     # ATAP quotes (Excel)
#quotes     <- readxl::read_excel(quotes_path)

# 4. Once quotes are available, run post-ATAP
# Use articles_with_mentions which contains the mentioned_entities column
final_statements <- create_statements_from_atap(
  articles_clean = pre$articles_with_mentions,
  searchlist     = searchlist
)

# ==============================================================================
# SAVE STATEMENTS TO /output
# ==============================================================================

# Define output paths
output_statement_path    <- "output/final_statements.csv"

write.csv(final_statements,
          file = output_statement_path,
          row.names = FALSE)

cat("Statements saved to /output:\n")
cat(" -", output_statement_path, "\n")
# ==============================================================================
# END OF SCRIPT
# ==============================================================================
