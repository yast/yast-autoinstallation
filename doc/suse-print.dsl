<!-- Copyright (C) 2002 by SuSE Linux AG -->
<!-- Karl Eichwalder <ke@suse.de> -->
<!-- GPL  -->

;; ====================
;; customize the print stylesheet
;; ====================

;; ;; make funcsynopsis look pretty
;; (define %funcsynopsis-decoration%
;;   ;; Decorate elements of a FuncSynopsis?
;;   #t)
;; 
;; ;; use graphics in admonitions, and have their path be "."
;; ;; NO: we are not yet ready to use gifs in TeX and so forth
;; (define %admon-graphics-path%
;;   "./")
;; (define %admon-graphics%
;;   #f)
;; 
;; ;; this is necessary because right now jadetex does not understand
;; ;; symbolic entities, whereas things work well with numeric entities.
;; (declare-characteristic preserve-sdata?
;;           "UNREGISTERED::James Clark//Characteristic::preserve-sdata?"
;;           #f)
;; (define %two-side% #t)
;; (define %paper-type% "A4")
;; 
;; (define %section-autolabel% 
;;   ;; Are sections enumerated?
;;   #t)
;; ;; (define %title-font-family% 
;; ;;   ;; The font family used in titles
;; ;;   "Ariel")
;; (define %visual-acuity%
;;   ;; General measure of document text size
;;   ;; "presbyopic"
;;   ;; "large-type"
;;   "presbyopic")
;; 
;; (define %generate-part-toc% #t)
;; 
;; ;; (define %block-start-indent% 10pt)
;; 
;; (define %graphic-default-extension% "eps")
