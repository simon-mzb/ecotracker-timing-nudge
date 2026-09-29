# Aggregate description of the primary households for the manuscript Methods
# (added 2026-09-28, descriptive only; no outcome model, no change to any rule).
# Reads the locked primary events, the analysis population, the raw intake
# profiles and the 04a device clocks; writes one identifier-free table.
source("analysis/analysis_helpers.R")
population<-read_set("analysis_population")
profiles<-read_csv("data/raw/2026-09-24_original_data/household_profiles.csv",
  col_types=cols(household_id=col_character(),.default=col_character()),show_col_types=FALSE)
tz<-read_csv(file.path(analysis_dir,"household_timezone.csv"),
  col_types=cols(household_id=col_character()),show_col_types=FALSE)
ids<-unique(as.character(primary$household_id))
stopifnot(length(ids)==42L,setequal(ids,population$household_id[population$primary_population]),
  !anyDuplicated(profiles$household_id),all(ids %in% profiles$household_id),all(ids %in% tz$household_id))
p<-profiles[match(ids,profiles$household_id),]
size<-as.integer(p$household_size)
first_login<-as.POSIXct(population$first_login_at[match(ids,population$household_id)],
  format="%Y-%m-%dT%H:%M:%OSZ",tz="UTC")
stopifnot(!anyNA(first_login))
clock<-tz$device_clock_offset_hours[match(ids,tz$household_id)]
yes<-function(x)sum(x=="true",na.rm=TRUE)
rows<-list(
  c("households",length(ids)),
  c("household_size_median",median(size,na.rm=TRUE)),c("household_size_min",min(size,na.rm=TRUE)),
  c("household_size_max",max(size,na.rm=TRUE)),c("household_size_missing",sum(is.na(size))),
  c("dwelling_apartment",sum(p$dwelling_type=="apartment",na.rm=TRUE)),
  c("dwelling_house",sum(p$dwelling_type=="house",na.rm=TRUE)),
  c("dwelling_other",sum(p$dwelling_type=="other",na.rm=TRUE)),c("dwelling_missing",sum(is.na(p$dwelling_type))),
  c("age_18_24",sum(p$age_bracket=="18-24",na.rm=TRUE)),c("age_25_34",sum(p$age_bracket=="25-34",na.rm=TRUE)),
  c("age_35_plus",sum(p$age_bracket %in% c("35-44","45-54","55-64","65+"),na.rm=TRUE)),
  c("age_missing",sum(is.na(p$age_bracket))),
  c("owns_dishwasher",yes(p$owns_dishwasher)),c("owns_washing_machine",yes(p$owns_washing_machine)),
  c("owns_phone_charging_habit",yes(p$owns_phone_charging_habit)),
  c("first_login_first_utc_date",format(min(first_login),"%Y-%m-%d",tz="UTC")),
  c("first_login_last_utc_date",format(max(first_login),"%Y-%m-%d",tz="UTC")),
  # Device clocks (04a): the stored window follows each device's local hour.
  c("clock_utc_plus_2",sum(clock==2)),c("clock_utc_plus_8_or_9",sum(clock %in% c(8,9))),
  c("backdated_events",sum(primary$is_backdated)),c("events",nrow(primary)))
out<-tibble(measure=vapply(rows,`[`,"",1),value=vapply(rows,`[`,"",2))
num<-function(m)as.integer(out$value[out$measure==m])
stopifnot(num("dwelling_apartment")+num("dwelling_house")+num("dwelling_other")+num("dwelling_missing")==42L,
  num("clock_utc_plus_2")+num("clock_utc_plus_8_or_9")==42L,
  num("age_18_24")+num("age_25_34")+num("age_35_plus")+num("age_missing")==42L,
  num("events")==802L)
save_table(out,"primary_sample_description")
record_session("05b_sample_description")
cat("Primary sample description written.\n")
