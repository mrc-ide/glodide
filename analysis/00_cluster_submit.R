# Setting Up Cluster From New

# Log in to didehpc (Replace with own credentials!)
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
# install.packages("rrq")

# tinytex::install_tinytex(
#   force = TRUE,
#   dir = file.path(dirname(here::here()), "TinyTex")
# )

## ------------------------------------
## 2. Setting up a cluster configuration
## ------------------------------------

options(didehpc.cluster = "fi--didemrchnb")

# not if T is not mapped then map network drive
network_map <- stringr::str_remove(dirname(dirname(here::here())), "/") #Ensure this is correct
didehpc::didehpc_config_global(temp=didehpc::path_mapping("tmp",
                                                          "T:",
                                                          "//fi--didef3.dide.ic.ac.uk/tmp",
                                                          "T:"),
                               home=didehpc::path_mapping("ncov",
                                                          network_map,
                                                          "//wpia-hpc-hn-app/ncov-global",
                                                          network_map),
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
config <- didehpc::didehpc_config(template = "32Core", use_workers = TRUE)
# Configure the Queue
obj <- didehpc::queue_didehpc(ctx, config = config)

## 3. Submit the jobs
## ------------------------------------

date <- "2022-09-01"
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
iso3cs <- names(tasks)
tasks <- as.character(vapply(tasks, "[[", character(1), "path"))

#How many workers
n_workers <- 13

#One country takes around 5806 seconds and 185 countries split into the workers
#((ceiling(185/workers) * (5806))/60/60) = 24.2 hours total

# submit our tasks to the cluster
split_path <- function(x) if (dirname(x)==x) x else c(basename(x),split_path(dirname(x)))
bundle_name <- paste0(tail(rev(split_path(workdir)), 2), collapse = "_")
grp <- obj$lapply(tasks, orderly::orderly_bundle_run, workdir = workdir,
                  name = paste0(bundle_name, "_1"))
workers <- obj$submit_workers(n_workers)
rrq <- obj$rrq_controller()

## ------------------------------------
## 4. Check on our jobs
## ------------------------------------

#source functions for checking on fits
source(file.path(here::here(), "analysis", "resubmit_func.R"))

#see how they are running
print(table(grp$status()))
#may fail depening on status of pandoc/tinytex on cluster(just rerun these)
#see reports from workers
rrq$worker_log_tail(n = 2)
#check every 30 minutes for 5 hours
for(i in 1:10){# | keep_running_2){
  Sys.sleep(30*60)
  print("LMIC Fit")
  print(table(grp$status()))
}

# see what has errored
errs <- get_errors(grp)

#get the iso3cs of the tasks with a givens status, might need adjusting
dput(iso3cs[which(grp$status() == "ERROR")])

obj$submit(grp$ids[grp$status() == "ERROR"])
workers <- obj$submit_workers(2)
## ------------------------------------
## 6. Submit new jobs that need rerunning
## ------------------------------------

# Grabbing tasks to be run
tasks <- readRDS(gsub("derived", "raw", file.path(workdir, "bundles_to_rerun.rds")))
iso3cs_rerun <- names(tasks)
tasks <- as.character(vapply(tasks, "[[", character(1), "path"))

# submit our tasks to the cluster
split_path <- function(x) if (dirname(x)==x) x else c(basename(x),split_path(dirname(x)))
bundle_name <- paste0("rerun_", paste0(tail(rev(split_path(workdir)), 2), collapse = "_"))
grp_rerun <- obj$lapply(tasks, orderly::orderly_bundle_run, workdir = workdir,
                  name = paste0(bundle_name, "_2"))
workers <- obj$submit_workers(14)
table(grp_rerun$status())

# see what has errorred

errs <- get_errors(grp_rerun_2)

dput(iso3cs_rerun[which(grp_rerun$status() == "ERROR")])

resubmit_all(grp_rerun, c("ERROR", "MISSING"))
