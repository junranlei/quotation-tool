# Define file paths
input_file <- "proceeding/articles_with_mentions.csv"
output_file <- "input/articles_with_mentions.csv"

# Ensure output directory exists
if (!dir.exists("input")) dir.create("input", recursive = TRUE)

# Read with readr so UTF-8 BOM is stripped automatically
cat("Reading file from proceeding folder...\n")
articles_df <- readr::read_csv(input_file, show_col_types = FALSE)

# Repair any remaining BOM-damaged column names (e.g. from Excel on Windows)
names(articles_df) <- sub("^\xef\xbb\xbf", "", names(articles_df))   # raw BOM bytes
names(articles_df) <- sub("^\u00ef\u00bb\u00bfan$", "an", names(articles_df))
names(articles_df) <- sub("^\u00ef\\.\\.", "an", names(articles_df))
names(articles_df) <- trimws(names(articles_df))

# Rename columns: body -> text, an -> text_name
cat("Renaming columns...\n")
if ("body" %in% names(articles_df)) {
  names(articles_df)[names(articles_df) == "body"] <- "text"
}
if ("an" %in% names(articles_df)) {
  names(articles_df)[names(articles_df) == "an"] <- "text_name"
}

# Write to input folder as clean UTF-8 (no BOM, no row numbers)
cat("Writing file to input folder...\n")
readr::write_csv(articles_df, file = output_file)

cat("Successfully moved and renamed columns!\n")
cat("File saved to:", output_file, "\n")
