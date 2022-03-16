# Setting Up Cluster From New

# Log in to didehpc
credentials = "C:/Users/gbarnsle/.smbcredentials"
options(didehpc.cluster = "fi--didemrchnb",
        didehpc.username = "gbarnsle")

## ------------------------------------
## 1. Package Installations
## ------------------------------------
# drat:::add("mrc-ide")
# install.packages("pkgdepends")
# install.packages("didehpc")
# install.packages("orderly")

## ------------------------------------
## 2. Setting up a cluster configuration
## ------------------------------------

options(didehpc.cluster = "fi--didemrchnb")

# not if T is not mapped then map network drive
didehpc::didehpc_config_global(temp=didehpc::path_mapping("tmp",
                                                          "T:",
                                                          "//fi--didef3.dide.ic.ac.uk/tmp",
                                                          "T:"),
                               home=didehpc::path_mapping("GB",
                                                          "Q:",
                                                          "//fi--san03/homes/gbarnsle",
                                                          "Q:"),
                               credentials=credentials,
                               cluster = "fi--didemrchnb")

# Creating a Context
context_name <- paste0("Q:/COVID-Fitting/help/glodide/context")

ctx <- context::context_save(
  path = context_name,
  package_sources = conan::conan_sources(
    packages = c(
      "vimc/orderly", "mrc-ide/squire", "mrc-ide/nimue", "mrc-ide/squire.page",
      c('tinytex','knitr', 'tidyr', 'ggplot2', 'ggrepel', 'magrittr', 'dplyr', 'here', "lubridate", "rmarkdown",
        'stringdist','plotly', 'rvest', 'xml2', 'ggforce', 'countrycode', 'cowplot', 'RhpcBLASctl', 'nimue',
        'squire.page', "ggpubr")
      ),
    repos = "https://ncov-ic.github.io/drat/")
  )

# set up a specific config for here as we need to specify the large RAM nodes
config <- didehpc::didehpc_config(template = "GeneralNodes")
config$resource$parallel <- "FALSE"
config$resource$type <- "Cores"
config$resource$count <- 3
# Configure the Queue
obj <- didehpc::queue_didehpc(ctx, config = config)

## 3. Submit the jobs
## ------------------------------------

date <- "2022-01-31"#"2021-12-08"
excess_mortality <- TRUE
workdir <- file.path(
  "analysis/data/",
  paste0(
    "derived",
    ifelse(excess_mortality, "_excess", "")
  ),
  date
)
dir.create(workdir, recursive = TRUE, showWarnings = FALSE)
workdir <- normalizePath(workdir)

# Grabbing tasks to be run
tasks <- readRDS(gsub("derived", "raw", file.path(workdir, "bundles.rds")))
tasks <- as.character(vapply(tasks, "[[", character(1), "path"))

# submit our tasks to the cluster
split_path <- function(x) if (dirname(x)==x) x else c(basename(x),split_path(dirname(x)))
bundle_name <- paste0(tail(rev(split_path(workdir)), 2), collapse = "_")
grp_reported <- obj$lapply(tasks, orderly::orderly_bundle_run, workdir = workdir,
                  name = paste0(bundle_name, "_2"))

## ------------------------------------
## 4. Check on our jobs
## ------------------------------------

didehpc:::reconcile(obj, grp$ids)
table(grp$status())

#get the resubmit function
source(file.path(here::here(), "analysis", "resubmit_func.R"))

while(keep_running | keep_running_2){
  Sys.sleep(30*60)
  print("LMIC")
  keep_running <- resubmit_func(obj, grp_lmic)
  print(table(grp_lmic$status()))
  print("Excess")
  keep_running_2 <- resubmit_func(obj, grp_excess)
  print(table(grp_excess$status()))
}

# see what has errored
errs <- get_errors(grp_lmic)

#get their iso3cs
dput(get_iso3cs(grp_excess, c("ERROR", "RUNNING")))

# do we just need to rerun some of the bundles
resubmit_all(grp_lmic, c("ERROR"))

## ------------------------------------
## 6. Submit new jobs that come from a different bundle - this bit you will rewrite
## ------------------------------------

# Grabbing tasks to be run
tasks <- readRDS(gsub("derived", "raw", file.path(workdir, "bundles_to_rerun.rds")))
tasks <- as.character(vapply(tasks, "[[", character(1), "path"))

# submit our tasks to the cluster
split_path <- function(x) if (dirname(x)==x) x else c(basename(x),split_path(dirname(x)))
bundle_name <- paste0("rerun_", paste0(tail(rev(split_path(workdir)), 2), collapse = "_"))
grp_excess_2 <- obj$lapply(tasks, orderly::orderly_bundle_run, workdir = workdir,
                  name = paste0(bundle_name, "_4"))

didehpc:::reconcile(obj, grp_rerun$ids)
table(grp_rerun$status())

# see what has errorred

errs <- get_errors(grp_rerun)

resubmit_all(grp_rerun, c("ERROR", "MISSING"))

## ------------------------------
## 7. Functions to extract objects from zips for checking
## ------------------------------

zip_read <- function(path, file = "pack/grid_out.rds", fn = readRDS) {

  td <- tempdir()
  zip::unzip(gsub("raw", "derived", path),
             files = file.path(gsub(".zip", "", basename(path)), file),
             exdir = td, overwrite = TRUE, junkpaths = TRUE)
  fn(file.path(td, basename(file)))

}

out <- zip_read(tasks$IRN$path)
proj <- zip_read(tasks$IRN$path, file = "pack/projections.csv", read.csv)
proj %>% filter(compartment == "infections" & scenario == "Maintain Status Quo") %>%
  select(date, y_median) %>%
  ggplot(aes(as.Date(date), cumsum(y_median)/sum(squire::get_population("Iran")$n))) +
  geom_line() + ylab("Attack Rate") + xlab("") + ggpubr::theme_pubclean() +
  theme(axis.line = element_line()) +
  geom_vline(xintercept = as.Date("2021-08-19"))

zip_read(grp_rerun$X[1], "pack/fitting.pdf", roxer::sopen)
zip_read(grp_bgd$X[1], "pack/fitting.pdf", roxer::sopen)
