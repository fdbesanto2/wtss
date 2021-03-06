#' @title Decodes the description from a WTSS coverage
#' @name  .wtss_coverage_description
#' 
#' @description creates a tibble to store the description of the WTSS coverage
#' @param wtss.obj  valid WTSS object
#' @param cov       coverage response provided by WTSS service
#' 
.wtss_coverage_description <- function(wtss.obj, cov){
    
    # retri
    name <- cov$name

    # temporal extent
    timeline <- lubridate::as_date(cov$timeline)
    
    # retrieve information about the bands
    band_info <- cov$attributes
    
    attr <- tibble::as_tibble(band_info)
    bands <- attr$name
    
    t <- dplyr::select(dplyr::filter(attr, name %in% bands), 
                       name, missing_value, scale_factor, valid_range)
    missing_values        <- t$missing_value
    names(missing_values) <- t$name
    
    scale_factors         <- t$scale_factor
    names(scale_factors)  <- t$name
    
    minimum_values        <- t$valid_range$min
    names(minimum_values) <- t$name
    
    maximum_values        <- t$valid_range$max
    names(maximum_values) <- t$name
    
    # correct errors in scale factors
    if (all(scale_factors == 1))
        scale_factors <- 1/maximum_values
    
    # Spatial extent
    xmin <- cov$spatial_extent$xmin
    ymin <- cov$spatial_extent$ymin
    xmax <- cov$spatial_extent$xmax
    ymax <- cov$spatial_extent$ymax
    
    # Spatial resolution
    xres <- cov$spatial_resolution$x
    yres <- cov$spatial_resolution$y
    
    # Size (rows and cols)
    nrows <- cov$dimension$y$max_idx - cov$dimensions$y$min_idx + 1
    ncols <- cov$dimension$x$max_idx - cov$dimensions$x$min_idx + 1
    
    # Projection CRS
    crs <- cov$crs$proj4
    
    # retrieve the satellite associated to the cube
    sat_sensor <- .wtss_guess_satellite(xres)
    satellite  <- sat_sensor["satellite"]
    # retrieve the sensor associated to the cube
    sensor     <- sat_sensor["sensor"]
    
    # create a tibble to store the metadata
    cov.tb <- tibble::tibble(URL            = wtss.obj$url,
                             satellite      = satellite,
                             sensor         = sensor,
                             name           = name,
                             bands          = list(bands),
                             scale_factors  = list(scale_factors),
                             missing_values = list(missing_values),
                             minimum_values = list(minimum_values),
                             maximum_values = list(maximum_values),
                             timeline       = list(timeline),
                             nrows          = nrows,
                             ncols          = ncols,
                             xmin           = xmin,
                             xmax           = xmax,
                             ymin           = ymin,
                             ymax           = ymax,
                             xres           = xres,
                             yres           = yres,
                             crs            = crs)
    
    class(cov.tb) <- append(class(cov.tb), c("sits", "sits_cube_tbl"), after = 0)
    
    return(cov.tb)
}

.wtss_print_coverage <- function(cov.tb){
    cat("---------------------------------------------------------------------")
    cat(paste0("\nWTSS server URL = ", cov.tb$URL, "\n"))
    cat(paste0("Cube (coverage) = ", cov.tb$name))
    
    print(knitr::kable(dplyr::select(cov.tb, satellite, sensor, bands), 
                       padding = 0))
    print(knitr::kable(dplyr::select(cov.tb, scale_factors), padding = 0))
    print(knitr::kable(dplyr::select(cov.tb, minimum_values), padding = 0))
    print(knitr::kable(dplyr::select(cov.tb, maximum_values), padding = 0))
    print(knitr::kable(dplyr::select(cov.tb, nrows, ncols, xmin, xmax, ymin, 
                                     ymax, xres, yres, crs), padding = 0))
    # print the timeline
    timeline <- lubridate::as_date(cov.tb$timeline[[1]])
    n_time_steps <- length(timeline)
    cat(paste0("\nTimeline - ",n_time_steps," time steps\n"))
    cat(paste0("start_date: ", timeline[1], 
               " end_date: ", timeline[n_time_steps],"\n"))
    cat("-------------------------------------------------------------------\n")
}
#' @title Retrieves the list of cubes from the URL server
#' @name .wtss_list_coverages
#'
#' @description Use the WTSS protocol to find out available coverages
#'
#' @param wtss.obj      WTSS object associated to the service
#' @return              updated WTSS object.
.wtss_list_coverages <- function(wtss.obj) {
    
    items <- NULL
    ce <- 0
    
    url <- wtss.obj$url
    
    response <- NULL
    
    # concat list_coverages to the service URL 
    request <- paste(url,"/list_coverages",sep = "")
    
    # send a request to the WTSS server
    response <- .wtss_send_request(request)
    # parse the response 
    items <- .wtss_parse_json(response)
    # if the server does not answer any item
    if (purrr::is_null(items))
        return(NULL)
    
    # if the server answers correctly
    return(items$coverages)
}
#' @title Try a best guess for the type of sensor/satellite
#' @name .wtss_guess_satellite
#' @author Gilberto Camara, \email{gilberto.camara@@inpe.br}
#'
#' @description    Based on resolution, tries to guess what is the satellite.
#'
#' @param xres      xres of the coverage
#' @return          Satellite sensor pair
.wtss_guess_satellite <- function(xres) {
    
    if (xres < 1.0 ) {
        # assume that xres is given in decimal degrees
        # approximate resolution of the coverage 
        res_m <- geosphere::distGeo(p1 = c(0.0, 0.0), p2 = c(xres, 0.00))
    }
    else
        res_m <- xres
    
    #try to guess the satellite
    if (res_m > 200.0 && res_m < 2000.0) {
        sat_sensor <- c("TERRA", "MODIS")
    }
    else if (res_m > 60.00 && res_m < 80.0)
        sat_sensor <- c("CBERS", "AWFI")
    else if (res_m > 25.00 && res_m < 35.0)
        sat_sensor <- c("LANDSAT", "OLI")
    else if (res_m < 25.00 && res_m > 5.0)
        sat_sensor <- c("SENTINEL-2", "MSI")
    else 
        sat_sensor <- c("UNKNOWN", "UNKNOWN")

    
    names(sat_sensor) <-  c("satellite", "sensor")
    
    return(sat_sensor)
}
#' @title Remove trailing dashes from a WTSS server address
#' @name  .wtss_remove_trailing_dash
#'
#' @description The WTSS URL cannot have a trailing dash. This functions checks
#' and removes it, if present.
#' 
#' @param URL         A WTSS URL
#' @return            URL without trailing dash

.wtss_remove_trailing_dash <- function(URL) {
    
    # find the length of the URL 
    url_length   <- stringr::str_length(URL)
    # locate all dashes in URL and return a data frame
    url_loc_dash <- stringr::str_locate_all(URL, "/")[[1]]
    # find out how many rows are there (one row for each dash)
    nrow_ld <- nrow(url_loc_dash)
    
    # find the location of the last dash
    lg <- as.numeric(url_loc_dash[nrow_ld, "start"])
    # create a retrun variable
    url_new <- URL
    
    # if there is a trailing dash, remove it
    if (lg == url_length)
        url_new <- stringr::str_sub(URL, end = (url_length - 1))
    
    return(url_new)
}
