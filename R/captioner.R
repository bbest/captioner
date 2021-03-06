#' Captioner function
#'
#' Creates a function to create numbered captions for figures, tables or other objects
#' 
#' @param prefix Character string containing text to go before object number. The default is "Figure".
#' @param auto_space Logical indicating whether or not a space should automatically be added following the prefix.  Space is added by default.
#' @param levels Logical or number indicating whether or not you want hierarchical numbering, and if so, how many levels.  Hierarchical numbering is turned off by default.
#' @param type Vector with same length as `levels` indicating whether figure numbering should be numeric ("n"), lowercase character ("c"), or uppercase character ("C").  If unspecified, `captioner` will revert to all numeric values.
#' @param infix Character string containing text to go between figure numbers if hierarchical numbering is on.  Default is "."
#' @param link Logical indicating whether you want citations linked to figures for HTML or PDF output. Default is FALSE.
#' 
#' @return A captioner function.
#' 
#' @details Captioner generates a function with the following parameters
#' 
#' \code{name}: Character string containing a unique object name
#' 
#' \code{caption}: The object caption
#' 
#' \code{display}: Character string (or logical) indicating what display mode you would like: "full" or "f" is the default and shows the entire caption with prefix and number; "cite" or "c" displays just the prefix and number, without the caption; "num" or "n" displays just the number
#'
#' \code{level}: Optional numeric used to "bump" up the numbering if you have hierarchical numbering.  See also \code{\link{bump}}.
#'   
#' \code{cite}: Deprecated.  Please use \code{display}.
#' 
#' \code{num}: Deprecated. Please use \code{display}.
#' 
#' And returns a character string containing the prefix and object number with or without a caption.
#' The initial numbering is determined based on the order of caption creation.  However, this order
#' is modified based on the citations you use.  The first figure to be cited will be moved to the
#' beginning of the list, becoming "Figure 1".
#' 
#' If \code{link = TRUE}, then citations are hyperlinked to the referenced
#' caption. This only applies when rendering an Rmarkdown document to HTML or
#' PDF (see \url{http://rmarkdown.rstudio.com}). For the link to work, the
#' caption needs to be output using the option \code{fig_caption: yes} in the
#' front matter of the Rmarkdown document. Since for PDF output, figure
#' numbering is internally handled, this number gets used over the captioner
#' generated number so special use of \code{level} does not get applied.
#' 
#' @examples
#' \donttest{
#' # Create a new captioner object:
#' fig_nums <- captioner()
#' 
#' # Store a caption with the key word "flower_plot". Print the caption
#' # including the figure number:
#' fig_nums("flower_plot", "This plot shows the distribution of flower colors")
#' 
#' # Cite the figure e.g. "Figure 1", using the key word:
#' fig_nums("flower_plot", cite = TRUE)
#' 
#' # Now you can print the caption any time using the designated key:
#' fig_nums("flower_plot")
#'
#' # Create a captioner object with hierarchical numbering:
#' tables <- captioner(prefix = "Table", levels = 2)
#' tables("a", "Table of world populations sorted from greatest to least.")
#' }
#' 
#' # Create a captioner object with links (for HTML or PDF output):
#' fig_nums <- captioner(link = TRUE)
#'   
#' @export

captioner <- function(prefix = "Figure", auto_space = TRUE, levels = 1,
                      type = NULL, infix = ".", 
                      link = FALSE, fmt = knitr::opts_knit$get()[['rmarkdown.pandoc.to']])
{
  ## Make sure all of the parameters are setup correctly ---
  
  # Check the parameter classes
  check_class(prefix,     "character")
  check_class(auto_space, "logical")
  check_class(levels,     "numeric")
  check_class(infix,      "character")
  
  # Check "type" vector
  
  # Set missing/NULL "type" values to numeric
  # Cut off extra values
  if(is.null(type)){
    type <- c(rep("n", times = levels))
  } else if(length(type) < levels){
    type[(length(type) + 1):levels] <- "n"
  } else if(length(type) > levels){
    type <- type[1:levels]
  }
  
  # Give error if wrong types were used
  if(!all(type %in% c("n", "c", "C"))){
    stop("Invalid 'type' value used.  Expecting 'n', 'c', or 'C'.")
  }
  
  # Add a space after the prefix if auto_space is on
  if(auto_space){
    prefix <- paste(prefix, " ")
  }
  
  # Force the parameter values for use in the return function
  force(levels)  
  force(prefix)
  force(infix)
  
  ## Create the OBJECT list ---
  
  # Create a list to store object names, captions, and numbers
  OBJECTS <- list("name"    = NULL,
                  "caption" = NULL,
                  "number"  = list(list()))
  
  # Assign the first caption number
  # Note that extra values of "type" are ignored by looping over "levels"
  OBJECTS$number[[1]][which(type == "n")] <- 1
  OBJECTS$number[[1]][which(type == "c")] <- "a"
  OBJECTS$number[[1]][which(type == "C")] <- "A"
  
  ## Create and return the specialized captioning function ---
  
  function(name, caption = "", display = "full", level = FALSE, cite = FALSE, num = FALSE)
  {
    ## Error check parameters --
    if(level > levels){
      stop("Level too large.")
    }    
    
    ## Get the object list from the enclosing environment ---
    objects <- OBJECTS
    
    ## Assign the new name and caption to the list ---
    
    # Is the name already stored?
    if(any(objects$name == name)) {
      # find the index associated with the stored name
      obj_ind <- match(name, objects$name)
      
      # find the caption associated with the stored name
      # if the caption is missing, and you supplied one with the current
      # function call, the missing one will be filled in with the new one
      if(objects$caption[obj_ind] == ""){
        # replace empty caption
        objects$caption[obj_ind] <- caption
      } else {
        # access existing caption
        caption <- objects$caption[obj_ind]
      }
    }  
    else {
      # get the earliest available index
      obj_ind <- length(objects$name) + 1
            
      # If there is already a nameless number, none will be added
      # Otherwise the number is incremented
      if(length(objects$number) == length(objects$name)){
        if(level){
          # bump the numbering at an earlier level
          objects$number[[obj_ind]] <- increment(objects$number[[obj_ind - 1]], level)
        } else{
          # increment the previous number and add as the new number
          objects$number[[obj_ind]] <- increment(objects$number[[obj_ind - 1]], levels)
          
        }
      }
      
      # store the object name and caption at the current index
      objects$name[obj_ind]    <- name
      objects$caption[obj_ind] <- caption
    }
    
    ## Copy "objects" back to the parent environment ---
    
    assign("OBJECTS", objects, envir = parent.env(environment()))
    
    ## Format the display ready output ---
    
    # create display version of object number
    obj_num <- paste(objects$number[[obj_ind]], collapse = infix)
    
    # get display output format from running rmarkdown::render()
    ref = stringr::str_replace_all(sprintf('%s_%s', prefix, obj_num), ' ', '')
    if (link & fmt == 'latex'){
      # note that prefix is dropped for PDF output since automatically handles this
      s_display = sprintf('%s\\label{%s}', caption, ref)
      s_cite    = sprintf('%s\\ref{%s}', prefix, ref)
      s_num     = sprintf('\\ref{%s}', ref)
    } else if (link & fmt == 'html'){
      s_display = sprintf('<a name="%s"}></a>%s%s: %s', ref, prefix, obj_num, caption)
      s_cite    = sprintf('[%s%s](#%s)', prefix, obj_num, ref)
      s_num     = sprintf('[%s](#%s)', obj_num, ref)
    } else {
      s_display = paste0(prefix, obj_num, ": ", caption)
      s_cite    = paste0(prefix, obj_num)
      s_num     = obj_num
    }
    
    # choose display format and return
    
    # for backwards compatibility, use the cite and num options first
    if(cite){
      .Deprecated(new = "display", old = "cite")
      return(s_cite)
     }
    
    if(num){
      .Deprecated(new = "display", old = "num")
      return(s_num)
    }
    
    if(display == FALSE)
    {
      return(invisible())
    }
    else if(display == "full" || display == "f")
    {
      return(s_display)
    }
    else if(display == "cite" || display == "c")
    {
      return(s_cite)
    }
    else if(display == "num"  || display == "n")
    {
      return(s_num)
    }
    else
    {
      warning("Invalid display mode used.  Caption was still saved.")
      return(invisible())
    }
  }
}