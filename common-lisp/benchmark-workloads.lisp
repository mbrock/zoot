(defpackage #:zoot-benchmark
  (:use #:cl #:zoot)
  (:shadowing-import-from #:zoot #:concatenate))

(in-package #:zoot-benchmark)

(defun join-documents (separator documents)
  (if (null documents)
      (text "")
      (reduce (lambda (left right)
                (cat left separator right))
              (rest documents)
              :initial-value (first documents))))

(defun call-document (items)
  "A token-preserving choice between horizontal and vertical S-expression
layout. Both branches contain exactly the same non-whitespace tokens."
  (let ((horizontal (join-documents (text " ") items))
        (vertical (apply #'vcat items)))
    (cat (text "(")
         (align (choice horizontal vertical))
         (text ")"))))

(defun ternary-document (depth)
  "Construct a fresh full ternary expression tree with choices at each call."
  (let ((ordinal 0))
    (labels ((name (prefix)
               (prog1 (text (format nil "~A~D" prefix ordinal))
                 (incf ordinal)))
             (walk (remaining)
               (let ((operator (name "f")))
                 (if (zerop remaining)
                     (call-document
                      (list operator (name "x") (name "x") (name "x")))
                     (call-document
                      (list operator
                            (walk (1- remaining))
                            (walk (1- remaining))
                            (walk (1- remaining))))))))
      (walk depth))))

(defun shared-document (depth)
  "Construct a DAG: each level concatenates the same child on both branches."
  (labels ((walk (remaining)
             (if (zerop remaining)
                 (choice (text "shared-wide")
                         (cat +newline+ (text "s")))
                 (let ((child (walk (1- remaining))))
                   (choice
                    (cat (text "(") child (text " ") child (text ")"))
                    (cat (text "(") (align (vcat child child)) (text ")")))))))
    (walk depth)))

(defun tainted-document (count)
  "An overflowing prefix followed by fitting alternatives after newlines."
  (apply #'cat
         (loop repeat count
               append (list (text "unavoidably-wide-token")
                            +newline+
                            (choice (text "also-far-too-wide")
                                    (text "ok"))))))
