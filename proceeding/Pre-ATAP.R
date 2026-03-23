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
library(readr)

# Global constants ----
CHUNK_SIZE <- 10000  # Rows per processing chunk
MIN_ARTICLE_LENGTH <- 200  # Minimum article length in characters

# ==============================================================================
# ENCODING HELPER
# ==============================================================================

#' Repair column names damaged by a UTF-8 BOM (common on Windows/Excel outputs)
#' Replaces leading \u00ef\u00bb\u00bf or \u00ef.. sequences with empty string.
#' @param df Data frame whose column names should be cleaned
#' @return Data frame with repaired column names
fix_bom_colnames <- function(df) {
  names(df) <- sub("^\\xef\\xbb\\xbf", "", names(df))  # UTF-8 BOM bytes in latin1 view
  names(df) <- sub("^\\\u00ef\\\u00bb\\\u00bf", "", names(df))  # Unicode escape form
  names(df) <- sub("^\u00ef..", "an", names(df))  # common garbled form: ï..an
  names(df) <- sub("^\u00ef\u00bb\u00bfan$", "an", names(df))
  names(df) <- trimws(names(df))
  df
}

# Load datasets using readr for clean UTF-8 input (handles BOM automatically)
articles_path   <- "proceeding/Articles.csv"       # raw articles
searchlist_path <- "proceeding/Masterlist.csv"     # entity searchlist

articles   <- readr::read_csv(articles_path, show_col_types = FALSE)
searchlist <- readr::read_csv(searchlist_path, show_col_types = FALSE)

# Repair any BOM-damaged column names that survived the read
articles   <- fix_bom_colnames(articles)
searchlist <- fix_bom_colnames(searchlist)
# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

#' Validate required columns exist in dataframe
#' @param df Data frame to check
#' @param required_cols Character vector of required column names
#' @param df_name Name of dataframe for error messages
#' @return TRUE if all columns exist, stops with error otherwise
validate_columns <- function(df, required_cols, df_name = "dataframe") {
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf("Missing required columns in %s: %s",
                 df_name,
                 paste(missing_cols, collapse = ", ")))
  }
  return(TRUE)
}

# ==============================================================================
# STEP 1: DATA PREPROCESSING
# ==============================================================================

#' Process article chunks to remove invalid content
#' @param chunk Data frame chunk to process
#' @return Filtered data frame
process_article_chunk <- function(chunk) {
  
  # Validate required columns
  validate_columns(chunk, c("body"), "article chunk")
  
  # Check if text contains English words
  contains_english <- function(text) {
    grepl("\\b[a-zA-Z]{2,}\\b", text)
  }
  
  # Remove URLs from text
  remove_urls <- function(text) {
    url_pattern <- "http[s]?://[^\\s]+"
    text_clean <- gsub(url_pattern, "", text)
    return(trimws(text_clean))
  }
  
  # Clean and filter articles
  chunk %>%
    mutate(body = sapply(body, remove_urls)) %>%
    filter(
      body != "",
      nchar(body) >= MIN_ARTICLE_LENGTH,
      sapply(body, contains_english)
    )
}

#' Preprocess articles dataset
#' @param articles Raw articles data frame
#' @return Cleaned articles data frame
preprocess_articles <- function(articles) {
  
  cat("Preprocessing articles...\n")
  
  # Validate required columns
  validate_columns(articles, c("body", "publication_datetime"), "articles")
  
  # Process in chunks to manage memory
  num_chunks <- ceiling(nrow(articles) / CHUNK_SIZE)
  chunks <- split(articles, (seq_len(nrow(articles)) - 1) %/% CHUNK_SIZE)
  
  # Process each chunk
  processed_chunks <- lapply(chunks, process_article_chunk)
  articles_clean <- do.call(rbind, processed_chunks)
  
  # Format dates
  if (is.numeric(articles_clean$publication_datetime)) {
    # Case 1: numeric epoch (assume milliseconds)
    articles_clean <- articles_clean %>%
      mutate(
        publication_datetime = as.POSIXct(publication_datetime / 1000,
                                          origin = "1970-01-01", tz = "UTC"),
        publication_date = as.Date(publication_datetime)
      )
  } else {
    # Case 2: character / other → parse flexibly
    articles_clean <- articles_clean %>%
      mutate(
        publication_datetime = suppressWarnings(
          lubridate::parse_date_time(
            as.character(publication_datetime),
            orders = c(
              "Ymd HMS", "Ymd HM", "Ymd",
              "Y-m-d HMS", "Y-m-d HM", "Y-m-d",
              "Y/m/d HMS", "Y/m/d HM", "Y/m/d",
              "d/m/Y HMS", "d/m/Y HM", "d/m/Y"
            ),
            tz = "UTC"
          )
        ),
        publication_date = as.Date(publication_datetime)
      )
  }
  
  cat("Preprocessing complete. Articles retained:", nrow(articles_clean), "\n")
  return(articles_clean)
}

# ==============================================================================
# STEP 2: ARTICLE SUBSETTING BY MENTIONS
# ==============================================================================

#' Normalise Unicode apostrophes and quotes to ASCII equivalents
#' @param s Character string to normalise
#' @return Normalised string
normalize_unicode <- function(s) {
  s <- gsub("\u2018|\u2019", "'", s)  # curly single quotes → straight
  s <- gsub("\u201c|\u201d", '"', s)  # curly double quotes → straight
  s
}

#' Create regex patterns for entity search (FIXED)
#' @param searchlist Data frame with entity names and alternatives
#' @return Data frame with regex patterns
create_search_patterns <- function(searchlist) {
  
  # Validate columns exist (with defaults for optional columns)
  required_cols <- c("name", "uniqid")
  validate_columns(searchlist, required_cols, "searchlist")
  
  # Add optional columns if they don't exist
  optional_cols <- c("name_alt1", "name_alt2")
  for (col in optional_cols) {
    if (!col %in% names(searchlist)) {
      searchlist[[col]] <- NA_character_
    }
  }
  
  # Build patterns safely
  searchlist %>%
    rowwise() %>%
    mutate(
      pattern = {
        pattern_parts <- c()
        
        # Add main name if not NA
        if (!is.na(name)) {
          pattern_parts <- c(pattern_parts, paste0("\\b", normalize_unicode(tolower(name)), "\\b"))
        }
        
        # Add alternative 1 if not NA
        if (!is.na(name_alt1)) {
          pattern_parts <- c(pattern_parts, paste0("\\b", normalize_unicode(tolower(name_alt1)), "\\b"))
        }
        
        # Add alternative 2 if not NA
        if (!is.na(name_alt2)) {
          pattern_parts <- c(pattern_parts, paste0("\\b", normalize_unicode(tolower(name_alt2)), "\\b"))
        }
        
        # Join with OR operator, return NA if no valid parts
        if (length(pattern_parts) > 0) {
          paste(pattern_parts, collapse = "|")
        } else {
          NA_character_
        }
      }
    ) %>%
    ungroup() %>%
    filter(!is.na(pattern))  # Remove entries with no valid pattern
}

#' Find entity mentions in articles
#' @param articles Preprocessed articles data frame
#' @param searchlist Entity search list with patterns
#' @return Articles with mention information
find_entity_mentions <- function(articles, searchlist) {
  
  cat("Finding entity mentions in articles...\n")
  
  # Validate required columns
  validate_columns(articles, c("body"), "articles")
  validate_columns(searchlist, c("uniqid", "name"), "searchlist")
  
  # Initialize progress bar
  pb <- progress_bar$new(
    format = "  Processing [:bar] :percent ETA: :eta",
    total = nrow(articles),
    width = 60
  )
  
  # Create search patterns
  searchlist_patterns <- create_search_patterns(searchlist)
  
  # Check if we have valid patterns
  if (nrow(searchlist_patterns) == 0) {
    warning("No valid search patterns created from searchlist")
    return(articles %>% mutate(mentioned_entities = NA_character_))
  }
  
  # Find mentions for each article
  mentioned_entities <- vector("list", nrow(articles))
  
  for (i in seq_len(nrow(articles))) {
    pb$tick()
    
    body_lower <- normalize_unicode(tolower(articles$body[i]))
    matches <- searchlist_patterns$uniqid[
      str_detect(body_lower, regex(searchlist_patterns$pattern))
    ]
    
    mentioned_entities[[i]] <- if (length(matches) > 0) {
      paste(matches, collapse = ";")
    } else {
      NA_character_
    }
  }
  
  # Add results to articles
  articles_with_mentions <- articles %>%
    mutate(mentioned_entities = unlist(mentioned_entities)) %>%
    filter(!is.na(mentioned_entities) & mentioned_entities != "")
  
  cat("Found", nrow(articles_with_mentions), "articles with entity mentions\n")
  return(articles_with_mentions)
}



# ==============================================================================
# PRE-ATAP PIPELINE (BEFORE YOU RUN THE QUOTATION TOOL)
# ==============================================================================

#' Prepare articles for ATAP quotation extraction
#'
#' This function runs the "before ATAP" part of the pipeline:
#' - cleans raw articles
#' - detects entity mentions
#' - returns both the cleaned articles and the subset with mentions
#'   that you can export to / feed into ATAP.
#'
#' @param articles Raw articles dataset
#' @param searchlist Entity searchlist (contains all entity information)
#' @return A list with:
#'   \item{articles_clean}{Cleaned articles dataset}
#'   \item{articles_with_mentions}{Subset used as input to ATAP}
prepare_atap_input <- function(articles, searchlist) {
  
  cat("=== PRE-ATAP: PREPARING INPUT FOR QUOTATION TOOL ===\n\n")
  
  # Validate main inputs
  if (missing(articles) || is.null(articles)) {
    stop("Articles dataset is required")
  }
  if (missing(searchlist) || is.null(searchlist)) {
    stop("Searchlist is required")
  }
  
  # Step 1: Preprocess articles
  articles_clean <- preprocess_articles(articles)
  
  # Step 2: Find entity mentions (this defines the subset for ATAP)
  articles_with_mentions <- find_entity_mentions(articles_clean, searchlist)
  
  cat("Pre-ATAP summary:\n")
  cat("  n_cleaned   =", nrow(articles_clean), "\n")
  cat("  n_with_mentions =", nrow(articles_with_mentions), "\n\n")
  cat("Use `articles_with_mentions` as the subset to send to ATAP.\n")
  cat("Ensure article is in ' text' coloumn and textid  is in 'text_name' coloumn.\n")
  
  invisible(list(
    articles_clean        = articles_clean,
    articles_with_mentions = articles_with_mentions
  ))
}

# ==============================================================================
# FULL WORKFLOW
# ==============================================================================

# 1. Run pre-ATAP (prepare input for quotation tool)
pre <- prepare_atap_input(
  articles   = articles,
  searchlist = searchlist
)

# ==============================================================================
# SAVE OUTPUTS TO /output
# ==============================================================================

# Define output paths
input_clean_path   <- "proceeding/articles_clean.csv"
input_atap_path    <- "proceeding/articles_with_mentions.csv"

# Save files using readr::write_csv for clean UTF-8 output (no BOM, cross-platform)
readr::write_csv(pre$articles_clean, file = input_clean_path)
readr::write_csv(pre$articles_with_mentions, file = input_atap_path)

cat("Outputs saved to /input:\n")
cat(" -", input_clean_path, "\n")
cat(" -", input_atap_path, "\n")