# SusAI raw-data validation
# Structural checks only. This script does not clean data or fit outcome models.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

raw_dir <- file.path("data", "raw", "2026-09-24_original_data")

expected_files <- c(
  "household_profiles.csv",
  "households.csv",
  "nudge_responses.csv",
  "usage_logs.csv"
)

expected_sha256 <- c(
  household_profiles.csv = "25e6efc7ff948fe10b93551535740745f339a4b14a1ef4ef70a0d772b857e72a",
  households.csv = "2de289ac02927bacf0789b7d1863aea511cd92a8f975d293387151fabb19a882",
  nudge_responses.csv = "4a1c7bc6351c4ed5cfac1ca9fac9cd987eb5c43aa2d05b58199f68a4502e1988",
  usage_logs.csv = "15673f9cacb7d8d44979fa8881e299fcaa30ebdf404baf760cd4647e0a4aca98"
)

paths <- file.path(raw_dir, expected_files)
if (!all(file.exists(paths))) {
  stop(
    "Raw snapshot is incomplete. Missing: ",
    paste(expected_files[!file.exists(paths)], collapse = ", ")
  )
}

sha256_file <- function(path) {
  command <- if (Sys.info()[["sysname"]] == "Darwin") "shasum" else "sha256sum"
  args <- if (command == "shasum") c("-a", "256", path) else path
  output <- system2(command, args, stdout = TRUE, stderr = TRUE)
  sub("[[:space:]].*$", "", output[[1]])
}

actual_sha256 <- vapply(paths, sha256_file, character(1))
names(actual_sha256) <- expected_files

if (!identical(unname(actual_sha256), unname(expected_sha256))) {
  mismatch <- expected_files[actual_sha256 != expected_sha256]
  stop("Raw-data checksum mismatch: ", paste(mismatch, collapse = ", "))
}

households <- read_csv(
  paths[expected_files == "households.csv"],
  show_col_types = FALSE
)
profiles <- read_csv(
  paths[expected_files == "household_profiles.csv"],
  show_col_types = FALSE
)
nudge <- read_csv(
  paths[expected_files == "nudge_responses.csv"],
  show_col_types = FALSE
)
usage <- read_csv(
  paths[expected_files == "usage_logs.csv"],
  show_col_types = FALSE
)

required_columns <- list(
  households = c(
    "id", "passcode_hash", "first_login_at", "phase_override",
    "ineligible_at", "consented_at", "phase2_intro_seen_at", "is_test",
    "green_score", "day_override", "created_at"
  ),
  profiles = c(
    "household_id", "owns_dishwasher", "owns_washing_machine",
    "owns_phone_charging_habit", "household_size", "dwelling_type",
    "age_bracket", "created_at"
  ),
  nudge = c(
    "id", "household_id", "appliance", "window", "response",
    "suggested_wait_hours", "created_at"
  ),
  usage = c(
    "id", "household_id", "appliance", "started_at", "window_at_use",
    "is_backdated", "created_at"
  )
)

tables <- list(
  households = households,
  profiles = profiles,
  nudge = nudge,
  usage = usage
)

for (table_name in names(tables)) {
  missing_columns <- setdiff(
    required_columns[[table_name]],
    names(tables[[table_name]])
  )
  if (length(missing_columns) > 0) {
    stop(
      table_name,
      " is missing columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
}

checks <- tibble::tribble(
  ~check, ~value,
  "household_rows", nrow(households),
  "profile_rows", nrow(profiles),
  "nudge_rows", nrow(nudge),
  "usage_rows", nrow(usage),
  "duplicate_household_ids", sum(duplicated(households$id)),
  "duplicate_profile_household_ids", sum(duplicated(profiles$household_id)),
  "duplicate_nudge_ids", sum(duplicated(nudge$id)),
  "duplicate_usage_ids", sum(duplicated(usage$id)),
  "orphan_profile_households", sum(!profiles$household_id %in% households$id),
  "orphan_nudge_households", sum(!nudge$household_id %in% households$id),
  "orphan_usage_households", sum(!usage$household_id %in% households$id),
  "test_accounts", sum(households$is_test, na.rm = TRUE),
  "consented_accounts", sum(!is.na(households$consented_at)),
  "ineligible_accounts", sum(!is.na(households$ineligible_at))
)

allowed_appliances <- c("dishwasher", "washing_machine", "phone_charging")
allowed_windows <- c("bad", "ok", "great")
allowed_responses <- c("accept", "decline")

category_failures <- tibble::tribble(
  ~field, ~invalid_rows,
  "usage.appliance", sum(!usage$appliance %in% allowed_appliances),
  "usage.window_at_use", sum(!usage$window_at_use %in% allowed_windows),
  "nudge.appliance", sum(!nudge$appliance %in% allowed_appliances),
  "nudge.window", sum(!nudge$window %in% allowed_windows),
  "nudge.response", sum(!nudge$response %in% allowed_responses)
)

cat("SusAI raw-data structural validation\n")
cat("Snapshot:", raw_dir, "\n")
cat("Checksums: PASS\n\n")
print(checks, n = Inf)
cat("\nCategory failures\n")
print(category_failures, n = Inf)

structural_issues <- checks$value[
  grepl("duplicate|orphan", checks$check)
] != 0

if (any(structural_issues) || any(category_failures$invalid_rows != 0)) {
  stop("Structural validation failed. Review the printed checks.")
}

cat("\nStructural validation: PASS\n")
