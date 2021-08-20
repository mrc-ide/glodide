# Setting Up Cluster From New

# Log in to didehpc
credentials = "C:/Users/ow813/.smbcredentials"
options(didehpc.cluster = "fi--didemrchnb",
        didehpc.username = "ow813")

## 1. Package Installations
# drat:::add("mrc-ide")
# install.packages("pkgdepends")
# install.packages("didehpc")
# install.packages("orderly")

## 2. Setting up a configuration
options(didehpc.cluster = "fi--didemrchnb")

# not if T is not mapped then map network drive
didehpc::didehpc_config_global(temp=didehpc::path_mapping("tmp",
                                                          "T:",
                                                          "//fi--didef3.dide.ic.ac.uk/tmp",
                                                          "T:"),
                               home=didehpc::path_mapping("OJ",
                                                          "L:",
                                                          "//fi--didenas5/malaria",
                                                          "L:"),
                               credentials=credentials,
                               cluster = "fi--didemrchnb")

# Creating a Context
context_name <- paste0("L:/OJ/glodide/context")

ctx <- context::context_save(
  path = context_name,
  package_sources = conan::conan_sources(
    packages = c(
      "vimc/orderly", "mrc-ide/squire", "mrc-ide/nimue",
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

## 3. Submit the jobs
date <- "2021-08-16"
workdir <- normalizePath(file.path("analysis/data/derived", date))
dir.create(workdir, showWarnings = FALSE)

# Grabbing tasks to be run
tasks <- readRDS(file.path("analysis/data/raw", date, "bundles.rds"))
tasks <- vapply(tasks, "[[", character(1), "path")

# submit our tasks to the cluster
grp <- obj$lapply(tasks, orderly::orderly_bundle_run, workdir = workdir)

# check on their status
status <- grp$status()
table(status)

# see what has errorred
errs <- lapply(seq_along(which(status == "ERROR")), function(x){
  grp$tasks[[which(status == "ERROR")[x]]]$log()$body[[19]]
})

# sometimes tasks say running or completed when in fact they have errored:
didehpc:::reconcile(obj, grp$ids)
status <- grp$status()
errs <- lapply(seq_along(which(status == "ERROR")), function(x){
  grp$tasks[[which(status == "ERROR")[x]]]$log()$body[[19]]
})

# do we just need to rerun some of them bundle
to_rerun <- which(grp$status() == "ERROR")
unlink(gsub("\\.zip", "", gsub("raw", "derived", grp$X[to_rerun])), recursive = TRUE)

grp_new <- obj$lapply(tasks[to_rerun], orderly::orderly_bundle_run, workdir = workdir)
status_new <- grp_new$status()
errs <- lapply(seq_along(which(status_new == "ERROR")), function(x){
  tail(grp_new$tasks[[which(status_new == "ERROR")[x]]]$log()$body,3)[[1]]
})

grp_new <- obj$lapply(tasks[which(!file.exists(gsub("raw","derived", tasks)))], orderly::orderly_bundle_run, workdir = workdir)
status_new <- grp_new$status()
errs <- lapply(seq_along(which(status_new == "ERROR")), function(x){
  tail(grp_new$tasks[[which(status_new == "ERROR")[x]]]$log()$body,3)[[1]]
})




##

# Grabbing tasks to be run
tasks_test <- readRDS(file.path("analysis/data/raw", date, "test_bundles.rds"))
tasks_test <- vapply(tasks_test, "[[", character(1), "path")
grp_test <- obj$lapply(tasks_test, orderly::orderly_bundle_run, workdir = workdir)
