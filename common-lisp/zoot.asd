(asdf:defsystem "zoot"
  :description "A direct Common Lisp implementation of Zoot's recursive evaluator"
  :license "MIT"
  :serial t
  :components ((:file "zoot")))

(asdf:defsystem "zoot/tests"
  :depends-on ("zoot")
  :serial t
  :components ((:file "tests")))
