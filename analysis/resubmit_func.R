#function that checks for common errors and resubmits
resubmit_func <- function(object, group){
  didehpc::web_login()

  didehpc:::reconcile(object, group$ids)

  # check on their status
  status <- group$status()

  if(any(status == "ERROR")){
    # see what has errorred
    errs <- lapply(seq_along(which(status == "ERROR")), function(x){
      group$tasks[[which(status == "ERROR")[x]]]$log()$body
    })

    #general fail (e.g. no error message)
    failed <- unlist(lapply(errs, function(x){
      if(length(x)<19){
        TRUE
      } else if(stringr::str_detect(x[[19]][1],
                                    "missing value where TRUE/FALSE")){
        TRUE
      } else if(stringr::str_detect(x[[19]][1],
                                    "unable to load shared object")){
        TRUE
      } else if (stringr::str_detect(x[[19]][1], "Error in serverSocket")){
        TRUE
      } else if (stringr::str_detect(x[[19]][1], "Integration failure")){
        TRUE
      } else if (stringr::str_detect(x[[19]][1], "LaTeX")){
        TRUE
      } else{
        FALSE
      }
    }))

    if(any(failed)){
      #to re-run
      to_rerun <- which(status == "ERROR")[failed]
      print(paste0("Rerunning: ", paste0(to_rerun, collapse = ", ")))
      unlink(gsub("\\.zip", "", gsub("raw", "derived", group$X[to_rerun])), recursive = TRUE)
      object$submit(group$ids[to_rerun])
    } else if(all(status %in% c("COMPLETE", "ERROR"))){
      return(FALSE)
    }
    return(TRUE)
  } else if(all(status == "COMPLETE")) {
    return(FALSE)
  } else {
    return(TRUE)
  }
}
