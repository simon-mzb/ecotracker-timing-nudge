# Database timestamps have at most microsecond precision. readr::write_csv
# otherwise formats POSIXct at whole seconds in this runtime. Preserve UTC
# fractional seconds explicitly in DERIVED files; never modify raw CSVs.
format_utc_microseconds <- function(x) {
  seconds<-as.numeric(x);whole<-floor(seconds)
  micros<-round((seconds-whole)*1e6)
  carry<-!is.na(micros) & micros==1e6
  whole[carry]<-whole[carry]+1;micros[carry]<-0
  out<-paste0(format(as.POSIXct(whole,origin="1970-01-01",tz="UTC"),
    "%Y-%m-%dT%H:%M:%S",tz="UTC"),sprintf(".%06dZ",as.integer(micros)))
  out[is.na(seconds)]<-NA_character_
  out
}
write_csv_precise <- function(x,file,...) {
  date_columns<-vapply(x,inherits,logical(1),what="POSIXct")
  x[date_columns]<-lapply(x[date_columns],format_utc_microseconds)
  readr::write_csv(x,file,...)
}
