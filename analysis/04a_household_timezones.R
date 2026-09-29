# DEC-028: household clock offsets for calendar covariates, and verification that
# stored window labels follow each device's reported local clock.
# Stored labels are never recoded. Offsets are used only to form LOCAL calendar
# dates/weekdays for the calendar-time sensitivity analyses.
options(susai.skip_primary_load = TRUE)  # this script creates the offsets prepare_events() needs
source("analysis/analysis_helpers.R")
raw <- "data/raw/2026-09-24_original_data"
hh <- read_csv(file.path(raw, "households.csv"), col_types = cols(.default = col_character()))
ul <- read_csv(file.path(raw, "usage_logs.csv"), col_types = cols(.default = col_character()))
nr <- read_csv(file.path(raw, "nudge_responses.csv"), col_types = cols(.default = col_character()))
ts <- function(x) as.POSIXct(sub("\\+00$", "", x), tz = "UTC", format = "%Y-%m-%d %H:%M:%OS")
app_window <- function(h) ifelse(h >= 10 & h < 17, "great", ifelse((h >= 8 & h < 10) | (h >= 17 & h < 19), "ok", "bad"))

# Assignment rule (team information 2026-09-27, cross-checked against the stored window labels below):
# each household's device-clock offset (UTC+2 Germany, UTC+8 or UTC+9 East/Southeast Asia) was assigned
# from its recruitment block. [redacted for the public repository: original household IDs are not published]
# Households with records rewritten after collection (DEC-030) are not assigned.
ids <- hh$id
device <- REDACTED_OFFSET_ASSIGNMENT(ids)  # [redacted for the public repository: original household IDs are not published]
calendar <- device
region <- ifelse(device %in% c(8, 9), "Southeast/East Asia (UTC+8/+9)", "Germany")
tz <- tibble(household_id = ids, region = region, device_clock_offset_hours = device,
  calendar_offset_hours = calendar)

integrity_excluded <- read_csv("analysis/record_integrity_exclusions.csv", col_types = cols(.default = col_character()))$household_id
eligible <- hh$id[hh$is_test == "false" & !is.na(hh$consented_at) & is.na(hh$ineligible_at) & !is.na(hh$first_login_at) &
  !(hh$id %in% integrity_excluded)]
first_login <- setNames(ts(hh$first_login_at), hh$id)
# Only records inside each household's own study window [0, 336 h) are relevant.
in_window <- function(id, t) { h <- as.numeric(difftime(t, first_login[id], units = "hours")); !is.na(h) & h >= 0 & h < 336 }

# Verification 1: immediate registrations (label from device hour at registration).
imm <- bind_rows(
  ul %>% filter(is_backdated == "false") %>% transmute(household_id, t = ts(created_at), window = window_at_use, source = "usage_log"),
  nr %>% transmute(household_id, t = ts(created_at), window, source = "nudge_response")) %>%
  inner_join(tz, by = "household_id") %>% filter(household_id %in% eligible, in_window(household_id, t)) %>%
  mutate(device_hour = (as.integer(format(t, "%H", tz = "UTC")) + device_clock_offset_hours) %% 24,
    agrees = app_window(device_hour) == window,
    agrees_germany = app_window((as.integer(format(t, "%H", tz = "UTC")) + 2) %% 24) == window)
# Verification 2: suggested wait hours (computed from the same device hour).
sw <- nr %>% filter(window == "bad", !is.na(suggested_wait_hours)) %>%
  inner_join(tz, by = "household_id") %>% filter(household_id %in% eligible, in_window(household_id, ts(created_at))) %>%
  mutate(s = as.integer(suggested_wait_hours), implied_hour = ifelse(s <= 10 & 10 - s <= 7, 10 - s, 34 - s),
    utc_hour = as.integer(format(ts(created_at), "%H", tz = "UTC")),
    implied_offset = (implied_hour - utc_hour) %% 24, agrees = implied_offset == device_clock_offset_hours %% 24)

region_check <- imm %>% filter(household_id %in% eligible) %>% group_by(region) %>%
  summarise(households = n_distinct(household_id), immediate_records = n(),
    label_agreement_device_clock = mean(agrees), label_agreement_if_germany_clock = mean(agrees_germany), .groups = "drop") %>%
  left_join(sw %>% filter(household_id %in% eligible) %>% group_by(region) %>%
    summarise(bad_responses = n(), suggested_wait_agreement = mean(agrees), .groups = "drop"), by = "region")
hh_check <- imm %>% filter(household_id %in% eligible) %>% group_by(household_id, region) %>%
  summarise(records = n(), agreement = mean(agrees), .groups = "drop")
save_table(region_check, "timezone_label_consistency", TRUE)
save_table(hh_check %>% ungroup() %>% summarise(households = n(), all_records_agree = sum(agreement == 1),
  min_agreement = min(agreement), households_below_0.9 = sum(agreement < .9)), "timezone_household_agreement_summary", TRUE)
write_csv(tz %>% filter(household_id %in% eligible), file.path(analysis_dir, "household_timezone.csv"))
write_csv(hh_check, file.path(analysis_dir, "household_timezone_label_agreement.csv"))

overall <- mean(imm$agrees[imm$household_id %in% eligible])
stopifnot(overall > .98, length(eligible) == 66L, !any(tz$region[tz$household_id %in% eligible] == "Germany (device clock UTC)"), all(sw$agrees[sw$household_id %in% eligible]),
  all(eligible %in% tz$household_id))
print(region_check, width = Inf)
cat(sprintf("Overall label agreement with assigned device clocks: %.4f\n", overall))
record_session("04a_household_timezones")
