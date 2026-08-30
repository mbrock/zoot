(asdf:defsystem "zoot"
  :description "A direct Common Lisp implementation of Zoot's recursive evaluator"
  :license "MIT"
  :serial t
  :components ((:file "zoot")))

(asdf:defsystem "zoot/sexp"
  :description "A Lisp source pretty-printer built on Zoot"
  :depends-on ("zoot" "eclector")
  :components ((:file "sexp")))

(asdf:defsystem "zoot/tests"
  :depends-on ("zoot")
  :serial t
  :components ((:file "tests")))
