# Define file paths
input_file <- "proceeding/articles_with_mentions.csv"
output_file <- "input/articles_with_mentions.csv"

# Read the CSV file (base R - much faster)
cat("Reading file from proceeding folder...\n")
articles_df <- read.csv(input_file, stringsAsFactors = FALSE)

# Rename columns: body -> text, title -> text_name
cat("Renaming columns...\n")
names(articles_df)[names(articles_df) == "body"] <- "text"
names(articles_df)[names(articles_df) == "an"] <- "text_name"

# Write to input folder
cat("Writing file to input folder...\n")
write.csv(articles_df, output_file, row.names = FALSE)

cat("Successfully moved and renamed columns!\n")
cat("File saved to:", output_file, "\n")
