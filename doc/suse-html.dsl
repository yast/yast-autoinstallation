<!-- Copyright (C) 2002 by SuSE Linux AG -->
<!-- Karl Eichwalder <ke@suse.de> -->
<!-- GPL  -->

(define %html-header-tags% 
  ;; REFENTRY html-header-tags
  ;; PURP What additional HEAD tags should be generated?
  ;; DESC
  ;; A list of the the HTML HEAD tags that should be generated.
  ;; The format is a list of lists, each interior list consists
  ;; of a tag name and a set of attribute/value pairs:
  '(("META" ;; ("NAME" "name") ("CONTENT" "content"))
     ("http-equiv" "Content-Type")
     ("content" "text/html; charset=ISO-8859-1")))
  ;; /DESC
  ;; AUTHOR N/A
  ;; /REFENTRY
  )

