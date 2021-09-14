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
context_name <- paste0("Q:/COVID-Fitting/glodide/context")

ctx <- context::context_save(
  path = context_name,
  package_sources = conan::conan_sources(
    packages = c(
      "vimc/orderly", "mrc-ide/squire@v0.6.9", "mrc-ide/nimue",
      c('tinytex','knitr', 'tidyr', 'ggplot2', 'ggrepel', 'magrittr', 'dplyr', 'here', "lubridate", "rmarkdown",
        'stringdist','plotly', 'rvest', 'xml2', 'ggforce', 'countrycode', 'cowplot', 'RhpcBLASctl', 'nimue')
      ),
    repos = "https://ncov-ic.github.io/drat/")
  )

# set up a specific config for here as we need to specify the large RAM nodes
config <- didehpc::didehpc_config(template = "24Core")
config$resource$parallel <- "FALSE"
config$resource$type <- "Cores"

# Configure the Queue
obj <- didehpc::queue_didehpc(ctx, config = config)

## ------------------------------------
## 3. Submit the jobs
## ------------------------------------

date <- "2021-09-09"
short_run <- FALSE
excess_mortality <- TRUE
workdir <- file.path(
  "analysis/data/",
  paste0(
    "derived",
    ifelse(excess_mortality, "_excess", ""),
    ifelse(short_run, "_test", "")
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
                  name = bundle_name)

## ------------------------------------
## 4. Check on our jobs
## ------------------------------------

# check on their status
status <- grp$status()
table(status)

# see what has errorred
errs <- lapply(seq_along(which(status == "ERROR")), function(x){
  grp$tasks[[which(status == "ERROR")[x]]]$log()$body
})

# sometimes tasks say running or completed when in fact they have errored:
didehpc:::reconcile(obj, grp$ids)
status <- grp$status()
errs <- lapply(seq_along(which(status == "ERROR")), function(x){
  grp$tasks[[which(status == "ERROR")[x]]]$log()$body[[19]]
})

# do we just need to rerun some of the bundles
to_rerun <- which(grp$status() == "ERROR")
unlink(gsub("\\.zip", "", gsub("raw", "derived", grp$X[to_rerun])), recursive = TRUE)
obj$submit(grp$ids[to_rerun])


## ------------------------------------
## 5. Check on our jobs from a new R session
## ------------------------------------

# what were run for the date in question
grep(date, obj$task_bundle_list(), value = TRUE)

# we can get an old task bundle as follows
grp <- obj$task_bundle_get("derived_2021-08-19")

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
                  name = bundle_name)

table(grp_rerun$status())

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
