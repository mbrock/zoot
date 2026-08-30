(defpackage #:zoot
  (:use #:cl)
  (:shadow #:concatenate)
  (:export
   #:text #:verbatim #:+newline+ #:concatenate #:cat #:vcat #:choice
   #:nest #:align
   #:span #:span-document #:span-document-meta #:span-document-child
   #:flatten #:group
   #:separated-by #:separated-by-spaces #:one-per-line
   #:possibly-collapsed-to-one-line
   #:surrounded-by #:surrounded-by-parentheses
   #:surrounded-by-square-brackets #:surrounded-by-braces
   #:*indentation-width* #:indented #:indented-by
   #:starting-on-next-line #:aligned-to-current-column
   #:make-f1 #:make-f2 #:pick #:render #:render-layout #:format-document
   #:*cost-measure* #:linear-overflow-cost #:squared-overflow-cost
   #:result-candidate #:result-frontier #:result-statistics #:result-tainted-p
   #:candidate-last #:candidate-rank
   #:rank-overflow #:rank-indentation #:rank-height
   #:statistics-evaluations #:statistics-memo-hits
   #:statistics-memo-entries #:statistics-frontier-maximum
   #:statistics-frontier-histogram
   #:statistics-taints-deferred #:statistics-taints-forced))

(in-package #:zoot)

(deftype nonnegative-fixnum ()
  '(integer 0 #.most-positive-fixnum))
