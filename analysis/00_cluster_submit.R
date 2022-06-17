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
                               home=didehpc::path_mapping("ncov",
                                                          "N:",
                                                          "//wpia-hpc-hn-app/ncov-global",
                                                          ":"),
                               credentials=credentials,
                               cluster = "fi--didemrchnb")

# Creating a Context
context_name <- file.path(here::here(), "context")

ctx <- context::context_save(
  path = context_name,
  package_sources = conan::conan_sources(
    packages = c(
      "vimc/orderly", "mrc-ide/odin", "mrc-ide/drjacoby", "mrc-ide/squire", "mrc-ide/nimue", "mrc-ide/squire.page",
      c('tinytex','knitr', 'tidyr', 'ggplot2', 'ggrepel', 'magrittr', 'dplyr', 'here', "lubridate", "rmarkdown",
        'stringdist','plotly', 'rvest', 'xml2', 'ggforce', 'countrycode', 'cowplot', 'RhpcBLASctl', 'nimue',
        'squire.page', "ggpubr", "purrr")
      ),
    repos = "https://ncov-ic.github.io/drat/")
  )


# set up a specific config for here as we need to specify the large RAM nodes
config <- didehpc::didehpc_config(template = "32Core")
config$resource$parallel <- "FALSE"
config$resource$type <- "Cores"
config$resource$count <- 3
# Configure the Queue
obj <- didehpc::queue_didehpc(ctx, config = config)

## 3. Submit the jobs
## ------------------------------------

date <- "2022-05-30"
workdir <- file.path(
  "analysis/data/",
  paste0(
    "derived"
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
grp <- obj$lapply(tasks, orderly::orderly_bundle_run, workdir = workdir,
                  name = paste0(bundle_name, ""))

## ------------------------------------
## 4. Check on our jobs
## ------------------------------------

#get the resubmit function
source(file.path(here::here(), "analysis", "resubmit_func.R"))

#this function checks for common errors can be safely resubmitted
#then returns TRUE if tasks are still running
keep_running <- resubmit_func(obj, grp)
#this loops checks the fits every 30 minutes
while(keep_running){# | keep_running_2){
  Sys.sleep(30*60)
  print("LMIC Fit")
  keep_running <- resubmit_func(obj, grp)
  print(table(grp$status()))
}

# see what has errored
errs <- get_errors(grp)

#get their iso3cs
dput(get_iso3cs(grp, c("ERROR")))

# do we just need to rerun all with errors
resubmit_all(grp_rerun, c("ERROR"))

## ------------------------------------
## 6. Submit new jobs that come from a different bundle - this bit you will rewrite
## ------------------------------------

# Grabbing tasks to be run
tasks <- readRDS(gsub("derived", "raw", file.path(workdir, "bundles_to_rerun.rds")))
tasks <- as.character(vapply(tasks, "[[", character(1), "path"))

# submit our tasks to the cluster
split_path <- function(x) if (dirname(x)==x) x else c(basename(x),split_path(dirname(x)))
bundle_name <- paste0("rerun_", paste0(tail(rev(split_path(workdir)), 2), collapse = "_"))
grp_rerun <- obj$lapply(tasks, orderly::orderly_bundle_run, workdir = workdir,
                  name = paste0(bundle_name, ""))

didehpc:::reconcile(obj, grp_rerun$ids)
table(grp_rerun$status())

# see what has errorred

errs <- get_errors(grp_excess_rerun)

resubmit_all(grp_excess_rerun, c("ERROR", "MISSING"))
